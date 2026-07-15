-- Fails if product's actual data date (parsed from filename) is meaningfully
-- more stale than other sources' data dates. Blob upload metadata
-- (_file_last_modified) can't detect this since all files were bulk-uploaded
-- in the same few-minute window -- the real signal is the date embedded in
-- each file's name (e.g. products_2024-09-15.json vs customers_2024-09-27.json).

with latest_per_source as (
    select 'product' as source_name,
           max(to_date(regexp_substr(_source_file, '\\d{4}-\\d{2}-\\d{2}'))) as latest_data_date
    from {{ ref('product') }}
    union all
    select 'customer', max(to_date(regexp_substr(_source_file, '\\d{4}-\\d{2}-\\d{2}')))
    from {{ ref('customer') }}
    union all
    select 'orders', max(to_date(regexp_substr(_source_file, '\\d{4}-\\d{2}-\\d{2}')))
    from {{ ref('orders') }}
    union all
    select 'employee', max(to_date(regexp_substr(_source_file, '\\d{4}-\\d{2}-\\d{2}')))
    from {{ ref('employee') }}
    union all
    select 'store', max(to_date(regexp_substr(_source_file, '\\d{4}-\\d{2}-\\d{2}')))
    from {{ ref('store') }}
),

comparison as (
    select
        (select latest_data_date from latest_per_source where source_name = 'product') as product_latest,
        max(latest_data_date) as other_sources_latest
    from latest_per_source
    where source_name != 'product'
)

select *, datediff(day, product_latest, other_sources_latest) as day_gap
from comparison
where datediff(day, product_latest, other_sources_latest) > 5