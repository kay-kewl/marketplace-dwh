from __future__ import annotations

from airflow import DAG
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

from common import DEFAULT_DAG_ARGS, DWH_CONN_ID, read_sql_file


with DAG(
    dag_id="purchases_mart_daily",
    schedule="0 2 * * *",
    default_args=DEFAULT_DAG_ARGS,
    start_date=__import__("datetime").datetime(2025, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["presentation", "purchase"],
    doc_md="""
    Ежедневный full-refresh витрины presentation.purchase_analytics.
    """,
) as dag:
    refresh_purchase_mart = SQLExecuteQueryOperator(
        task_id="refresh_purchase_mart",
        conn_id=DWH_CONN_ID,
        sql=read_sql_file("load_purchase_analytics.sql"),
    )

    refresh_purchase_mart