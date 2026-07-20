{{ config(materialized='view') }}

select
    c.customer_id,
    c.full_name,
    c.segment,
    c.registration_date,
    count(distinct f.order_id) as total_orders,
    sum(f.total_sales_amount) as lifetime_value,
    sum(f.profit_amount) as lifetime_profit_contribution,
    datediff(day, c.registration_date, current_date()) as customer_tenure_days,
    round(
        sum(f.total_sales_amount) / nullif(datediff(day, c.registration_date, current_date()), 0) * 365,
        2
    ) as annualized_value

from {{ ref('dim_customer') }} c
left join {{ ref('fact_sales') }} f
    on c.customer_key = f.customer_key

group by c.customer_id, c.full_name, c.segment, c.registration_date
order by lifetime_value desc