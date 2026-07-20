with src_campaign as (
    select * from {{ ref('campaign') }}
),

parsed as (
    select
        campaign_id,
        initcap(trim(raw_json:campaign_name::string)) as campaign_name,
        initcap(trim(raw_json:campaign_type::string)) as campaign_type,
        raw_json:channel::string as channel,
        raw_json:description::string as description,
        raw_json:target_audience::string as target_audience,

        try_to_decimal(
            regexp_replace(raw_json:budget::string, '[$,]', ''),
            38, 2
        ) as budget,

        try_to_decimal(
            regexp_replace(raw_json:total_cost::string, '[$,]', ''),
            38, 2
        ) as total_cost,

        try_to_decimal(
            regexp_replace(raw_json:total_revenue::string, '[$,]', ''),
            38, 2
        ) as total_revenue,

        raw_json:roi_calculation::float as roi_calculation,

        raw_json:start_date::timestamp_ntz as start_date,
        raw_json:end_date::timestamp_ntz as end_date

    from src_campaign
)

select * from parsed