{{ config(materialized='view') }}

select
    f.region,
    d.year,
    d.month,
    sum(f.total_sales_amount) as total_sales_amount,
    sum(f.quantity_sold) as total_units_sold,
    count(distinct f.order_id) as total_orders,
    sum(f.profit_amount) as total_profit_amount

from {{ ref('fact_sales') }} f
inner join {{ ref('dim_date') }} d
    on f.date_key = d.date_key

group by f.region, d.year, d.month
order by f.region, d.year, d.month