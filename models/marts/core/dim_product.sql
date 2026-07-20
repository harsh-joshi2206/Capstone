{{ config(materialized='table') }}

with src_product as (
    select * from {{ ref('snp_product') }}
),

parsed as (
    select
        product_id,
        dbt_valid_from,
        dbt_valid_to,
        initcap(trim(raw_json:name::string)) as product_name,
        initcap(trim(raw_json:category::string)) as category,
        initcap(trim(raw_json:subcategory::string)) as subcategory,
        initcap(trim(raw_json:product_line::string)) as product_line,
        initcap(trim(raw_json:brand::string)) as brand,
        initcap(trim(raw_json:color::string)) as color,
        raw_json:size::string as size,
        raw_json:unit_price::float as unit_price,
        raw_json:cost_price::float as cost_price,
        raw_json:supplier_id::string as supplier_id
    from src_product
),

supplier_info as (
    select
        supplier_id,
        supplier_name,
        supplier_type,
        contact_person,
        email as supplier_email,
        phone as supplier_phone
    from {{ ref('stg_supplier') }}
),

joined as (
    select
        p.*,
        s.supplier_name,
        s.supplier_type,
        s.contact_person as supplier_contact_person,
        s.supplier_email,
        s.supplier_phone
    from parsed p
    left join supplier_info s on p.supplier_id = s.supplier_id
)

select
    {{ dbt_utils.generate_surrogate_key(['product_id', 'dbt_valid_from']) }} as product_key,
    product_id,
    product_name,
    category,
    subcategory,
    product_line,
    brand,
    color,
    size,
    unit_price,
    cost_price,
    supplier_id,
    supplier_name,
    supplier_type,
    supplier_contact_person,
    supplier_email,
    supplier_phone,
    dbt_valid_from as valid_from,
    dbt_valid_to as valid_to,
    case when dbt_valid_to is null then true else false end as is_current
from joined