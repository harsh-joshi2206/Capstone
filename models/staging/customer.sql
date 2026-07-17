{{
  config(
    materialized='incremental',
    unique_key='customer_id',
    incremental_strategy='merge'
  )
}}

{{ flatten_bronze_source('customer_ext', 'customer_id') }}