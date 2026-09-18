-- Explode the comma-separated `director` into one row per (title, director).

with exploded as (

    select
        show_id,
        trim(unnest(string_split(director, ','))) as director
    from {{ ref('stg_netflix') }}
    where director is not null

)

select distinct
    show_id,
    director
from exploded
where director is not null and director <> ''
