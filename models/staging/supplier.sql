{{
  config(
    materialized='incremental',
    unique_key='supplier_id',
    incremental_strategy='merge'
  )
}}

{{ flatten_bronze_source('supplier_ext', 'supplier_id') }}