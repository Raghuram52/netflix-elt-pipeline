-- Bridge: many-to-many between titles and countries.
-- Grain: one row per (title, country).

select
    {{ dbt_utils.generate_surrogate_key(['c.show_id']) }} as title_key,
    {{ dbt_utils.generate_surrogate_key(['c.country']) }} as country_key
from {{ ref('int_title_countries') }} c
