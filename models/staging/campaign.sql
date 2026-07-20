{{
  config(
    materialized='incremental',
    unique_key='campaign_id',
    incremental_strategy='merge'
  )
}}

{{ flatten_bronze_source('campaign_ext', 'campaign_id') }}