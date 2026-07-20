{{ config(materialized='table') }}

with src_employee as (
    select * from {{ ref('snp_employee') }}
),

parsed as (
    select
        employee_id,
        dbt_valid_from,
        dbt_valid_to,
        initcap(trim(raw_json:first_name::string)) as first_name,
        initcap(trim(raw_json:last_name::string)) as last_name,
        lower(trim(raw_json:email::string)) as email_raw,
        raw_json:phone::string as phone_raw,
        initcap(trim(raw_json:role::string)) as role_raw,
        raw_json:work_location::string as work_location,
        raw_json:performance_rating::float as performance_rating,
        raw_json:sales_target::float as sales_target,
        raw_json:current_sales::float as current_sales,
        coalesce(
            try_to_date(raw_json:hire_date::string, 'YYYY-MM-DD'),
            try_to_date(raw_json:hire_date::string, 'DD-MM-YYYY'),
            try_to_date(raw_json:hire_date::string, 'MM-DD-YYYY')
        ) as hire_date
    from src_employee
),

cleaned as (
    select
        employee_id,
        first_name,
        last_name,
        first_name || ' ' || last_name as full_name,

        case role_raw
            when 'Sales Associate' then 'Associate'
            when 'Senior Manager' then 'Senior Manager'
            when 'Store Manager' then 'Manager'
            else role_raw
        end as role,

        work_location,

        case
            when email_raw regexp '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$'
            then email_raw
            else null
        end as email,

        case
            when phone_raw rlike '^[+0-9()\\- ]+$'
                 and length(regexp_replace(phone_raw, '[^0-9]', '')) between 10 and 15
            then phone_raw
            else null
        end as phone,

        hire_date,
        datediff(year, hire_date, current_date())
            - iff(to_char(hire_date, 'MMDD') > to_char(current_date(), 'MMDD'), 1, 0) as tenure_years,

        performance_rating,
        sales_target,
        current_sales,
        case
            when sales_target > 0
            then round((current_sales / sales_target) * 100, 2)
            else null
        end as target_achievement_percentage,

        dbt_valid_from,
        dbt_valid_to

    from parsed
)

select
    {{ dbt_utils.generate_surrogate_key(['employee_id', 'dbt_valid_from']) }} as employee_key,
    employee_id,
    full_name,
    role,
    work_location,
    email,
    phone,
    tenure_years,
    performance_rating,
    target_achievement_percentage,
    dbt_valid_from as valid_from,
    dbt_valid_to as valid_to,
    case when dbt_valid_to is null then true else false end as is_current
from cleaned