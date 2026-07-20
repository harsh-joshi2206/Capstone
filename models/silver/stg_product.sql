with src_product as (
    select * from {{ ref('snp_product') }} where dbt_valid_to is null
),

parsed as (
    select
        product_id,
        initcap(trim(raw_json:name::string)) as product_name,
        initcap(trim(raw_json:short_description::string)) as short_description,
        raw_json:technical_specs::string as technical_specs,
        initcap(trim(raw_json:category::string)) as category,
        initcap(trim(raw_json:subcategory::string)) as subcategory,
        initcap(trim(raw_json:product_line::string)) as product_line,
        initcap(trim(raw_json:brand::string)) as brand,
        initcap(trim(raw_json:color::string)) as color,
        raw_json:size::string as size,
        raw_json:dimensions::string as dimensions,
        raw_json:weight::string as weight,
        raw_json:warranty_period::string as warranty_period,
        raw_json:unit_price::float as unit_price,
        raw_json:cost_price::float as cost_price,
        raw_json:stock_quantity::number as stock_quantity,
        raw_json:reorder_level::number as reorder_level,
        raw_json:supplier_id::string as supplier_id,
        raw_json:is_featured::boolean as is_featured,
        coalesce(
            try_to_date(raw_json:launch_date::string, 'YYYY-MM-DD'),
            try_to_date(raw_json:launch_date::string, 'DD-MM-YYYY'),
            try_to_date(raw_json:launch_date::string, 'MM-DD-YYYY')
        ) as launch_date,
        last_modified_date
    from src_product
),

cleaned as (
    select
        product_id,
        product_name,
        short_description,
        technical_specs,

        product_name || ' - ' || short_description ||
            case when technical_specs is not null then ' (' || technical_specs || ')' else '' end
            as full_description,

        category,
        subcategory,
        product_line,
        brand,
        color,
        size,
        dimensions,
        weight,
        warranty_period,

        unit_price,
        cost_price,

        case
            when unit_price > 0
            then round(((unit_price - cost_price) / unit_price) * 100, 2)
            else null
        end as profit_margin_percentage,

        stock_quantity,
        reorder_level,
        case
            when stock_quantity < reorder_level then true
            else false
        end as is_low_stock,

        supplier_id,
        is_featured,
        launch_date,
        last_modified_date

    from parsed
),

deduped as (
    select
        *,
        row_number() over (
            partition by product_id
            order by last_modified_date desc
        ) as _rn
    from cleaned
)

select * exclude (_rn)
from deduped
where _rn = 1