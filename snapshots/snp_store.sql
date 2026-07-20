{% snapshot snp_store %}

{{
    config(
        target_schema='silver',
        unique_key='store_id',
        strategy='timestamp',
        updated_at='last_modified_date',
        invalidate_hard_deletes=True
    )
}}

select
    store_id,
    raw_json,
    raw_json:last_modified_date::timestamp_ntz as last_modified_date
from {{ ref('store') }}

{% endsnapshot %}