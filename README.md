# Netflix ELT Pipeline

A tested, reproducible ELT pipeline that turns the raw Netflix catalogue into a
documented dimensional model and a set of analytics tables. Built with **dbt** on
**DuckDB**, validated at the ingestion boundary with **pandera**, orchestrated with
**Airflow**, and verified in **CI on every push**.

The whole thing runs cold from a fresh clone with one command — no database to
install, no credentials, no manual steps:

```bash
make setup && make run
```

That builds a warehouse, validates and loads 8,807 titles, materialises the models,
and runs 41 data tests. If any test fails, the run fails.

---

## Why this exists / what it demonstrates

This started as a SQL analysis of the Netflix catalogue. It was rebuilt as an
engineering project to demonstrate the things that separate a data *engineer* from
someone who wrote a query that ran once:

- **Reproducibility** — clone and run, on any machine, with one command.
- **Data modelling on purpose** — a star schema with explicit grain, surrogate
  keys, and bridge tables for the many-to-many relationships.
- **Data quality as a deliverable** — a validation contract at ingestion plus 41
  dbt tests (uniqueness, not-null, referential integrity, accepted values, ranges).
- **Automation** — CI runs the full pipeline on every push; an Airflow DAG
  sequences it on a schedule.
- **Right-sizing** — see the note at the bottom on why this is DuckDB and not Spark.

---

## Architecture

```
data/netflix_titles.csv
        │
        ▼  ingest/ingest.py  ── validates against a pandera contract (ingest/schema.py),
        │                        then create-or-replace loads to raw.netflix_raw (idempotent)
        ▼
   raw.netflix_raw
        │
        ▼  dbt
  ┌───────────────────────────────────────────────────────────────────────┐
  │ staging/      stg_netflix          dedup, type-cast, parse dates,       │
  │                                     split duration → minutes / seasons  │
  │ intermediate/ int_title_genres     explode comma-packed columns;        │
  │               int_title_directors   back-fill missing country via       │
  │               int_title_countries   the title's director                │
  │ marts/        dim_title  dim_genre  star schema: surrogate keys +        │
  │               dim_director dim_country   3 bridge tables (M:N)           │
  │               bridge_title_genre / _director / _country                  │
  │ marts/analysis/  7 analytics tables (5 rebuilt questions + 2 original)   │
  └───────────────────────────────────────────────────────────────────────┘
        │
        ▼  41 dbt data tests + 1 pandera contract   ──►  CI gate on every push
```

Run `dbt docs generate && dbt docs serve` (or `make docs`) for the full interactive
lineage graph.

---

## The dimensional model

The raw file is one wide table with comma-packed lists (`listed_in`, `director`,
`country`, `cast`) and nulls. That is fine to *land*, but wrong to *analyse* — a
title has many genres, a genre has many titles. The model resolves this into a star:

| Table | Grain | Notes |
| --- | --- | --- |
| `dim_title` | one row per title | `title_key` surrogate + `show_id` natural key; `duration_minutes` / `num_seasons` split out of the overloaded `duration` string |
| `dim_genre` | one row per genre | |
| `dim_director` | one row per director | |
| `dim_country` | one row per country | |
| `bridge_title_genre` | one row per (title, genre) | resolves the M:N |
| `bridge_title_director` | one row per (title, director) | resolves the M:N |
| `bridge_title_country` | one row per (title, country) | resolves the M:N |

Every bridge key is tested with a `relationships` test back to its dimension, so a
broken join fails the build rather than silently dropping rows. (During development
one of those tests caught a real key-mapping bug — which is the point of having them.)

---

## Data quality

Two layers, deliberately:

1. **Ingestion contract (pandera).** `ingest/schema.py` asserts the shape of the raw
   file before a single row is written: `show_id` present and unique, `type` in
   `{Movie, TV Show}`, `release_year` a plausible integer, no unexpected columns
   (schema-drift guard). A malformed CSV is rejected at the door.
2. **Warehouse tests (dbt).** 41 tests including primary-key uniqueness on every
   dimension, referential integrity on every bridge, `accepted_values` on `type`, a
   positive-range check on `duration_minutes`, and a singular test asserting no title
   was "added" to Netflix in the future.

---

## Analytics

Seven analysis tables under `models/marts/analysis/`. Five are the original catalogue
questions, rebuilt on the star schema (and with the original's broken comedy-country
join fixed). Two are **new** — the kind a stakeholder actually asks:

- **`content_mix_by_year`** — movies vs TV shows added per year, and TV's rising share
  of additions.
- **`acquisition_lag`** — years between a title's release and its arrival on Netflix,
  by release decade. The median drops monotonically from ~29 years for early-1990s
  titles to 0 for 2020–21 — a clean, data-driven picture of Netflix shifting from
  licensing old catalogue to same-year originals.

Selected results (computed by the pipeline, not hand-entered):

- Most comedy movies by country: **United States (684)**, India (336), Canada (95).
- **83** directors have made both a movie and a TV show; **55** have made both a
  horror and a comedy movie.

---

## Running it

### Default: DuckDB (zero infrastructure)

```bash
make setup   # pip install -r requirements.txt && dbt deps
make run     # ingest (validate + load) -> dbt build -> dbt test
make docs    # optional: interactive lineage + model docs
```

### Production-like: Postgres in Docker

The same models run against a real client/server warehouse by swapping the target:

```bash
docker compose up -d                 # Postgres 16 on :5432
export TARGET=postgres
export POSTGRES_URL=postgresql+psycopg2://netflix:netflix@localhost:5432/netflix
python -m ingest.ingest
dbt build --target postgres
```

Snowflake or BigQuery would be one more `outputs:` block in `profiles.yml` — the
models don't change. That portability is the reason transformations live in dbt
rather than in engine-specific SQL.

---

## Orchestration & CI

- **CI** (`.github/workflows/ci.yml`) runs ingest → build → test → docs on every push
  and pull request. A green check means the data contracts and every transformation
  are verified, not merely that the code parses.
- **Airflow** (`dags/netflix_elt_dag.py`) sequences the same steps on a schedule with
  retries and task dependencies.

---

## Project layout

```
├── data/netflix_titles.csv        # source data
├── ingest/
│   ├── schema.py                  # pandera data contract
│   └── ingest.py                  # validated, idempotent loader (duckdb | postgres)
├── models/
│   ├── staging/stg_netflix.sql
│   ├── intermediate/int_title_*.sql
│   └── marts/
│       ├── dim_*.sql  bridge_*.sql
│       └── analysis/*.sql
├── tests/                         # singular data tests
├── dags/netflix_elt_dag.py        # Airflow orchestration
├── .github/workflows/ci.yml       # CI gate
├── docker-compose.yml             # Postgres target
├── profiles.yml  dbt_project.yml  packages.yml
├── Makefile                       # make setup / run / docs / clean
└── requirements.txt
```

---

## A note on right-sizing (deliberate)

This dataset is ~8,807 rows. It would run in memory in Excel. So the tooling is
matched to the *problem*, not chosen to pad a résumé:

- **DuckDB, not Spark/Kafka.** Distributed compute and streaming on 8.8k static rows
  would be theatre. The dimensional model, tests, orchestration, and CI here are the
  skills that transfer to a billion-row feed; the engine is not. The natural switch
  point to a distributed engine is when data stops fitting comfortably in one machine's
  memory and jobs stop finishing in seconds — not before.
- **Postgres path included** to prove the models are warehouse-portable, and the
  incremental pattern is where this scales: swap the ingest step for an incremental
  extract and make the fact/bridge models `incremental` to load only new titles.

Building the small version well — tested, reproducible, documented — is the point.
