-- Fails if product's data is meaningfully more stale (>5 days) than the other sources.
-- This directly targets the PDF's intentional 12-day product staleness scenario,
-- rather than relying on absolute freshness-vs-now (which is meaningless on this
-- static historical dataset).

with latest_per_source as (
    select 'product' as source_name, max(file_last_modified) as latest_file from {{ source('capstone_raw', 'product_ext') }}
    union all
    select 'customer', max(file_last_modified) from {{ source('capstone_raw', 'customer_ext') }}
    union all
    select 'orders', max(file_last_modified) from {{ source('capstone_raw', 'orders_ext') }}
    union all
    select 'employee', max(file_last_modified) from {{ source('capstone_raw', 'employee_ext') }}
    union all
    select 'store', max(file_last_modified) from {{ source('capstone_raw', 'store_ext') }}
),

comparison as (
    select
        (select latest_file from latest_per_source where source_name = 'product') as product_latest,
        max(latest_file) as other_sources_latest
    from latest_per_source
    where source_name != 'product'
)

select *
from comparison
where datediff(day, product_latest, other_sources_latest) > 5