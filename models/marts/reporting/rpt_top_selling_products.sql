{{ config(materialized='view') }}

select
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    p.brand,
    sum(f.quantity_sold) as total_units_sold,
    sum(f.total_sales_amount) as total_sales_amount,
    sum(f.profit_amount) as total_profit_amount,
    count(distinct f.order_id) as total_orders

from {{ ref('fact_sales') }} f
inner join {{ ref('dim_product') }} p
    on f.product_key = p.product_key

group by p.product_id, p.product_name, p.category, p.subcategory, p.brand
order by total_units_sold desc