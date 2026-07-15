{{
  config(
    materialized='incremental',
    unique_key='store_id',
    incremental_strategy='merge'
  )
}}

{{ flatten_bronze_source('store_ext', 'store_id') }}