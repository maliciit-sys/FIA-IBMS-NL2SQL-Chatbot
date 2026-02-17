#!/usr/bin/env python3
"""
setup_oracle_ibms.py
====================
Creates Oracle 19c schema (20 tables) and loads CSV data from data/raw/
Respects FK dependency order from schema_documentation.md

Usage:
    cd ~/ml-projects/python-projects/IBMS_LLM
    python scripts/setup_oracle_ibms.py
"""

import oracledb
import pandas as pd
import os
import sys
import time
from pathlib import Path

# ============================================================
# Configuration
# ============================================================
ORACLE_USER = "ibms_user"
ORACLE_PASS = "ibms_pass"
ORACLE_DSN = "localhost:1521/FREEPDB1"

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data" / "raw"
SCHEMA_FILE = PROJECT_ROOT / "scripts" / "oracle_schema.sql"

# FK-respecting load order (from schema_documentation.md)
LOAD_ORDER = [
    ("countries",            "countries.csv"),
    ("ports_of_entry",       "ports_of_entry.csv"),
    ("visa_categories",      "visa_categories.csv"),
    ("sponsors",             "sponsors.csv"),
    ("travelers",            "travelers.csv"),
    ("document_registry",    "document_registry.csv"),
    ("visa_applications",    "visa_applications.csv"),
    ("travel_records",       "travel_records.csv"),
    ("asylum_claims",        "asylum_claims.csv"),
    ("removal_orders",       "removal_orders.csv"),
    ("detention_records",    "detention_records.csv"),
    ("family_relationships", "family_relationships.csv"),
    ("watchlist",            "watchlist.csv"),
    ("ecl_entries",          "ecl_entries.csv"),
    ("trafficking_cases",    "trafficking_cases.csv"),
    ("illegal_crossings",    "illegal_crossings.csv"),
    ("offloading_records",   "offloading_records.csv"),
    ("risk_profiles",        "risk_profiles.csv"),
    ("suspect_networks",     "suspect_networks.csv"),
    ("audit_log",            "audit_log.csv"),
]

# Columns with DATE type (need to_date conversion)
DATE_COLUMNS = {
    "date_of_birth", "issue_date", "expiry_date", "application_date",
    "decision_date", "filing_date", "order_date", "execution_date",
    "intake_date", "release_date", "issued_date", "reported_date",
    "offload_date", "identified_date", "order_date", "travel_date",
}

# Columns with TIMESTAMP type
TIMESTAMP_COLUMNS = {
    "created_at", "entry_date", "exit_date", "detected_date",
    "action_timestamp", "last_updated",
}

BATCH_SIZE = 5000


def get_connection():
    """Create Oracle connection using thin mode (no Instant Client needed)."""
    return oracledb.connect(user=ORACLE_USER, password=ORACLE_PASS, dsn=ORACLE_DSN)


def execute_schema(conn):
    """Execute Oracle DDL schema file to create all 20 tables."""
    print("=" * 60)
    print("STEP 1: Creating Oracle schema (20 tables + indexes)")
    print("=" * 60)

    with open(SCHEMA_FILE, "r") as f:
        schema_sql = f.read()

    # Split on '/' which is the PL/SQL block separator for the DROP statements
    # and on ';' for CREATE/INDEX statements
    cursor = conn.cursor()

    # First execute PL/SQL blocks (DROP statements)
    plsql_blocks = []
    current_block = []
    in_plsql = False

    for line in schema_sql.split("\n"):
        stripped = line.strip()

        if stripped.startswith("BEGIN"):
            in_plsql = True
            current_block = [line]
        elif stripped == "/" and in_plsql:
            plsql_blocks.append("\n".join(current_block))
            current_block = []
            in_plsql = False
        elif in_plsql:
            current_block.append(line)

    # Execute DROP blocks
    for block in plsql_blocks:
        try:
            cursor.execute(block)
        except Exception as e:
            pass  # Table might not exist, that's fine

    conn.commit()
    print(f"  Dropped existing tables (if any)")

    # Now execute CREATE TABLE and CREATE INDEX statements
    # Remove all PL/SQL blocks first
    remaining_sql = schema_sql
    for block in plsql_blocks:
        remaining_sql = remaining_sql.replace(block, "")
    remaining_sql = remaining_sql.replace("\n/\n", "\n")

    # Split by semicolon, filter empty
    statements = [s.strip() for s in remaining_sql.split(";") if s.strip()]

    created_tables = 0
    created_indexes = 0

    for stmt in statements:
        # Skip comments and empty lines
        if not stmt or stmt.startswith("--"):
            continue
        # Remove leading comments
        lines = [l for l in stmt.split("\n") if not l.strip().startswith("--")]
        clean_stmt = "\n".join(lines).strip()
        if not clean_stmt:
            continue

        try:
            cursor.execute(clean_stmt)
            if "CREATE TABLE" in clean_stmt.upper():
                table_name = clean_stmt.split("(")[0].split()[-1]
                print(f"  ✓ Created table: {table_name}")
                created_tables += 1
            elif "CREATE INDEX" in clean_stmt.upper():
                created_indexes += 1
        except oracledb.DatabaseError as e:
            error_msg = str(e)
            if "ORA-00955" in error_msg:  # Name already used
                pass
            else:
                print(f"  ✗ Error: {error_msg[:120]}")
                print(f"    Statement: {clean_stmt[:100]}...")

    conn.commit()
    print(f"\n  Summary: {created_tables} tables, {created_indexes} indexes created")
    print()


def load_csv_to_table(conn, table_name, csv_file):
    """Load a single CSV file into an Oracle table using batch inserts."""
    csv_path = DATA_DIR / csv_file

    if not csv_path.exists():
        print(f"  ⚠ SKIP: {csv_file} not found")
        return 0

    # Read CSV
    df = pd.read_csv(csv_path, low_memory=False)
    total_rows = len(df)

    if total_rows == 0:
        print(f"  ⚠ SKIP: {csv_file} is empty")
        return 0

    # Replace NaN with None (Oracle NULL)
    df = df.where(pd.notnull(df), None)

    # Parse date columns
    for col in df.columns:
        if col in DATE_COLUMNS:
            df[col] = pd.to_datetime(df[col], errors="coerce", format="mixed")
            df[col] = df[col].where(pd.notnull(df[col]), None)
        elif col in TIMESTAMP_COLUMNS:
            df[col] = pd.to_datetime(df[col], errors="coerce", format="mixed")
            df[col] = df[col].where(pd.notnull(df[col]), None)

    # Build INSERT statement
    columns = df.columns.tolist()
    placeholders = ", ".join([f":{i+1}" for i in range(len(columns))])
    col_names = ", ".join(columns)
    insert_sql = f"INSERT INTO {table_name} ({col_names}) VALUES ({placeholders})"

    cursor = conn.cursor()
    loaded = 0
    errors = 0

    # Batch insert
    for start in range(0, total_rows, BATCH_SIZE):
        batch = df.iloc[start:start + BATCH_SIZE]
        rows = []
        for _, row in batch.iterrows():
            row_data = []
            for col in columns:
                val = row[col]
                if val is None:
                    row_data.append(None)
                elif col in DATE_COLUMNS or col in TIMESTAMP_COLUMNS:
                    # Convert pandas Timestamp to Python datetime
                    if pd.notnull(val):
                        row_data.append(val.to_pydatetime())
                    else:
                        row_data.append(None)
                elif isinstance(val, float) and val == int(val):
                    # Convert float IDs to int (pandas reads nullable int as float)
                    row_data.append(int(val))
                else:
                    row_data.append(val)
            rows.append(row_data)

        try:
            cursor.executemany(insert_sql, rows)
            loaded += len(rows)
        except oracledb.DatabaseError as e:
            # Fall back to row-by-row for this batch to skip bad rows
            for row_data in rows:
                try:
                    cursor.execute(insert_sql, row_data)
                    loaded += 1
                except oracledb.DatabaseError:
                    errors += 1

        # Progress
        pct = min(100, int((start + BATCH_SIZE) / total_rows * 100))
        print(f"\r  Loading {table_name}: {pct:3d}% ({loaded:,}/{total_rows:,})", end="", flush=True)

    conn.commit()
    error_msg = f" ({errors} errors)" if errors else ""
    print(f"\r  ✓ {table_name}: {loaded:,} rows loaded{error_msg}{'':30}")
    return loaded


def verify_tables(conn):
    """Print row counts for all tables."""
    print("=" * 60)
    print("VERIFICATION: Row counts")
    print("=" * 60)

    cursor = conn.cursor()
    total = 0

    for table_name, _ in LOAD_ORDER:
        try:
            cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
            count = cursor.fetchone()[0]
            total += count
            print(f"  {table_name:30s} {count:>10,}")
        except oracledb.DatabaseError:
            print(f"  {table_name:30s} {'ERROR':>10}")

    print(f"  {'─' * 42}")
    print(f"  {'TOTAL':30s} {total:>10,}")


def main():
    print("\n🔧 FIA-IBMS Oracle Database Setup")
    print(f"   Target: {ORACLE_USER}@{ORACLE_DSN}")
    print(f"   Data:   {DATA_DIR}\n")

    # Verify data directory
    csv_count = len(list(DATA_DIR.glob("*.csv")))
    print(f"   Found {csv_count} CSV files in data/raw/\n")

    conn = get_connection()

    try:
        # Step 1: Create schema
        execute_schema(conn)

        # Step 2: Load data
        print("=" * 60)
        print("STEP 2: Loading CSV data (respecting FK order)")
        print("=" * 60)

        start_time = time.time()
        total_loaded = 0

        for table_name, csv_file in LOAD_ORDER:
            rows = load_csv_to_table(conn, table_name, csv_file)
            total_loaded += rows

        elapsed = time.time() - start_time
        print(f"\n  Total: {total_loaded:,} rows loaded in {elapsed:.1f}s\n")

        # Step 3: Verify
        verify_tables(conn)

    finally:
        conn.close()

    print("\n✅ Setup complete. Oracle IBMS database is ready.\n")


if __name__ == "__main__":
    main()
