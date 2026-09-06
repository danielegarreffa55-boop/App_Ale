[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z][a-z0-9-]{4,28}[a-z0-9]$')]
  [string]$ProjectId,

  [Parameter(Mandatory = $true)]
  [string]$BillingAccount,

  [string]$Region = 'europe-west1',
  [string]$FirestoreLocation = 'eur3',
  [string]$ServiceName = 'alessio-garreffa-hair-api',
  [string]$GoogleCalendarId = '',
  [string]$CorsOrigins = ''
)

$ErrorActionPreference = 'Stop'

$gcloudCommand = (Get-Command gcloud -ErrorAction SilentlyContinue).Source
if (-not $gcloudCommand) {
  $userInstall = Join-Path $env:LOCALAPPDATA 'Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd'
  if (Test-Path -LiteralPath $userInstall) { $gcloudCommand = $userInstall }
}

function Invoke-Gcloud {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CommandArgs)
  & $script:gcloudCommand @CommandArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Comando gcloud non riuscito: gcloud $($CommandArgs -join ' ')"
  }
}

if (-not $gcloudCommand) {
  throw 'Google Cloud CLI non installata. Installarla e lanciare gcloud auth login.'
}
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  throw 'Firebase CLI non installata. Installarla e lanciare firebase login.'
}

$projectExists = $true
& $gcloudCommand projects describe $ProjectId --format='value(projectId)' 2>$null
if ($LASTEXITCODE -ne 0) { $projectExists = $false }
if (-not $projectExists) {
  Invoke-Gcloud projects create $ProjectId --name='Alessio Garreffa Hair'
}

Invoke-Gcloud billing projects link $ProjectId --billing-account=$BillingAccount
Invoke-Gcloud config set project $ProjectId
Invoke-Gcloud services enable `
  artifactregistry.googleapis.com `
  calendar-json.googleapis.com `
  cloudbuild.googleapis.com `
  compute.googleapis.com `
  firebase.googleapis.com `
  firestore.googleapis.com `
  identitytoolkit.googleapis.com `
  run.googleapis.com `
  --project=$ProjectId

& firebase projects:addfirebase $ProjectId --non-interactive
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Il progetto potrebbe essere già collegato a Firebase; continuo con la verifica.'
}

$databaseExists = $true
& $gcloudCommand firestore databases describe --database='(default)' --project=$ProjectId 2>$null
if ($LASTEXITCODE -ne 0) { $databaseExists = $false }
if (-not $databaseExists) {
  Invoke-Gcloud firestore databases create `
    --database='(default)' `
    --location=$FirestoreLocation `
    --type=firestore-native `
    --delete-protection `
    --project=$ProjectId
}

$runtimeAccount = "salon-api@$ProjectId.iam.gserviceaccount.com"
$runtimeExists = $true
& $gcloudCommand iam service-accounts describe $runtimeAccount --project=$ProjectId 2>$null
if ($LASTEXITCODE -ne 0) { $runtimeExists = $false }
if (-not $runtimeExists) {
  Invoke-Gcloud iam service-accounts create salon-api `
    --display-name='Salon API runtime' `
    --project=$ProjectId
}

Invoke-Gcloud projects add-iam-policy-binding $ProjectId `
  --member="serviceAccount:$runtimeAccount" `
  --role='roles/datastore.user' `
  --condition=None
Invoke-Gcloud projects add-iam-policy-binding $ProjectId `
  --member="serviceAccount:$runtimeAccount" `
  --role='roles/firebaseauth.admin' `
  --condition=None
Invoke-Gcloud projects add-iam-policy-binding $ProjectId `
  --member="serviceAccount:$runtimeAccount" `
  --role='roles/logging.logWriter' `
  --condition=None

$projectNumber = (& $gcloudCommand projects describe $ProjectId --format='value(projectNumber)').Trim()
if (-not $projectNumber) { throw 'Impossibile determinare il project number.' }
$builderAccount = "$projectNumber-compute@developer.gserviceaccount.com"
Invoke-Gcloud projects add-iam-policy-binding $ProjectId `
  --member="serviceAccount:$builderAccount" `
  --role='roles/run.builder' `
  --condition=None

& firebase use $ProjectId
if ($LASTEXITCODE -ne 0) { throw 'Impossibile selezionare il progetto Firebase.' }
& firebase deploy --only firestore:rules,firestore:indexes --project $ProjectId
if ($LASTEXITCODE -ne 0) { throw 'Deploy di regole o indici Firestore non riuscito.' }

$environment = "^|^GOOGLE_CLOUD_PROJECT=$ProjectId|APP_TIMEZONE=Europe/Rome"
if ($GoogleCalendarId) { $environment += "|GOOGLE_CALENDAR_ID=$GoogleCalendarId" }
if ($CorsOrigins) { $environment += "|CORS_ORIGINS=$CorsOrigins" }

Invoke-Gcloud run deploy $ServiceName `
  --source="$PSScriptRoot\..\backend" `
  --region=$Region `
  --service-account=$runtimeAccount `
  --allow-unauthenticated `
  --cpu=1 `
  --memory=512Mi `
  --concurrency=40 `
  --min=0 `
  --max=10 `
  --timeout=60 `
  --set-env-vars=$environment `
  --project=$ProjectId

$serviceUrl = (& $gcloudCommand run services describe $ServiceName `
  --region=$Region `
  --project=$ProjectId `
  --format='value(status.url)').Trim()

Write-Host ''
Write-Host "API pubblicata: $serviceUrl"
Write-Host "Health check: $serviceUrl/healthz"
Write-Host "Inserire BACKEND_API_URL=$serviceUrl nella configurazione Flutter production."
Write-Host "Service account Calendar: $runtimeAccount"
