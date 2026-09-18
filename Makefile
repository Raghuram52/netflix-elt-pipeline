# One-command pipeline for the Netflix ELT project.
#
#   make setup   # install python deps + dbt packages
#   make run     # ingest -> build -> test  (the whole pipeline, cold)
#   make ingest  # validate + load the CSV into the warehouse (idempotent)
#   make build   # run dbt models
#   make test    # run dbt data tests
#   make docs    # build + serve the dbt lineage/docs site
#   make clean   # remove the local warehouse + dbt artifacts

export DBT_PROFILES_DIR := $(CURDIR)
export DUCKDB_PATH := $(CURDIR)/netflix.duckdb

.PHONY: setup ingest build test run docs clean

setup:
	pip install -r requirements.txt
	dbt deps

ingest:
	python -m ingest.ingest

build:
	dbt build --select staging intermediate marts

test:
	dbt test

# The full pipeline, reproducible from a clean checkout.
run: ingest
	dbt build

docs:
	dbt docs generate
	dbt docs serve

clean:
	rm -f $(DUCKDB_PATH) $(DUCKDB_PATH).wal
	rm -rf target dbt_packages logs
