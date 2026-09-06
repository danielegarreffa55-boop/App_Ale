[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z][a-z0-9-]{4,28}[a-z0-9]$')]
  [string]$ProjectId,

  [Parameter(Mandatory = $true)]
  [string]$BillingAccount,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^https://')]
  [string]$PublicAppUrl,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-fA-F-]{36}$')]
  [string]$OneSignalAppId,

  [string]$Region = 'europe-west1',
  [ValidatePattern('^[a-z][a-z0-9-]{0,62}$')]
  [string]$ServiceName = 'alessio-garreffa-hair-api',
  [ValidatePattern('^[A-Za-z0-9_-]+$')]
  [string]$MongoDatabase = 'alessio_garreffa_hair',
  [string]$GoogleCalendarId = '',
  [string]$CorsOrigins = '',
  [Parameter(Mandatory = $true)]
  [string]$SmtpHost,
  [int]$SmtpPort = 587,
  [Parameter(Mandatory = $true)]
  [string]$SmtpUsername,
  [Parameter(Mandatory = $true)]
  [string]$SmtpFrom,
  [string]$MongoSecretName = 'agh-mongodb-uri',
  [string]$JwtSecretName = 'agh-jwt-secret',
  [string]$OneSignalApiKeySecretName = 'agh-onesignal-api-key',
  [string]$SmtpPasswordSecretName = 'agh-smtp-password',
  [string]$CronSecretName = 'agh-cron-secret',
  [switch]$SkipScheduler
)

$ErrorActionPreference = 'Stop'

$gcloudCommand = (Get-Command gcloud -ErrorAction SilentlyContinue).Source
if (-not $gcloudCommand) {
  $userInstall = Join-Path $env:LOCALAPPDATA 'Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd'
  if (Test-Path -LiteralPath $userInstall) { $gcloudCommand = $userInstall }
}

if (-not $CorsOrigins) { $CorsOrigins = $PublicAppUrl }

function Invoke-Gcloud {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CommandArgs)
  & $script:gcloudCommand @CommandArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Comando gcloud non riuscito: gcloud $($CommandArgs -join ' ')"
  }
}

function Assert-Secret {
  param([Parameter(Mandatory = $true)][string]$Name)
  & $script:gcloudCommand secrets describe $Name --project=$ProjectId --format='value(name)' 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Secret Manager non contiene '$Name'. Crearlo prima del deploy."
  }
}

if (-not $gcloudCommand) {
  throw 'Google Cloud CLI non installata. Installarla e autenticarsi con l’account dell’attività.'
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
  cloudscheduler.googleapis.com `
  iam.googleapis.com `
  iamcredentials.googleapis.com `
  run.googleapis.com `
  secretmanager.googleapis.com `
  --project=$ProjectId

Assert-Secret -Name $MongoSecretName
Assert-Secret -Name $JwtSecretName
Assert-Secret -Name $OneSignalApiKeySecretName
Assert-Secret -Name $CronSecretName

$runtimeAccount = "agh-api@$ProjectId.iam.gserviceaccount.com"
$runtimeExists = $true
& $gcloudCommand iam service-accounts describe $runtimeAccount --project=$ProjectId 2>$null
if ($LASTEXITCODE -ne 0) { $runtimeExists = $false }
if (-not $runtimeExists) {
  Invoke-Gcloud iam service-accounts create agh-api `
    --display-name='AGH API runtime' `
    --project=$ProjectId
}

Invoke-Gcloud projects add-iam-policy-binding $ProjectId `
  --member="serviceAccount:$runtimeAccount" `
  --role='roles/logging.logWriter' `
  --condition=None
foreach ($secretName in @(
  $MongoSecretName,
  $JwtSecretName,
  $OneSignalApiKeySecretName,
  $SmtpPasswordSecretName,
  $CronSecretName
)) {
  Invoke-Gcloud secrets add-iam-policy-binding $secretName `
    --member="serviceAccount:$runtimeAccount" `
    --role='roles/secretmanager.secretAccessor' `
    --project=$ProjectId
}

$projectNumber = (& $gcloudCommand projects describe $ProjectId --format='value(projectNumber)').Trim()
if (-not $projectNumber) { throw 'Impossibile determinare il project number.' }
$builderAccount = "$projectNumber-compute@developer.gserviceaccount.com"
Invoke-Gcloud projects add-iam-policy-binding $ProjectId `
  --member="serviceAccount:$builderAccount" `
  --role='roles/run.builder' `
  --condition=None

$environment = "^|^APP_ENV=production|MONGODB_DATABASE=$MongoDatabase|MONGODB_TRANSACTIONS=true|JWT_ISSUER=alessio-garreffa-hair-api|APP_TIMEZONE=Europe/Rome|PUBLIC_APP_URL=$PublicAppUrl|ONESIGNAL_APP_ID=$OneSignalAppId"
if ($GoogleCalendarId) { $environment += "|GOOGLE_CALENDAR_ID=$GoogleCalendarId" }
if ($CorsOrigins) { $environment += "|CORS_ORIGINS=$CorsOrigins" }
Assert-Secret -Name $SmtpPasswordSecretName
$environment += "|SMTP_HOST=$SmtpHost|SMTP_PORT=$SmtpPort|SMTP_USERNAME=$SmtpUsername|SMTP_FROM=$SmtpFrom|SMTP_USE_TLS=true"
$secretEnvironment = "^|^MONGODB_URI=${MongoSecretName}:latest|JWT_SECRET=${JwtSecretName}:latest|ONESIGNAL_API_KEY=${OneSignalApiKeySecretName}:latest|CRON_SECRET=${CronSecretName}:latest"
$secretEnvironment += "|SMTP_PASSWORD=${SmtpPasswordSecretName}:latest"

Invoke-Gcloud run deploy $ServiceName `
  --source="$PSScriptRoot\..\backend" `
  --region=$Region `
  --service-account=$runtimeAccount `
  --allow-unauthenticated `
  --cpu=1 `
  --memory=1Gi `
  --concurrency=8 `
  --min=0 `
  --max=10 `
  --timeout=60 `
  --set-env-vars=$environment `
  --set-secrets=$secretEnvironment `
  --project=$ProjectId

$serviceUrl = (& $gcloudCommand run services describe $ServiceName `
  --region=$Region `
  --project=$ProjectId `
  --format='value(status.url)').Trim()
if (-not $serviceUrl) { throw 'Cloud Run non ha restituito l’URL del servizio.' }

$schedulerAccount = "agh-scheduler@$ProjectId.iam.gserviceaccount.com"
if (-not $SkipScheduler) {
  $schedulerExists = $true
  & $gcloudCommand iam service-accounts describe $schedulerAccount --project=$ProjectId 2>$null
  if ($LASTEXITCODE -ne 0) { $schedulerExists = $false }
  if (-not $schedulerExists) {
    Invoke-Gcloud iam service-accounts create agh-scheduler `
      --display-name='AGH reminder scheduler' `
      --project=$ProjectId
  }
  $cronEnvironment = "^|^CRON_OIDC_AUDIENCE=$serviceUrl|CRON_SERVICE_ACCOUNT=$schedulerAccount"
  Invoke-Gcloud run services update $ServiceName `
    --region=$Region `
    --update-env-vars=$cronEnvironment `
    --project=$ProjectId

  & $gcloudCommand scheduler jobs describe agh-send-reminders `
    --location=$Region `
    --project=$ProjectId 2>$null
  if ($LASTEXITCODE -eq 0) {
    Invoke-Gcloud scheduler jobs update http agh-send-reminders `
      --location=$Region `
      --schedule='*/15 * * * *' `
      --time-zone='Europe/Rome' `
      --uri="$serviceUrl/internal/reminders" `
      --http-method=POST `
      --oidc-service-account-email=$schedulerAccount `
      --oidc-token-audience=$serviceUrl `
      --project=$ProjectId
  } else {
    Invoke-Gcloud scheduler jobs create http agh-send-reminders `
      --location=$Region `
      --schedule='*/15 * * * *' `
      --time-zone='Europe/Rome' `
      --uri="$serviceUrl/internal/reminders" `
      --http-method=POST `
      --oidc-service-account-email=$schedulerAccount `
      --oidc-token-audience=$serviceUrl `
      --project=$ProjectId
  }
}

Write-Host ''
Write-Host "API pubblicata: $serviceUrl"
Write-Host "Health check: $serviceUrl/healthz"
Write-Host "Configurazione Flutter: BACKEND_API_URL=$serviceUrl"
Write-Host "Condividere il calendario dedicato con: $runtimeAccount"
