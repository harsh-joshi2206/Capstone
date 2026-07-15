{{
  config(
    materialized='incremental',
    unique_key='product_id',
    incremental_strategy='merge'
  )
}}

{{ flatten_bronze_source('product_ext', 'product_id') }}