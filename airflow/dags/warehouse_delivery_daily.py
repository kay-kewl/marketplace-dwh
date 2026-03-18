from __future__ import annotations

from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

from common import DEFAULT_DAG_ARGS, DWH_CONN_ID, read_sql_file


def resolve_business_date(**context) -> str:
    conf = (context.get("dag_run") or {}).conf if context.get("dag_run") else {}
    if conf and conf.get("business_date"):
        return conf["business_date"]

    data_interval_start = context["data_interval_start"]
    return (data_interval_start.subtract(days=1)).to_date_string()


with DAG(
    dag_id="warehouse_delivery_daily",
    schedule="0 3 * * *",
    default_args=DEFAULT_DAG_ARGS,
    start_date=datetime(2025, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["presentation", "warehouse"],
    doc_md="""
    Ежедневное обновление витрины presentation.warehouse_delivery_daily за business_date
    """,
) as dag:
    get_business_date = PythonOperator(
        task_id="resolve_business_date",
        python_callable=resolve_business_date,
    )

    load_warehouse_daily = SQLExecuteQueryOperator(
        task_id="load_warehouse_daily",
        conn_id=DWH_CONN_ID,
        sql=read_sql_file("load_warehouse_delivery_daily.sql"),
    )

    get_business_date >> load_warehouse_daily