-- Staging: clean + de-duplicate the raw catalogue.
--
-- Design notes:
--   * De-dup on (title, type) with ROW_NUMBER, keeping the first show_id — this
--     is the tutorial's logic, but pushed into a dedicated, tested staging layer
--     instead of a one-off SELECT ... INTO.
--   * The raw `duration` column is overloaded: "90 min" for movies, "2 Seasons"
--     for TV shows, and — for a few rows — the *rating* leaked into it. We repair
--     the swap and then split duration into two typed columns.

with source as (

    select * from {{ source('raw', 'netflix_raw') }}

),

deduplicated as (

    select
        *,
        row_number() over (
            partition by upper(title), type
            order by show_id
        ) as rn
    from source

),

cleaned as (

    select
        show_id,
        type,
        title,
        director,
        country,
        "cast"                         as cast_members,
        -- date_added arrives as "September 25, 2021" (sometimes with stray
        -- whitespace); parse it explicitly rather than relying on an implicit cast.
        cast(try_strptime(trim(date_added), '%B %d, %Y') as date) as date_added,
        release_year,
        rating,
        listed_in,
        description,

        -- Repair the duration/rating swap: if duration is null but rating holds a
        -- duration-looking value, fall back to rating.
        coalesce(duration, rating)     as duration_raw
    from deduplicated
    where rn = 1

)

select
    show_id,
    type,
    title,
    director,
    country,
    cast_members,
    date_added,
    release_year,
    rating,
    listed_in,
    description,

    -- Movies: "90 min" -> 90. TV shows have no minutes.
    case
        when duration_raw like '%min%'
        then try_cast(replace(duration_raw, ' min', '') as integer)
    end as duration_minutes,

    -- TV shows: "2 Seasons" -> 2. Movies have no seasons.
    case
        when duration_raw like '%Season%'
        then try_cast(split_part(duration_raw, ' ', 1) as integer)
    end as num_seasons

from cleaned
