"""Simulate SpendWise sheet import rules on a CSV export."""
import csv
import sys
from datetime import datetime, timedelta

EPOCH = datetime(1899, 12, 30)
METADATA_START = 26
FIRST_ACCOUNT = 3


def cell(row, i):
    if i < 0 or i >= len(row):
        return ""
    return (row[i] or "").strip()


def parse_amount(val):
    if val is None:
        return None
    s = str(val).strip().replace(",", "").replace("₹", "")
    if not s:
        return None
    try:
        return float(s)
    except ValueError:
        return None


def parse_date(col_a, col_b):
    for v in (col_b, col_a):
        if v is None:
            continue
        s = str(v).strip()
        if not s:
            continue
        try:
            n = float(s)
            if n > 1000:
                return EPOCH + timedelta(days=int(n))
        except ValueError:
            pass
        for sep in ("/", "-"):
            parts = s.split(sep)
            if len(parts) != 3:
                continue
            try:
                d1, d2, y = int(parts[0]), int(parts[1]), int(parts[2])
            except ValueError:
                continue
            if y < 1900:
                continue
            if d1 > 12:
                return datetime(y, d2, d1)
            if d2 > 12:
                return datetime(y, d1, d2)
            return datetime(y, d2, d1)
    return None


def clean_desc(raw):
    desc = raw.strip()
    for suffix in (" [cashback]", " [split:"):
        idx = desc.find(suffix)
        if idx > 0:
            desc = desc[:idx].strip()
    return desc


def account_name_from_header(header, col):
    for i in range(col, -1, -1):
        name = cell(header, i)
        if name:
            return name
    return ""


def is_summary(name):
    lower = name.lower()
    return "total in bank" in lower or lower == "total balance"


def infer_source_type(name, bill_total):
    if bill_total:
        return "CREDIT_CARD"
    lower = name.lower()
    if "cash" in lower:
        return "CASH"
    if "wallet" in lower:
        return "WALLET"
    if "credit card" in lower or lower.endswith(" cc"):
        return "CREDIT_CARD"
    if "debit card" in lower:
        return "DEBIT_CARD"
    return "BANK"


def mappings_from_headers(header, sub):
    mappings = []
    col = FIRST_ACCOUNT
    max_col = min(METADATA_START, len(sub))
    while col + 2 < max_col:
        credit_l = cell(sub, col).lower()
        debit_l = cell(sub, col + 1).lower()
        third_l = cell(sub, col + 2).lower()
        if (
            credit_l == "credit"
            and debit_l == "debit"
            and third_l in ("balance", "bill total")
        ):
            name = account_name_from_header(header, col)
            if name and not is_summary(name):
                mappings.append(
                    {
                        "name": name,
                        "credit_idx": col,
                        "debit_idx": col + 1,
                        "type": infer_source_type(name, third_l == "bill total"),
                    }
                )
            col += 3
        else:
            col += 1
    return mappings


def main():
    csv_path = (
        sys.argv[1]
        if len(sys.argv) > 1
        else r"C:\Users\Joseph Ashish\Downloads\Daily Expenses - Copy of Sheet1.csv"
    )

    with open(csv_path, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.reader(f))

    header = rows[0]
    sub = rows[1] if len(rows) > 1 else []
    data_rows = rows[2:]

    mappings = mappings_from_headers(header, sub)

    parsed = 0
    rows_no_date = 0
    rows_no_desc = 0
    rows_no_txn = 0
    rows_with_txn = 0
    multi_txn_rows = 0
    by_account = {}

    for i, row in enumerate(data_rows, start=3):
        date = parse_date(cell(row, 0), cell(row, 1))
        if not date:
            rows_no_date += 1
            continue
        desc = clean_desc(cell(row, 2))
        if not desc:
            rows_no_desc += 1
            continue

        row_txns = 0
        for m in mappings:
            credit = parse_amount(cell(row, m["credit_idx"]))
            debit = parse_amount(cell(row, m["debit_idx"]))
            if credit is not None and credit > 0:
                parsed += 1
                row_txns += 1
                by_account[m["name"]] = by_account.get(m["name"], 0) + 1
            if debit is not None and debit > 0:
                parsed += 1
                row_txns += 1
                by_account[m["name"]] = by_account.get(m["name"], 0) + 1

        if row_txns == 0:
            rows_no_txn += 1
        else:
            rows_with_txn += 1
            if row_txns > 1:
                multi_txn_rows += 1

    print(f"File: {csv_path}")
    print(f"Total lines: {len(rows)}")
    print(f"Data rows (sheet row 3+): {len(data_rows)}")
    print(f"Accounts from headers: {len(mappings)}")
    print(f"ACCEPTED transactions: {parsed}")
    print(f"Rows with >=1 transaction: {rows_with_txn}")
    print(f"Skipped - no date: {rows_no_date}")
    print(f"Skipped - no description: {rows_no_desc}")
    print(f"Skipped - no credit/debit > 0: {rows_no_txn}")
    print(f"Rows with 2+ transactions: {multi_txn_rows}")
    print("By account:")
    for name, cnt in sorted(by_account.items(), key=lambda x: -x[1]):
        print(f"  {name}: {cnt}")


if __name__ == "__main__":
    main()
