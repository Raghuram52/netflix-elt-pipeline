-- Director dimension: the distinct set of directors, each with a surrogate key.

select
    {{ dbt_utils.generate_surrogate_key(['director']) }} as director_key,
    director
from (
    select distinct director
    from {{ ref('int_title_directors') }}
)
