{{ config(materialized='table') }}

with date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2024-04-01' as date)",
        end_date="cast('2024-09-28' as date)"
    ) }}
),

campaign_windows as (
    select
        cast(start_date as date) as campaign_start,
        cast(end_date as date) as campaign_end
    from {{ ref('stg_campaign') }}
),

calculated as (
    select
        {{ dbt_utils.generate_surrogate_key(['date_spine.date_day']) }} as date_key,
        date_spine.date_day as full_date,
        year(date_spine.date_day) as year,
        quarter(date_spine.date_day) as quarter,
        month(date_spine.date_day) as month,
        week(date_spine.date_day) as week,
        dayofweek(date_spine.date_day) as day_of_week,
        dayname(date_spine.date_day) as day_name,

        case
            when (month(date_spine.date_day) = 1 and day(date_spine.date_day) = 1) then true
            when (month(date_spine.date_day) = 7 and day(date_spine.date_day) = 4) then true
            when (month(date_spine.date_day) = 12 and day(date_spine.date_day) = 25) then true
            when (month(date_spine.date_day) = 11 and dayofweek(date_spine.date_day) = 5
                  and day(date_spine.date_day) between 22 and 28) then true
            else false
        end as is_us_holiday,

        case
            when month(date_spine.date_day) in (12, 1, 2) then 'Winter'
            when month(date_spine.date_day) in (3, 4, 5) then 'Spring'
            when month(date_spine.date_day) in (6, 7, 8) then 'Summer'
            when month(date_spine.date_day) in (9, 10, 11) then 'Fall'
        end as season,

        exists (
            select 1 from campaign_windows
            where date_spine.date_day between campaign_windows.campaign_start and campaign_windows.campaign_end
        ) as is_campaign_active

    from date_spine
)

select * from calculated