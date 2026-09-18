-- ORIGINAL (not in the tutorial): acquisition lag — how many years pass between a
-- title's release and its arrival on Netflix, by decade of release. Surfaces the
-- shift from licensing older catalogue to same-year originals.
with lagged as (
    select
        show_id,
        type,
        release_year,
        extract(year from date_added) - release_year as years_to_netflix,
        (release_year / 10) * 10                      as release_decade
    from {{ ref('dim_title') }}
    where date_added is not null
      and extract(year from date_added) >= release_year   -- guard against bad dates
)
select
    release_decade,
    count(*)                              as titles,
    round(avg(years_to_netflix), 1)       as avg_years_to_netflix,
    median(years_to_netflix)              as median_years_to_netflix
from lagged
group by release_decade
order by release_decade
