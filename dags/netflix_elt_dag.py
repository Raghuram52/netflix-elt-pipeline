"""Airflow DAG for the Netflix ELT pipeline.

Orchestrates the pipeline as a scheduled, dependency-aware graph:

    ingest  ->  dbt_build  ->  dbt_test  ->  dbt_docs

Honesty note (and a deliberate talking point): for ~8.8k static rows this DAG is
more orchestration than the data needs. It is here to demonstrate the pattern —
scheduling, task dependencies, retries, and a clean separation between ingestion
and transformation — not because the volume demands Airflow. In production this
same shape scales to real feeds by swapping the ingest task for an incremental
extract and running dbt incremental models.

Drop this file into your Airflow `dags/` folder. It uses BashOperator so it has no
provider dependencies beyond core Airflow; a real deployment would likely use the
`astronomer-cosmos` package to render dbt models as native Airflow tasks.
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator

PROJECT_DIR = os.environ.get("NETFLIX_ELT_HOME", "/opt/netflix-elt")

default_args = {
    "owner": "data-eng",
    "retries": 2,
    "retry_delay": timedelta(minutes=1),
}

with DAG(
    dag_id="netflix_elt",
    description="Validate + ingest the Netflix catalogue, then build and test the dbt models.",
    default_args=default_args,
    schedule="@daily",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["dbt", "duckdb", "elt"],
) as dag:

    env = {
        "DBT_PROFILES_DIR": PROJECT_DIR,
        "DUCKDB_PATH": f"{PROJECT_DIR}/netflix.duckdb",
        "PATH": os.environ.get("PATH", ""),
    }

    ingest = BashOperator(
        task_id="ingest",
        bash_command=f"cd {PROJECT_DIR} && python -m ingest.ingest",
        env=env,
    )

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=f"cd {PROJECT_DIR} && dbt run",
        env=env,
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"cd {PROJECT_DIR} && dbt test",
        env=env,
    )

    dbt_docs = BashOperator(
        task_id="dbt_docs_generate",
        bash_command=f"cd {PROJECT_DIR} && dbt docs generate",
        env=env,
    )

    ingest >> dbt_build >> dbt_test >> dbt_docs
