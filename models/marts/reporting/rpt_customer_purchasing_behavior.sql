{{ config(materialized='view') }}

select
    c.customer_id,
    c.full_name,
    c.segment,
    count(distinct f.order_id) as total_orders,
    sum(f.total_sales_amount) as total_spend,
    round(sum(f.total_sales_amount) / nullif(count(distinct f.order_id), 0), 2) as avg_order_value,
    sum(f.quantity_sold) as total_units_purchased,
    min(d.full_date) as first_purchase_date,
    max(d.full_date) as last_purchase_date

from {{ ref('fact_sales') }} f
inner join {{ ref('dim_customer') }} c
    on f.customer_key = c.customer_key
inner join {{ ref('dim_date') }} d
    on f.date_key = d.date_key

group by c.customer_id, c.full_name, c.segment
order by total_spend desc