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

## Metadata columns (AA–BA)

Row 1 headers for app sync metadata. Row 2 stays blank for these columns. Data rows (from row 3) are filled by the app on sync. Template file: [Daily Expenses.xlsx](./Daily%20Expenses.xlsx).

| Col | Header (row 1) | App field |
|---|---|---|
| AA | Transaction ID | `Transaction.id` (UUID) |
| AB | Type | `Income` / `Expense` |
| AC | Category | `Transaction.category` |
| AD | Gross Amount | Full amount before cashback |
| AE | Net Amount | Amount written to Credit/Debit column |
| AF | Cashback | `Transaction.cashbackReceived` |
| AG | Source ID | `PaymentSource.id` |
| AH | Source Name | `PaymentSource.name` |
| AI | Source Type | `BANK` / `CREDIT_CARD` / `CASH` |
| AJ | Method ID | `PaymentMethod.id` |
| AK | Method Name | `PaymentMethod.name` |
| AL | App ID | `PaymentApp.id` |
| AM | App Name | `PaymentApp.name` |
| AN | Notes | `Transaction.notes` |
| AO | Parent Txn ID | Cashback or split reimbursement → original expense |
| AP | Split ID | `BillSplit.id` |
| AQ | Split Type | `equal` / `custom` |
| AR | Split Summary | Human-readable member shares |
| AS | Split Settled | `Yes` / `No` |
| AT | Split Details (IDs) | `contactId:amount\|…` |
| AU | My Share | Payer share on split expense |
| AV | Group ID | `Group.id` |
| AW | Group Name | `Group.name` |
| AX | Settlement Contact ID | On reimbursement income rows |
| AY | Settlement Contact Name | On reimbursement income rows |
| AZ | Updated At | ISO datetime |
| BA | Sync Source | `app` (future: `sheet` for bidirectional sync) |

## Payment Source → Column Mapping

Each payment source stores its sheet columns in the local database (`sheet_credit_column`, `sheet_debit_column`, `sheet_balance_column`). The seven default accounts are pre-mapped to columns D–Y; metadata starts at column **AA** (index 26).

### Adding a new account (automatic)

When you create a new payment source in **Accounts**:

1. The app inserts **3 columns** in Google Sheet immediately before the metadata block (requires Google sign-in).
2. Row 1: account name · Row 2: Credit · Debit · Balance (or **Bill Total** for credit cards).
3. Column letters are saved on the source — sync, import, and balances use them like existing accounts.
4. The metadata block (Transaction ID … Sync Source) shifts right by 3 columns; the app tracks the new start index in `sync_state.metadata_start_column_index`.

If Google is not signed in when you save the account, columns are created on the next **Sync now**.

**Note:** Sheet summary formulas such as **Total In Bank (M)** and **Total Balance (Z)** are not rewritten automatically when new account columns are inserted. You may want to extend those formulas manually to include new bank columns.

Legacy hardcoded defaults (for reference):

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
{D..Z} = empty except the matched source's Credit OR Debit cell
{AA..BA} = transaction metadata (IDs, names, split, etc.)
```

- **EXPENSE:** write net amount (`amount - cashbackReceived`) in **Debit** column for the payment source.
- **INCOME:** write amount in **Credit** column for the payment source.
- **Cashback income** (linked INCOME txn): write in credit column of `creditSource`.

## Sync Strategy

1. Local registry file `spendwise_sheet_sync.json` (beside SQLite DB) tracks each synced transaction:
   - `sheetRowNumber` — row in Sheet1
   - `syncedUpdatedAt` — app `updated_at` when last pushed
2. **Sync now** (app → sheet only; sheet is not edited manually):
   - **Append** transactions not in the registry
   - **Update** existing sheet row when app `updated_at` is newer than `syncedUpdatedAt`
   - **Skip** unchanged transactions already synced
3. Uses Sheets API `append` for new rows and `batchUpdate` for changed rows (never overwrites balance/formula columns).
4. Range: `Sheet1!A:BA` with metadata in AA–BA.
5. **Import from Google Sheet** (sheet → app): separate action; only rows with non-empty column C (description). Missing metadata columns import as `unknown`.

## Drive Backup

Upload `spendwise-backup-YYYY-Www.json` (one file per ISO week) containing full local DB export to Google Drive folder `SpendWise Backups`. Syncing again in the same week replaces that file; a new file is created when the week changes.

## Import from Google Sheet (app ← sheet)

In the app: **Settings → Import from Google Sheet**

- Reads all data rows from `Sheet1` starting at row 3 (`A3:BA`)
- **Skips rows with empty description (column C)**
- Maps columns to accounts in the app **and** row 1–2 sheet headers (Credit / Debit / Balance or Bill Total)
- **New accounts from headers** (e.g. Kotak Bank) are added automatically before import
- **Credit and debit must be greater than zero** to import a transaction
- Metadata columns AA–BA: uses values when present; missing fields stored as `unknown`
- Registers each imported row in `spendwise_sheet_sync.json` with sheet row number
- **Opening balances (first import / Replace & import):** reads the **last dated row** in the sheet and sets each account balance from its **Balance** column (banks, cash) or **Bill Total** column (credit cards). These values override a transaction-sum recalculation.

Requires Google sign-in (same as sync).
