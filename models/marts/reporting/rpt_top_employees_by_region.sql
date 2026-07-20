{{ config(materialized='view') }}

with employee_sales as (
    select
        e.employee_id,
        e.full_name,
        e.role,
        f.region,
        count(distinct f.order_id) as total_orders,
        sum(f.total_sales_amount) as total_sales_amount,
        sum(f.profit_amount) as total_profit_amount
    from {{ ref('dim_employee') }} e
    inner join {{ ref('fact_sales') }} f
        on e.employee_key = f.employee_key
    group by e.employee_id, e.full_name, e.role, f.region
),

ranked as (
    select
        *,
        row_number() over (
            partition by region
            order by total_sales_amount desc
        ) as rank_in_region
    from employee_sales
)

select
    region,
    rank_in_region,
    employee_id,
    full_name,
    role,
    total_orders,
    total_sales_amount,
    total_profit_amount

from ranked
where rank_in_region <= 5
order by region, rank_in_region