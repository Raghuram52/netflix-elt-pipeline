-- Singular data test: a title cannot have been added to Netflix in the future.
-- Returns offending rows; dbt fails the test if any come back.

select
    show_id,
    date_added
from {{ ref('stg_netflix') }}
where date_added > current_date
