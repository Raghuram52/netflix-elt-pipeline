"""Load the raw Netflix CSV into the warehouse — validated and idempotent.

Two properties a hiring manager looks for and this script guarantees:

1. **Validated at the boundary.** The CSV is checked against a pandera contract
   (ingest/schema.py) before it is written anywhere. Bad data fails loudly here.
2. **Idempotent.** The load is replace-semantics (create-or-replace), so running
   this twice does not double the data. The tutorial version used
   `if_exists="append"`, which silently duplicated every row on re-run — the exact
   footgun this rewrite removes.

Engine choice: DuckDB by default (zero infrastructure, runs in CI with no services).
A Postgres target is available by setting TARGET=postgres — see README.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pandas as pd

from ingest.schema import RAW_NETFLIX_SCHEMA

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CSV = PROJECT_ROOT / "data" / "netflix_titles.csv"
DEFAULT_DUCKDB = PROJECT_ROOT / "netflix.duckdb"

RAW_SCHEMA = "raw"
RAW_TABLE = "netflix_raw"


def read_and_validate(csv_path: Path) -> pd.DataFrame:
    """Read the CSV and enforce the data contract. Raises on violation."""
    df = pd.read_csv(csv_path, dtype=str)
    # release_year is the only non-string column in the contract.
    df["release_year"] = pd.to_numeric(df["release_year"], errors="coerce").astype("Int64")
    validated = RAW_NETFLIX_SCHEMA.validate(df, lazy=True)
    return validated


def load_duckdb(df: pd.DataFrame, db_path: Path) -> None:
    """Create-or-replace the raw table in DuckDB (idempotent)."""
    import duckdb

    con = duckdb.connect(str(db_path))
    try:
        con.execute(f"CREATE SCHEMA IF NOT EXISTS {RAW_SCHEMA};")
        con.register("df_view", df)
        con.execute(
            f"CREATE OR REPLACE TABLE {RAW_SCHEMA}.{RAW_TABLE} AS "
            f"SELECT * FROM df_view;"
        )
        n = con.execute(
            f"SELECT COUNT(*) FROM {RAW_SCHEMA}.{RAW_TABLE};"
        ).fetchone()[0]
        print(f"[ingest] loaded {n:,} rows into {RAW_SCHEMA}.{RAW_TABLE} (duckdb)")
    finally:
        con.close()


def load_postgres(df: pd.DataFrame) -> None:
    """Create-or-replace the raw table in Postgres (idempotent)."""
    import sqlalchemy as sa

    url = os.environ["POSTGRES_URL"]  # e.g. postgresql+psycopg2://user:pass@host:5432/db
    engine = sa.create_engine(url)
    with engine.begin() as conn:
        conn.execute(sa.text(f"CREATE SCHEMA IF NOT EXISTS {RAW_SCHEMA};"))
        df.to_sql(
            RAW_TABLE,
            con=conn,
            schema=RAW_SCHEMA,
            index=False,
            if_exists="replace",  # replace, never append
        )
    print(f"[ingest] loaded {len(df):,} rows into {RAW_SCHEMA}.{RAW_TABLE} (postgres)")


def main() -> int:
    csv_path = Path(os.environ.get("SOURCE_CSV", DEFAULT_CSV))
    target = os.environ.get("TARGET", "duckdb").lower()

    if not csv_path.exists():
        print(f"[ingest] ERROR: source CSV not found at {csv_path}", file=sys.stderr)
        return 1

    print(f"[ingest] reading + validating {csv_path.name} against data contract...")
    try:
        df = read_and_validate(csv_path)
    except Exception as exc:  # pandera raises SchemaErrors under lazy=True
        print("[ingest] DATA CONTRACT VIOLATION — refusing to load:", file=sys.stderr)
        print(exc, file=sys.stderr)
        return 2

    print(f"[ingest] contract satisfied: {len(df):,} rows, {len(df.columns)} columns")

    if target == "postgres":
        load_postgres(df)
    else:
        db_path = Path(os.environ.get("DUCKDB_PATH", DEFAULT_DUCKDB))
        load_duckdb(df, db_path)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
