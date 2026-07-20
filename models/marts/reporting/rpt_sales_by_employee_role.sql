{{ config(materialized='view') }}

select
    e.role,
    count(distinct e.employee_id) as total_employees,
    count(distinct f.order_id) as total_orders,
    sum(f.total_sales_amount) as total_sales_amount,
    sum(f.profit_amount) as total_profit_amount,
    round(sum(f.total_sales_amount) / nullif(count(distinct e.employee_id), 0), 2) as avg_sales_per_employee

from {{ ref('dim_employee') }} e
left join {{ ref('fact_sales') }} f
    on e.employee_key = f.employee_key

group by e.role
order by total_sales_amount desc