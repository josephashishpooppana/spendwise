# SpendWise Mobile

Local-first Android expense tracker with Google Sheets and Drive sync.

## Features

- Track income/expenses across banks, credit cards, wallets, and cash
- Cashback (fixed, percentage, reward points) on expenses
- Bill splits (equal/custom) with contacts and groups
- Daily Google Drive JSON backup
- Append new transactions to your existing Google Sheet
- GitHub Actions builds APK without local Flutter install

## Project structure

```
mobile/lib/
  core/          Theme, routing, Riverpod providers
  data/          SQLite database, models, seed data
  domain/        Balance, cashback, transaction, split services
  features/      UI screens
  integrations/  Google OAuth, Sheets/Drive sync, Workmanager
```

## Local development

Requires Flutter SDK 3.2+:

```bash
cd mobile
flutter pub get
flutter run
```

## CI build

Push to `main` or run the **Flutter Android Build** workflow. Download the APK from Actions artifacts.

See [docs/mobile/google-setup.md](../docs/mobile/google-setup.md) for OAuth configuration.
