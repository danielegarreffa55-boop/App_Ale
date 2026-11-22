# FastAPI Cloud handoff

Questa guida serve a completare il deploy del backend dell'app Alessio Garreffa Hair. Le credenziali e le chiavi indicate come segrete non devono essere inserite nel repository, nei file `.env` versionati o nei log.

## 1. Pubblicare il codice

1. Eseguire il push di questo repository sul branch collegato a FastAPI Cloud.
2. Accedere a FastAPI Cloud con l'account che gestisce `app-ale.fastapicloud.dev`.
3. Verificare che il servizio punti alla cartella `backend` e all'applicazione `main:app`.
4. Verificare che il deploy installi `backend/requirements.txt`.

## 2. Variabili d'ambiente

Configurare le seguenti variabili nel pannello del servizio. Usare il tipo **secret** per password e chiavi.

```dotenv
PUBLIC_APP_URL=https://app-ale.fastapicloud.dev
APP_DEEP_LINK_SCHEME=alessiogarreffahair

ONESIGNAL_APP_ID=9983af4e-6764-4f1a-9ede-023f0711b3c7
ONESIGNAL_API_KEY=<CHIAVE_REST_ONESIGNAL_DA_RICEVERE_IN_PRIVATO>

SMTP_HOST=smtp.protonmail.ch
SMTP_PORT=587
SMTP_USERNAME=alehairapp@proton.me
SMTP_PASSWORD=<TOKEN_SMTP_PROTON, NON_PASSWORD_ACCOUNT>
SMTP_FROM=alehairapp@proton.me
SMTP_USE_TLS=true
```

La chiave `ONESIGNAL_API_KEY` è stata generata nel pannello OneSignal con nome `App Ale Backend Production`: va passata al responsabile del deploy tramite un password manager o altro canale privato, mai tramite Git.

La normale password dell'account Proton non è valida per l'invio SMTP dal server. Generare nelle impostazioni Proton un token SMTP compatibile con l'account e inserirlo come `SMTP_PASSWORD`. Se l'account non consente SMTP submission, usare un servizio transazionale (per esempio Brevo o Resend), verificare il mittente e sostituire host, utente e password con quelli del provider.

Confrontare inoltre le altre variabili obbligatorie con `backend/README.md` e `.env.example`, soprattutto database, autenticazione e ruoli amministrativi già presenti nel deploy.

## 3. Redeploy e controlli

1. Salvare le variabili e avviare un nuovo deploy.
2. Controllare che il deploy termini senza errori e che non stampi valori segreti nei log.
3. Aprire:
   - `https://app-ale.fastapicloud.dev/healthz`
   - `https://app-ale.fastapicloud.dev/readyz`
4. Entrambi gli endpoint devono rispondere con esito positivo.

## 4. Test funzionali

Su una build TestFlight installata:

1. Accettare il permesso per le notifiche.
2. Registrare un nuovo account e verificare l'arrivo dell'email di conferma.
3. Aprire il link dall'iPhone e controllare che si apra l'app tramite lo schema `alessiogarreffahair://`.
4. Provare “password dimenticata” e verificare il relativo link.
5. Creare o modificare un appuntamento e verificare la notifica push sul dispositivo.

Se email o push non arrivano, controllare prima i log del backend senza copiare i segreti nei ticket. Per OneSignal verificare anche che il dispositivo compaia tra le subscription dell'app `9983af4e-6764-4f1a-9ede-023f0711b3c7`.

## Materiale sensibile da conservare

- La chiave APNs Apple `AuthKey_8C2WN66HXN.p8` non è riscaricabile: conservarne una copia cifrata e limitarne l'accesso.
- Il JSON Firebase Admin SDK e le chiavi OneSignal devono restare fuori dal repository.
- Ruotare qualsiasi password condivisa in chat e usare token specifici per il servizio quando disponibili.

## Deploy automatico iOS

Il workflow `.github/workflows/ci.yml` pubblica automaticamente una nuova build su TestFlight dopo ogni push riuscito sul branch `main`. Il numero di build è calcolato dal contatore GitHub Actions, così ogni upload rimane univoco. I certificati e le chiavi Apple sono salvati esclusivamente nei GitHub Actions secrets del repository.
# Android / Google Play

La pipeline GitHub genera un Android App Bundle firmato a ogni push su `main`.
Il package Android definitivo è `it.studio.salon.salon_booking`.

Per abilitare anche il caricamento automatico nel test interno:

1. creare l'app Ale Hair in Google Play Console con questo package;
2. concedere al service account GitHub il permesso di rilascio sui canali di test;
3. creare nel repository la variabile Actions `GOOGLE_PLAY_ANDROID_ENABLED=true`.

Finché la variabile non è attiva, il job costruisce e conserva l'AAB tra gli
artifact di GitHub senza tentare un caricamento destinato a fallire.
