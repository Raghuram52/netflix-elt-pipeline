-- Q5: Directors who have made BOTH horror and comedy movies, with each count.
select
    d.director,
    count(distinct case when g.genre = 'Comedies'      then t.show_id end) as no_of_comedy,
    count(distinct case when g.genre = 'Horror Movies' then t.show_id end) as no_of_horror
from {{ ref('dim_title') }} t
join {{ ref('bridge_title_director') }} bd on t.title_key = bd.title_key
join {{ ref('dim_director') }} d           on bd.director_key = d.director_key
join {{ ref('bridge_title_genre') }} bg    on t.title_key = bg.title_key
join {{ ref('dim_genre') }} g              on bg.genre_key = g.genre_key
where t.type = 'Movie' and g.genre in ('Comedies', 'Horror Movies')
group by d.director
having count(distinct g.genre) = 2
