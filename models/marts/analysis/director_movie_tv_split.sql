-- Q1: For each director, count movies vs TV shows in separate columns,
-- keeping only directors who have made both.
select
    d.director,
    count(distinct case when t.type = 'Movie'   then t.show_id end) as no_of_movies,
    count(distinct case when t.type = 'TV Show' then t.show_id end) as no_of_tv_shows
from {{ ref('dim_title') }} t
join {{ ref('bridge_title_director') }} b on t.title_key = b.title_key
join {{ ref('dim_director') }} d          on b.director_key = d.director_key
group by d.director
having count(distinct t.type) > 1
