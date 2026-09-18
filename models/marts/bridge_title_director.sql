-- Bridge: many-to-many between titles and directors.
-- Grain: one row per (title, director).

select
    {{ dbt_utils.generate_surrogate_key(['d.show_id']) }}  as title_key,
    {{ dbt_utils.generate_surrogate_key(['d.director']) }} as director_key
from {{ ref('int_title_directors') }} d
