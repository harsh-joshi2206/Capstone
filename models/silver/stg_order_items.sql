with src_order_items as (
    select * from {{ ref('order_items') }}
),

parsed as (
    select
        order_id,
        line_item_index,
        product_id,
        raw_json:quantity::number as quantity,
        raw_json:unit_price::float as unit_price,
        raw_json:cost_price::float as cost_price,
        (raw_json:discount_amount::float) / 100 as discount_rate
    from src_order_items
),

calculated as (
    select
        order_id,
        line_item_index,
        product_id,
        quantity,
        unit_price,
        cost_price,
        discount_rate,

        quantity * unit_price * (1 - discount_rate) as line_revenue,
        quantity * cost_price as line_cost

    from parsed
)

select * from calculated