{{ config(materialized='view') }}

select
    c.segment,
    count(distinct c.customer_id) as total_customers,
    count(distinct f.order_id) as total_orders,
    sum(f.total_sales_amount) as total_revenue,
    round(sum(f.total_sales_amount) / nullif(count(distinct c.customer_id), 0), 2) as avg_revenue_per_customer,
    round(sum(f.total_sales_amount) / nullif(count(distinct f.order_id), 0), 2) as avg_order_value,
    round(count(distinct f.order_id) / nullif(count(distinct c.customer_id), 0), 2) as avg_orders_per_customer,
    sum(f.profit_amount) as total_profit

from {{ ref('dim_customer') }} c
left join {{ ref('fact_sales') }} f
    on c.customer_key = f.customer_key

group by c.segment
order by total_revenue desc