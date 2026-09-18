-- Q2: Country with the most comedy movies.
-- (Fixes the original's broken join, which accidentally cross-joined the title table.)
select
    c.country,
    count(distinct t.show_id) as no_of_comedy_movies
from {{ ref('dim_title') }} t
join {{ ref('bridge_title_genre') }}   bg on t.title_key = bg.title_key
join {{ ref('dim_genre') }} g            on bg.genre_key = g.genre_key
join {{ ref('bridge_title_country') }} bc on t.title_key = bc.title_key
join {{ ref('dim_country') }} c           on bc.country_key = c.country_key
where g.genre = 'Comedies' and t.type = 'Movie'
group by c.country
order by no_of_comedy_movies desc
