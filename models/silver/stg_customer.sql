with src_customer as (
    select * from {{ ref('snp_customer') }} where dbt_valid_to is null
),

parsed as (
    select
        customer_id,
        initcap(trim(raw_json:first_name::string)) as first_name,
        initcap(trim(raw_json:last_name::string)) as last_name,
        lower(trim(raw_json:email::string)) as email_raw,
        raw_json:phone::string as phone_raw,
        coalesce(
            try_to_date(raw_json:birth_date::string, 'YYYY-MM-DD'),
            try_to_date(raw_json:birth_date::string, 'DD-MM-YYYY'),
            try_to_date(raw_json:birth_date::string, 'MM-DD-YYYY')
        ) as birth_date,
        raw_json:address:street::string as address_street,
        raw_json:address:city::string as address_city,
        raw_json:address:state::string as address_state,
        raw_json:address:zip_code::string as address_zip,
        raw_json:address:country::string as address_country,
        coalesce(
            try_to_date(raw_json:registration_date::string, 'YYYY-MM-DD'),
            try_to_date(raw_json:registration_date::string, 'DD-MM-YYYY'),
            try_to_date(raw_json:registration_date::string, 'MM-DD-YYYY')
        ) as registration_date,
        coalesce(
            try_to_date(raw_json:last_purchase_date::string, 'YYYY-MM-DD'),
            try_to_date(raw_json:last_purchase_date::string, 'DD-MM-YYYY'),
            try_to_date(raw_json:last_purchase_date::string, 'MM-DD-YYYY')
        ) as last_purchase_date,
        raw_json:income_bracket::string as income_bracket,
        raw_json:loyalty_tier::string as loyalty_tier,
        raw_json:marketing_opt_in::boolean as marketing_opt_in,
        raw_json:occupation::string as occupation,
        raw_json:preferred_communication::string as preferred_communication,
        raw_json:preferred_payment_method::string as preferred_payment_method,
        raw_json:total_purchases::number as total_purchases,
        raw_json:total_spend::float as total_spend,
        last_modified_date
    from src_customer
),

cleaned as (
    select
        customer_id,
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

        birth_date,
        datediff(year, birth_date, current_date())
            - iff(
                to_char(birth_date, 'MMDD') > to_char(current_date(), 'MMDD'),
                1, 0
              ) as age,

        case
            when datediff(year, birth_date, current_date())
                 - iff(to_char(birth_date, 'MMDD') > to_char(current_date(), 'MMDD'), 1, 0)
                 between 18 and 35 then 'Young'
            when datediff(year, birth_date, current_date())
                 - iff(to_char(birth_date, 'MMDD') > to_char(current_date(), 'MMDD'), 1, 0)
                 between 36 and 55 then 'Middle-aged'
            when datediff(year, birth_date, current_date())
                 - iff(to_char(birth_date, 'MMDD') > to_char(current_date(), 'MMDD'), 1, 0)
                 >= 56 then 'Senior'
            else null
        end as age_segment,

        initcap(trim(address_street)) as address_street,
        initcap(trim(address_city)) as address_city,
        upper(trim(address_state)) as address_state,
        trim(address_zip) as address_zip,
        upper(trim(address_country)) as address_country,

        registration_date,
        last_purchase_date,
        upper(trim(income_bracket)) as income_bracket,
        lower(trim(loyalty_tier)) as loyalty_tier,
        marketing_opt_in,
        occupation,
        preferred_communication,
        preferred_payment_method,
        total_purchases,
        total_spend,
        last_modified_date

    from parsed
),

deduped as (
    select
        *,
        row_number() over (
            partition by customer_id
            order by last_modified_date desc
        ) as _rn
    from cleaned
)

select * exclude (_rn)
from deduped
where _rn = 1