{{
  config(
    materialized='incremental',
    unique_key=['order_id', 'product_id', 'line_item_index'],
    incremental_strategy='merge'
  )
}}

with order_base as (
    select
        f2.value:order_id::string as order_id,
        f2.value:order_items as items_array,
        file_name as _source_file,
        file_last_modified as _file_last_modified,
        current_timestamp() as _loaded_at,
        '{{ invocation_id }}' as _batch_id
    from {{ source('capstone_raw', 'orders_ext') }} t,
    lateral flatten(input => t.raw_json) f1,
    lateral flatten(input => f1.value) f2
),

exploded as (
    select
        order_base.order_id,
        item.index as line_item_index,
        item.value:product_id::string as product_id,
        item.value as raw_json,
        order_base._source_file,
        order_base._file_last_modified,
        order_base._loaded_at,
        order_base._batch_id
    from order_base,
    lateral flatten(input => order_base.items_array) item
),

ranked as (
    select
        *,
        row_number() over (
            partition by order_id, product_id, line_item_index
            order by _file_last_modified desc
        ) as _rn
    from exploded
)

select
    order_id,
    line_item_index,
    product_id,
    raw_json,
    _source_file,
    _file_last_modified,
    _loaded_at,
    _batch_id
from ranked
where _rn = 1

{% if is_incremental() %}
and _file_last_modified > (select coalesce(max(_file_last_modified), '1900-01-01'::timestamp_ntz) from {{ this }})
{% endif %}