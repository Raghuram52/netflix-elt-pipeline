-- Explode the comma-separated `listed_in` into one row per (title, genre).
-- Replaces the tutorial's CROSS APPLY STRING_SPLIT with portable standard SQL.

with exploded as (

    select
        show_id,
        trim(unnest(string_split(listed_in, ','))) as genre
    from {{ ref('stg_netflix') }}

)

select distinct
    show_id,
    genre
from exploded
where genre is not null and genre <> ''
