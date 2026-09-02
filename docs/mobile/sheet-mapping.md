# Google Sheet Mapping — Daily Expenses

## Spreadsheet

| Property | Value |
|---|---|
| Spreadsheet ID | `1ObWgYGp928tIva0FvWZyIcFNvLRkkG0gTRHrgyQ9JbU` |
| Target tab (Google gid) | `1320698518` |
| Excel tab name | `Sheet1` (primary data; `Copy of Sheet1` is a duplicate) |
| Form tab | `Form responses 3` (Google Form import — not synced by app) |

## Layout Type

**Running balance sheet** with per-account Credit / Debit / Balance (or Bill Total for credit cards) columns. Row 1–2 are headers; data starts at row 3. Balance and total columns use formulas — the app writes **data rows only** (Credit/Debit cells + metadata), never overwrites formula columns.

## Column Map (Sheet1)

| Col | Header (row 1) | Sub-header (row 2) | App field |
|---|---|---|---|
| A | Week | — | Derived weekday from transaction date |
| B | Date | — | `Transaction.timestamp` (Excel serial date) |
| C | Expense / Credit | — | `Transaction.description` |
| D | ICICI Bank | Credit | Income amount if source = ICICI Bank |
| E | | Debit | Expense amount if source = ICICI Bank |
| F | | Balance | **Formula — do not write** |
| G | BOB | Credit | Income if source = BOB |
| H | | Debit | Expense if source = BOB |
| I | | Balance | **Formula — do not write** |
| J | HDFC | Credit | Income if source = HDFC |
| K | | Debit | Expense if source = HDFC |
| L | | Balance | **Formula — do not write** |
| M | Total In Bank | — | **Formula — do not write** |
| N | Federal Bank Credit Card | Credit | Income / payment toward card |
| O | | Debit | Expense charged to Federal CC |
| P | | Bill Total | **Formula — do not write** |
| Q | HDFC Bank Credit Card | Credit | Income / payment toward card |
| R | | Debit | Expense charged to HDFC CC |
| S | | Bill Total | **Formula — do not write** |
| T | ICICI Bank Credit Card | Credit | Income / payment toward card |
| U | | Debit | Expense charged to ICICI CC |
| V | | Bill Total | **Formula — do not write** |
| W | Cash In Hand | Credit | Cash income |
| X | | Debit | Cash expense |
| Y | | Balance | **Formula — do not write** |
| Z | Total Balance | — | **Formula — do not write** |

## Payment Source → Column Mapping

Configure in app settings (`SheetColumnMapping`); defaults match the user's sheet:

| Payment source name (contains) | Source type | Credit col | Debit col |
|---|---|---|---|
| ICICI Bank | BANK | D | E |
| BOB | BANK | G | H |
| HDFC | BANK | J | K |
| Federal Bank Credit Card | CREDIT_CARD | N | O |
| HDFC Bank Credit Card | CREDIT_CARD | Q | R |
| ICICI Bank Credit Card | CREDIT_CARD | T | U |
| Cash In Hand | CASH | W | X |

Cashback income rows: append as separate row with description `"Cashback: {original}"`, credit to the cashback credit source column.

Split metadata: append to column C suffix `[split: contact names]` or store in notes column if extended later.

## Row Export Format

For each unsynced `Transaction`, produce one sheet row:

```
A = weekday name (Monday, Tuesday, …)
B = Excel serial date (days since 1899-12-30)
C = description (+ optional split/cashback note)
{D..AS} = empty except the matched source's Credit OR Debit cell
```

- **EXPENSE:** write net amount (`amount - cashbackReceived`) in **Debit** column for the payment source.
- **INCOME:** write amount in **Credit** column for the payment source.
- **Cashback income** (linked INCOME txn): write in credit column of `creditSource`.

## Sync Strategy

1. Track exported transaction UUIDs in local `sync_state.exported_transaction_ids` (JSON array).
2. On daily sync, query transactions where `id NOT IN exported_ids` OR `updated_at > last_sync_at`.
3. Use Sheets API `spreadsheets.values.append` on `Sheet1!A:AS` with `INSERT_ROWS`.
4. Resolve sheet name at runtime via `spreadsheets.get` (gid → sheet title).
5. Never import sheet → app in v1 (app is source of truth).

## Drive Backup

Upload `spendwise-backup-YYYY-MM-DD.json` containing full local DB export (all tables) to Google Drive folder `SpendWise Backups`.
