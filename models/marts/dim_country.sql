-- Country dimension: the distinct set of countries, each with a surrogate key.

select
    {{ dbt_utils.generate_surrogate_key(['country']) }} as country_key,
    country
from (
    select distinct country
    from {{ ref('int_title_countries') }}
)
