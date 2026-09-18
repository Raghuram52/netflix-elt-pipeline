"""Data contract for the raw Netflix catalogue.

Validation happens at the ingestion boundary: a malformed CSV is rejected here,
before anything reaches the warehouse. This is the "shift left" principle — catch
bad data at the door rather than debugging it three models deep.
"""

from __future__ import annotations

import pandera.pandas as pa
from pandera.pandas import Column, DataFrameSchema, Check

# The contract we expect the source file to satisfy. It is intentionally strict
# on the primary key and permissive on the columns that are known to be dirty
# (director, cast, country, date_added) — those are cleaned downstream in dbt,
# not rejected here.
RAW_NETFLIX_SCHEMA = DataFrameSchema(
    {
        "show_id": Column(str, nullable=False, unique=True),
        "type": Column(
            str,
            checks=Check.isin(["Movie", "TV Show"]),
            nullable=False,
        ),
        "title": Column(str, nullable=False),
        "director": Column(str, nullable=True),
        "cast": Column(str, nullable=True),
        "country": Column(str, nullable=True),
        "date_added": Column(str, nullable=True),
        "release_year": Column(
            int,
            checks=Check.in_range(1900, 2100),
            nullable=False,
        ),
        "rating": Column(str, nullable=True),
        "duration": Column(str, nullable=True),
        "listed_in": Column(str, nullable=False),
        "description": Column(str, nullable=True),
    },
    strict=True,       # reject unexpected columns — schema drift is a real failure mode
    coerce=True,
    name="raw_netflix",
)
