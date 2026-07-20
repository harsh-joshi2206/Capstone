{{ config(materialized='view') }}

select
    p.category,
    p.subcategory,
    count(distinct f.order_id) as total_orders,
    sum(f.quantity_sold) as total_units_sold,
    sum(f.total_sales_amount) as total_sales_amount,
    sum(f.profit_amount) as total_profit_amount,
    round(sum(f.profit_amount) / nullif(sum(f.total_sales_amount), 0) * 100, 2) as profit_margin_percentage

from {{ ref('fact_sales') }} f
inner join {{ ref('dim_product') }} p
    on f.product_key = p.product_key

group by p.category, p.subcategory
order by total_sales_amount desc