{% snapshot snp_customer %}

{{
    config(
        target_schema='silver',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='last_modified_date',
        invalidate_hard_deletes=True
    )
}}

select
    customer_id,
    raw_json,
    raw_json:last_modified_date::timestamp_ntz as last_modified_date
from {{ ref('customer') }}

{% endsnapshot %}