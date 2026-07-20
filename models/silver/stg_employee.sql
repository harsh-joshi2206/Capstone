with src_employee as (
    select * from {{ ref('snp_employee') }} where dbt_valid_to is null
),

parsed as (
    select
        employee_id,
        initcap(trim(raw_json:first_name::string)) as first_name,
        initcap(trim(raw_json:last_name::string)) as last_name,
        lower(trim(raw_json:email::string)) as email_raw,
        raw_json:phone::string as phone_raw,
        initcap(trim(raw_json:role::string)) as role_raw,
        initcap(trim(raw_json:department::string)) as department,
        raw_json:work_location::string as work_location,
        raw_json:manager_id::string as manager_id,
        initcap(trim(raw_json:education::string)) as education,
        initcap(trim(raw_json:employment_status::string)) as employment_status,
        raw_json:performance_rating::float as performance_rating,
        raw_json:salary::float as salary,
        raw_json:sales_target::float as sales_target,
        raw_json:current_sales::float as current_sales,
        raw_json:address:street::string as address_street,
        raw_json:address:city::string as address_city,
        raw_json:address:state::string as address_state,
        raw_json:address:zip_code::string as address_zip,
        coalesce(
            try_to_date(raw_json:hire_date::string, 'YYYY-MM-DD'),
            try_to_date(raw_json:hire_date::string, 'DD-MM-YYYY'),
            try_to_date(raw_json:hire_date::string, 'MM-DD-YYYY')
        ) as hire_date,
        coalesce(
            try_to_date(raw_json:date_of_birth::string, 'YYYY-MM-DD'),
            try_to_date(raw_json:date_of_birth::string, 'DD-MM-YYYY'),
            try_to_date(raw_json:date_of_birth::string, 'MM-DD-YYYY')
        ) as date_of_birth,
        last_modified_date
    from src_employee
),

cleaned as (
    select
        employee_id,
        first_name,
        last_name,
        first_name || ' ' || last_name as full_name,

        case
            when email_raw regexp '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$'
            then email_raw
            else null
        end as email,
        case
            when email_raw regexp '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$'
            then false
            else true
        end as is_email_invalid,

        case
            when phone_raw rlike '^[+0-9()\\- ]+$'
                 and length(regexp_replace(phone_raw, '[^0-9]', '')) between 10 and 15
            then phone_raw
            else null
        end as phone,
        case
            when phone_raw rlike '^[+0-9()\\- ]+$'
                 and length(regexp_replace(phone_raw, '[^0-9]', '')) between 10 and 15
            then false
            else true
        end as is_phone_invalid,

        case role_raw
            when 'Sales Associate' then 'Associate'
            when 'Senior Manager' then 'Senior Manager'
            when 'Store Manager' then 'Manager'
            else role_raw
        end as role,

        department,
        work_location,
        manager_id,
        education,
        employment_status,
        performance_rating,
        salary,
        sales_target,
        current_sales,

        case
            when sales_target > 0
            then round((current_sales / sales_target) * 100, 2)
            else null
        end as target_achievement_percentage,

        hire_date,
        datediff(year, hire_date, current_date())
            - iff(
                to_char(hire_date, 'MMDD') > to_char(current_date(), 'MMDD'),
                1, 0
              ) as tenure_years,

        date_of_birth,
        initcap(trim(address_street)) as address_street,
        initcap(trim(address_city)) as address_city,
        upper(trim(address_state)) as address_state,
        trim(address_zip) as address_zip,

        last_modified_date

    from parsed
),

deduped as (
    select
        *,
        row_number() over (
            partition by employee_id
            order by last_modified_date desc
        ) as _rn
    from cleaned
),

deduped_final as (
    select * exclude (_rn)
    from deduped
    where _rn = 1
),

employee_orders_agg as (
    select
        employee_id,
        count(order_id) as orders_processed,
        sum(line_revenue) as total_sales_amount
    from {{ ref('stg_orders') }}
    group by employee_id
)

select
    e.*,
    coalesce(o.orders_processed, 0) as orders_processed,
    coalesce(o.total_sales_amount, 0) as total_sales_amount
from deduped_final e
left join employee_orders_agg o on e.employee_id = o.employee_id