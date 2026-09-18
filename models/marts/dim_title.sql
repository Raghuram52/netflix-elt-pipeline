-- Title dimension. One row per title (show_id is the natural key; we also mint a
-- surrogate for join stability across the warehouse).

select
    {{ dbt_utils.generate_surrogate_key(['show_id']) }} as title_key,
    show_id,
    type,
    title,
    date_added,
    release_year,
    rating,
    duration_minutes,
    num_seasons,
    description
from {{ ref('stg_netflix') }}
