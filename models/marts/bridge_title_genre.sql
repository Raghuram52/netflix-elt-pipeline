-- Bridge: resolves the many-to-many between titles and genres.
-- Grain: one row per (title, genre). Keyed to both dimensions by surrogate key.

select
    {{ dbt_utils.generate_surrogate_key(['g.show_id']) }} as title_key,
    {{ dbt_utils.generate_surrogate_key(['g.genre']) }}   as genre_key
from {{ ref('int_title_genres') }} g
