-- Genre dimension: the distinct set of genres, each with a surrogate key.

select
    {{ dbt_utils.generate_surrogate_key(['genre']) }} as genre_key,
    genre
from (
    select distinct genre
    from {{ ref('int_title_genres') }}
)
