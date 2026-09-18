-- Q4: Average movie runtime per genre.
select
    g.genre,
    round(avg(t.duration_minutes), 1) as avg_duration_minutes,
    count(*)                          as movie_count
from {{ ref('dim_title') }} t
join {{ ref('bridge_title_genre') }} bg on t.title_key = bg.title_key
join {{ ref('dim_genre') }} g            on bg.genre_key = g.genre_key
where t.type = 'Movie' and t.duration_minutes is not null
group by g.genre
order by avg_duration_minutes desc
