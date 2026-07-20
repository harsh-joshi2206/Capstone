{{
  config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge'
  )
}}

with flattened as (
    select
        f2.value:order_id::string as order_id,
        f2.value as raw_json,
        file_name as _source_file,
        file_last_modified as _file_last_modified,
        current_timestamp() as _loaded_at,
        '{{ invocation_id }}' as _batch_id
    from {{ source('capstone_raw', 'orders_ext') }} t,
    lateral flatten(input => t.raw_json) f1,
    lateral flatten(input => f1.value) f2

    {% if is_incremental() %}
    where file_last_modified > (select coalesce(max(_file_last_modified), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
),

ranked as (
    select
        *,
        row_number() over (
            partition by order_id
            order by _file_last_modified desc
        ) as _rn
    from flattened
)

select
    order_id,
    raw_json,
    _source_file,
    _file_last_modified,
    _loaded_at,
    _batch_id
from ranked
where _rn = 1