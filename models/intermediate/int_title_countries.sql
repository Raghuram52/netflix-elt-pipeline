-- Explode `country` into one row per (title, country), AND back-fill missing
-- countries the way the original project did: if a title has no country but its
-- director has a known country on another title, borrow that.
--
-- This preserves the tutorial's imputation intent, but expresses it as a clean,
-- testable model with the fallback logic made explicit.

with base as (

    select show_id, country, director
    from {{ ref('stg_netflix') }}

),

-- Titles that already have a country: explode directly.
known as (

    select
        show_id,
        trim(unnest(string_split(country, ','))) as country
    from base
    where country is not null

),

-- Director -> a representative country, from titles where it IS known.
director_country as (

    select
        d.director,
        min(k.country) as country   -- deterministic pick when a director spans countries
    from {{ ref('int_title_directors') }} d
    join known k on d.show_id = k.show_id
    group by d.director

),

-- Titles missing a country: try to recover it via the director.
backfilled as (

    select
        b.show_id,
        dc.country
    from base b
    join {{ ref('int_title_directors') }} d on b.show_id = d.show_id
    join director_country dc on d.director = dc.director
    where b.country is null

),

combined as (

    select show_id, country from known
    union
    select show_id, country from backfilled

)

select distinct
    show_id,
    country
from combined
where country is not null and country <> ''
