{{ config(materialized='table') }}

-- DESIGN NOTE (per spec's required documentation of allocation approach):
-- Order-level amounts (shipping_cost, tax_amount, order_discount_rate) are
-- allocated to line items PROPORTIONALLY based on each line item's share of
-- the order's total line revenue (line_revenue / total_line_revenue). This
-- keeps FACT_Sales at a single consistent grain (one row per OrderID +
-- ProductKey) rather than requiring a separate order-grain fact table.
-- Summing allocated_shipping or allocated_tax across all line items of a
-- given order reconstructs exactly the original order-level amount --
-- no double-counting, no under-counting.

with order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select
        order_id,
        customer_id,
        employee_id,
        store_id,
        campaign_id,
        order_source,
        order_discount_rate,
        shipping_cost,
        tax_amount,
        order_date,
        total_line_revenue
    from {{ ref('stg_orders') }}
),

joined as (
    select
        oi.order_id,
        oi.line_item_index,
        oi.product_id,
        oi.quantity,
        oi.unit_price,
        oi.cost_price,
        oi.discount_rate as item_discount_rate,
        oi.line_revenue as item_line_revenue,
        oi.line_cost as item_line_cost,

        o.customer_id,
        o.employee_id,
        o.store_id,
        o.campaign_id,
        o.order_source,
        o.order_discount_rate,
        o.shipping_cost,
        o.tax_amount,
        o.order_date,
        o.total_line_revenue,

        case
            when o.total_line_revenue > 0
            then oi.line_revenue / o.total_line_revenue
            else 0
        end as allocation_ratio

    from order_items oi
    inner join orders o on oi.order_id = o.order_id
),

allocated as (
    select
        *,
        shipping_cost * allocation_ratio as allocated_shipping_cost,
        tax_amount * allocation_ratio as allocated_tax_amount,
        item_line_revenue * (1 - order_discount_rate) as line_revenue_after_order_discount
    from joined
),

-- NOTE: joins use is_current = true rather than a valid_from/valid_to date-range
-- match. With only a single snapshot run performed so far, every dimension has
-- exactly one row per natural key, so valid_from reflects an arbitrary
-- last_modified_date rather than a true "version start" boundary -- using it in
-- a range join incorrectly excludes orders dated before that arbitrary point.
-- Once the pipeline runs on a real recurring cadence and dimensions accumulate
-- genuine multi-version history, this join should be revisited to match each
-- order to the dimension version that was actually active on order_date.

with_keys as (
    select
        a.*,
        c.customer_key,
        c.segment as customer_segment,
        p.product_key,
        p.cost_price as dim_product_cost_price,
        s.store_key,
        s.region as store_region,
        e.employee_key,
        d.date_key
    from allocated a
    left join {{ ref('dim_customer') }} c
        on a.customer_id = c.customer_id
        and c.is_current = true
    left join {{ ref('dim_product') }} p
        on a.product_id = p.product_id
        and p.is_current = true
    left join {{ ref('dim_store') }} s
        on a.store_id = s.store_id
        and s.is_current = true
    left join {{ ref('dim_employee') }} e
        on a.employee_id = e.employee_id
        and e.is_current = true
    left join {{ ref('dim_date') }} d
        on cast(a.order_date as date) = d.full_date
)

select
    {{ dbt_utils.generate_surrogate_key(['order_id', 'product_id', 'line_item_index']) }} as sales_key,
    order_id,
    customer_key,
    product_key,
    store_key,
    date_key,
    employee_key,

    quantity as quantity_sold,
    unit_price,
    quantity * unit_price as total_sales_amount,
    quantity * dim_product_cost_price as cost_amount,
    (item_line_revenue - line_revenue_after_order_discount)
        + (quantity * unit_price * item_discount_rate) as discount_amount,
    allocated_shipping_cost as shipping_cost,

    line_revenue_after_order_discount
        - item_line_cost
        - allocated_shipping_cost
        - allocated_tax_amount as profit_amount,

    store_region as region,

    case
        when order_source in ('website', 'mobile app') then 'Online'
        when order_source = 'in-store' then 'In-Store'
        else null
    end as sales_channel,

    customer_segment as customer_segment_impact

from with_keys