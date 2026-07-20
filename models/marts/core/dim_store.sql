{{ config(materialized='table') }}

with src_store as (
    select * from {{ ref('snp_store') }}
),

parsed as (
    select
        store_id,
        dbt_valid_from,
        dbt_valid_to,
        initcap(trim(raw_json:store_name::string)) as store_name,
        initcap(trim(raw_json:store_type::string)) as store_type,
        upper(trim(raw_json:region::string)) as region,
        raw_json:size_sq_ft::number as size_sq_ft,
        raw_json:address:street::string as address_street,
        raw_json:address:city::string as address_city,
        raw_json:address:state::string as address_state,
        raw_json:address:zip_code::string as address_zip,
        raw_json:address:country::string as address_country,
        coalesce(
            try_to_date(raw_json:opening_date::string, 'YYYY-MM-DD'),
            try_to_date(raw_json:opening_date::string, 'DD-MM-YYYY'),
            try_to_date(raw_json:opening_date::string, 'MM-DD-YYYY')
        ) as opening_date
    from src_store
),

cleaned as (
    select
        store_id,
        store_name,
        store_type,
        region,

        initcap(trim(address_street)) as address_street,
        initcap(trim(address_city)) as address_city,
        upper(trim(address_state)) as address_state,
        trim(address_zip) as address_zip,
        upper(trim(address_country)) as address_country,

        size_sq_ft,
        case
            when size_sq_ft < 5000 then 'Small'
            when size_sq_ft between 5000 and 10000 then 'Medium'
            when size_sq_ft > 10000 then 'Large'
            else null
        end as size_category,

        opening_date,
        dbt_valid_from,
        dbt_valid_to

    from parsed
)

select
    {{ dbt_utils.generate_surrogate_key(['store_id', 'dbt_valid_from']) }} as store_key,
    store_id,
    store_name,
    store_type,
    region,
    address_street,
    address_city,
    address_state,
    address_zip,
    address_country,
    size_sq_ft,
    size_category,
    opening_date,
    dbt_valid_from as valid_from,
    dbt_valid_to as valid_to,
    case when dbt_valid_to is null then true else false end as is_current
from cleaned