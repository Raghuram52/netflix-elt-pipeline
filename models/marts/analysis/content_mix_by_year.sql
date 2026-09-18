-- ORIGINAL (not in the tutorial): how Netflix's content mix shifted over time.
-- Movies vs TV shows added per year, with the TV share of additions. This is the
-- kind of trend question a content/strategy stakeholder actually asks.
select
    extract(year from date_added)                                            as year_added,
    count(case when type = 'Movie'   then 1 end)                             as movies_added,
    count(case when type = 'TV Show' then 1 end)                             as tv_shows_added,
    count(*)                                                                  as total_added,
    round(
        100.0 * count(case when type = 'TV Show' then 1 end) / count(*), 1
    )                                                                        as tv_share_pct
from {{ ref('dim_title') }}
where date_added is not null
group by extract(year from date_added)
order by year_added
