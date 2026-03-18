from __future__ import annotations

from datetime import timedelta
from pathlib import Path


DWH_CONN_ID = "dwh_postgres"

DEFAULT_DAG_ARGS = {
    "owner": "data-platform",
    "depends_on_past": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}


def read_sql_file(file_name: str) -> str:
    sql_path = Path(__file__).resolve().parents[1] / "sql" / file_name
    return sql_path.read_text(encoding="utf-8")