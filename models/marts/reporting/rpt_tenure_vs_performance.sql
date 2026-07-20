{{ config(materialized='view') }}

select
    e.employee_id,
    e.full_name,
    e.role,
    e.tenure_years,

    case
        when e.tenure_years < 2 then '0-2 years'
        when e.tenure_years between 2 and 5 then '2-5 years'
        when e.tenure_years between 6 and 10 then '6-10 years'
        else '10+ years'
    end as tenure_bucket,

    e.performance_rating,
    e.target_achievement_percentage,
    count(distinct f.order_id) as total_orders,
    sum(f.total_sales_amount) as total_sales_amount

from {{ ref('dim_employee') }} e
left join {{ ref('fact_sales') }} f
    on e.employee_key = f.employee_key

group by e.employee_id, e.full_name, e.role, e.tenure_years, e.performance_rating, e.target_achievement_percentage
order by e.tenure_years desc