{{ config(materialized='view') }}

with customer_orders as (
    select
        c.customer_id,
        c.full_name,
        c.segment,
        count(distinct f.order_id) as total_orders
    from {{ ref('dim_customer') }} c
    left join {{ ref('fact_sales') }} f
        on c.customer_key = f.customer_key
    group by c.customer_id, c.full_name, c.segment
),

flagged as (
    select
        *,
        case when total_orders > 1 then true else false end as is_repeat_customer
    from customer_orders
)

select
    segment,
    count(*) as total_customers,
    sum(case when is_repeat_customer then 1 else 0 end) as repeat_customers,
    round(
        sum(case when is_repeat_customer then 1 else 0 end) / nullif(count(*), 0) * 100,
        2
    ) as repeat_purchase_rate_percentage

from flagged
group by segment

union all

select
    'ALL' as segment,
    count(*) as total_customers,
    sum(case when is_repeat_customer then 1 else 0 end) as repeat_customers,
    round(
        sum(case when is_repeat_customer then 1 else 0 end) / nullif(count(*), 0) * 100,
        2
    ) as repeat_purchase_rate_percentage

from flagged