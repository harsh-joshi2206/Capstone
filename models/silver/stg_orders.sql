with src_orders as (
    select * from {{ ref('orders') }}
),

order_items_agg as (
    select
        order_id,
        count(product_id) as total_items,
        sum(quantity) as total_quantity,
        sum(line_revenue) as total_line_revenue,
        sum(line_cost) as total_line_cost
    from {{ ref('stg_order_items') }}
    group by order_id
),

parsed as (
    select
        order_id,
        raw_json:customer_id::string as customer_id,
        raw_json:employee_id::string as employee_id,
        raw_json:store_id::string as store_id,
        raw_json:campaign_id::string as campaign_id,
        raw_json:order_status::string as order_status,
        raw_json:order_source::string as order_source,
        raw_json:payment_method::string as payment_method,
        raw_json:shipping_method::string as shipping_method,
        (raw_json:discount_amount::float) / 100 as order_discount_rate,
        raw_json:shipping_cost::float as shipping_cost,
        raw_json:tax_amount::float as tax_amount,
        raw_json:total_amount::float as total_amount,
        raw_json:order_date::timestamp_ntz as order_date,
        raw_json:shipping_date::timestamp_ntz as shipping_date,
        raw_json:delivery_date::timestamp_ntz as delivery_date,
        raw_json:estimated_delivery_date::timestamp_ntz as estimated_delivery_date,
        raw_json:billing_address::variant as billing_address,
        raw_json:shipping_address::variant as shipping_address
    from src_orders
),

joined as (
    select
        p.*,
        oi.total_items,
        oi.total_quantity,
        oi.total_line_revenue,
        oi.total_line_cost
    from parsed p
    left join order_items_agg oi on p.order_id = oi.order_id
),

calculated as (
    select
        *,

        total_line_revenue * (1 - order_discount_rate) as line_revenue,

        (total_line_revenue * (1 - order_discount_rate))
            - total_line_cost - shipping_cost - tax_amount as profit_amount,

        case
            when total_line_revenue > 0
            then round(
                ((total_line_revenue * (1 - order_discount_rate)) - total_line_cost - shipping_cost - tax_amount)
                / total_line_revenue * 100, 2
            )
            else null
        end as profit_margin_percentage,

        extract(hour from order_date) as order_hour,

        case
            when extract(hour from order_date) >= 5 and extract(hour from order_date) < 12 then 'Morning'
            when extract(hour from order_date) >= 12 and extract(hour from order_date) < 17 then 'Afternoon'
            when extract(hour from order_date) >= 17 and extract(hour from order_date) < 22 then 'Evening'
            else 'Night'
        end as order_time_of_day,

        date_trunc('week', order_date) as order_week,
        date_trunc('month', order_date) as order_month,
        date_trunc('quarter', order_date) as order_quarter,
        date_trunc('year', order_date) as order_year,

        datediff(day, order_date, shipping_date) as processing_days,
        datediff(day, shipping_date, delivery_date) as shipping_days,

        case
            when delivery_date is not null and delivery_date <= estimated_delivery_date then 'On Time'
            when delivery_date is not null and delivery_date > estimated_delivery_date then 'Delayed'
            when delivery_date is null and current_date() > estimated_delivery_date then 'Potentially Delayed'
            else 'In Transit'
        end as delivery_status

    from joined
)

select * from calculated