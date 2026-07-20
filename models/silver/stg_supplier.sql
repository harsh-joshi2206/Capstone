with src_supplier as (
    select * from {{ ref('supplier') }}
),

parsed as (
    select
        supplier_id,
        initcap(trim(raw_json:supplier_name::string)) as supplier_name,
        initcap(trim(raw_json:supplier_type::string)) as supplier_type,
        raw_json:categories_supplied as categories_supplied,
        raw_json:contact_information:contact_person::string as contact_person,
        lower(trim(raw_json:contact_information:email::string)) as email_raw,
        raw_json:contact_information:phone::string as phone_raw,
        raw_json:contact_information:address::string as address,
        raw_json:contract_details:contract_id::string as contract_id,
        raw_json:contract_details:exclusivity::boolean as contract_exclusivity,
        raw_json:contract_details:renewal_option::boolean as contract_renewal_option,
        coalesce(
            try_to_date(raw_json:contract_details:start_date::string, 'YYYY-MM-DD'),
            try_to_date(raw_json:contract_details:start_date::string, 'DD-MM-YYYY')
        ) as contract_start_date,
        coalesce(
            try_to_date(raw_json:contract_details:end_date::string, 'YYYY-MM-DD'),
            try_to_date(raw_json:contract_details:end_date::string, 'DD-MM-YYYY')
        ) as contract_end_date,
        upper(trim(raw_json:credit_rating::string)) as credit_rating,
        raw_json:is_active::boolean as is_active,
        raw_json:lead_time_days::number as lead_time_days,
        raw_json:minimum_order_quantity::number as minimum_order_quantity,
        raw_json:payment_terms::string as payment_terms,
        raw_json:preferred_carrier::string as preferred_carrier,
        raw_json:performance_metrics:average_delay_days::number as avg_delay_days,
        raw_json:performance_metrics:defect_rate::float as defect_rate,
        raw_json:performance_metrics:on_time_delivery_rate::float as on_time_delivery_rate,
        lower(trim(raw_json:performance_metrics:quality_rating::string)) as quality_rating,
        raw_json:performance_metrics:response_time_hours::number as response_time_hours,
        raw_json:performance_metrics:returns_percentage::float as returns_percentage,
        raw_json:tax_id::string as tax_id,
        raw_json:website::string as website,
        raw_json:year_established::number as year_established,
        coalesce(
            try_to_date(raw_json:last_order_date::string, 'YYYY-MM-DD'),
            try_to_date(raw_json:last_order_date::string, 'DD-MM-YYYY')
        ) as last_order_date
    from src_supplier
),

cleaned as (
    select
        supplier_id,
        supplier_name,
        supplier_type,
        categories_supplied,
        contact_person,

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

        address,
        contract_id,
        contract_exclusivity,
        contract_renewal_option,
        contract_start_date,
        contract_end_date,
        credit_rating,
        is_active,
        lead_time_days,
        minimum_order_quantity,
        payment_terms,
        preferred_carrier,
        avg_delay_days,
        defect_rate,
        on_time_delivery_rate,
        quality_rating,
        response_time_hours,
        returns_percentage,
        tax_id,
        website,
        year_established,
        last_order_date

    from parsed
)

select * from cleaned