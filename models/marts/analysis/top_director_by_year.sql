-- Q3: For each year (by date_added), the director with the most movies added.
with per_year as (
    select
        d.director,
        extract(year from t.date_added) as year_added,
        count(t.show_id) as no_of_movies
    from {{ ref('dim_title') }} t
    join {{ ref('bridge_title_director') }} b on t.title_key = b.title_key
    join {{ ref('dim_director') }} d          on b.director_key = d.director_key
    where t.type = 'Movie' and t.date_added is not null
    group by d.director, extract(year from t.date_added)
),
ranked as (
    select *,
        row_number() over (partition by year_added order by no_of_movies desc, director) as rn
    from per_year
)
select year_added, director, no_of_movies
from ranked
where rn = 1
order by year_added
