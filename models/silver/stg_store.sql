with src_store as (
    select * from {{ ref('snp_store') }} where dbt_valid_to is null
),

parsed as (
    select
        store_id,
        initcap(trim(raw_json:store_name::string)) as store_name,
        initcap(trim(raw_json:store_type::string)) as store_type,
        upper(trim(raw_json:region::string)) as region,
        raw_json:manager_id::string as manager_id,
        lower(trim(raw_json:email::string)) as email_raw,
        raw_json:phone_number::string as phone_raw,
        raw_json:size_sq_ft::number as size_sq_ft,
        raw_json:employee_count::number as employee_count,
        raw_json:sales_target::float as sales_target,
        raw_json:current_sales::float as current_sales,
        raw_json:monthly_rent::float as monthly_rent,
        raw_json:is_active::boolean as is_active,
        raw_json:address:street::string as address_street,
        raw_json:address:city::string as address_city,
        raw_json:address:state::string as address_state,
        raw_json:address:zip_code::string as address_zip,
        raw_json:address:country::string as address_country,
        coalesce(
            try_to_date(raw_json:opening_date::string, 'YYYY-MM-DD'),
            try_to_date(raw_json:opening_date::string, 'DD-MM-YYYY'),
            try_to_date(raw_json:opening_date::string, 'MM-DD-YYYY')
        ) as opening_date,
        last_modified_date
    from src_store
),

cleaned as (
    select
        store_id,
        store_name,
        store_type,
        region,
        manager_id,

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

        size_sq_ft,
        case
            when size_sq_ft < 5000 then 'Small'
            when size_sq_ft between 5000 and 10000 then 'Medium'
            when size_sq_ft > 10000 then 'Large'
            else null
        end as size_category,

        employee_count,
        sales_target,
        current_sales,
        monthly_rent,
        is_active,

        initcap(trim(address_street)) as address_street,
        initcap(trim(address_city)) as address_city,
        upper(trim(address_state)) as address_state,
        trim(address_zip) as address_zip,
        upper(trim(address_country)) as address_country,
        case
            when trim(address_zip) rlike '^[0-9]{5}(-[0-9]{4})?$' then false
            else true
        end as is_postal_code_invalid,

        opening_date,
        datediff(year, opening_date, current_date())
            - iff(
                to_char(opening_date, 'MMDD') > to_char(current_date(), 'MMDD'),
                1, 0
              ) as store_age_years,

        case
            when sales_target > 0
            then round((current_sales / sales_target) * 100, 2)
            else null
        end as sales_target_achievement_percentage,

        case
            when size_sq_ft > 0
            then round(current_sales / size_sq_ft, 2)
            else null
        end as revenue_per_sq_ft,

        case
            when employee_count > 0
            then round(current_sales / employee_count, 2)
            else null
        end as employee_efficiency,

        last_modified_date

    from parsed
),

flagged as (
    select
        *,
        case
            when sales_target_achievement_percentage < 90 then true
            else false
        end as has_performance_issue
    from cleaned
),

deduped as (
    select
        *,
        row_number() over (
            partition by store_id
            order by last_modified_date desc
        ) as _rn
    from flagged
)

select * exclude (_rn)
from deduped
where _rn = 1