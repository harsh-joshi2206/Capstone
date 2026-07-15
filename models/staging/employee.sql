{{
  config(
    materialized='incremental',
    unique_key='employee_id',
    incremental_strategy='merge'
  )
}}

{{ flatten_bronze_source('employee_ext', 'employee_id') }}