# Alessio Garreffa Hair — prenotazioni

Applicazione Flutter per Android, iOS e Web con area cliente, console amministrativa responsive e API FastAPI. Il client comunica esclusivamente via HTTPS con il backend; utenti, ruoli, servizi, blocchi e prenotazioni sono salvati in MongoDB.

## Funzioni principali

- Registrazione e login proprietari con password Argon2id, access token JWT breve e refresh token ruotato/revocabile.
- Gerarchia `owner` > `manager` > `client`; solo il proprietario assegna i ruoli.
- Richieste cliente volutamente permissive: più clienti possono chiedere la stessa fascia.
- Avvisi all’amministratore per sovrapposizioni e blocchi motivati; un solo appuntamento sovrapposto può essere confermato.
- Agenda amministrativa giornaliera a slot, servizi e orari configurabili.
- Push OneSignal su Android/iOS, email di verifica e recupero password via SMTP.
- Sincronizzazione opzionale con un Google Calendar dedicato all’attività.

## Avvio rapido

Preparare MongoDB e le variabili backend come indicato in [SETUP.md](SETUP.md), quindi:

```powershell
backend\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --reload --port 8088
flutter run -d android --dart-define-from-file=config/emulator.json
```

L’emulatore Android raggiunge il computer tramite `http://10.0.2.2:8088`. Per un dispositivo fisico usare l’IP LAN del computer oppure, preferibilmente, l’URL HTTPS di staging.

## Qualità

```powershell
backend\.venv\Scripts\python.exe -m ruff format --check backend
backend\.venv\Scripts\python.exe -m ruff check backend
backend\.venv\Scripts\python.exe -m pytest backend\tests -q
flutter analyze
flutter test
```

Le decisioni tecniche sono in [ARCHITECTURE.md](ARCHITECTURE.md); pubblicazione e segreti sono descritti in [DEPLOYMENT.md](DEPLOYMENT.md).
