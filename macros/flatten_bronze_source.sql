{% macro flatten_bronze_source(source_table, unique_key_col) %}

with flattened as (
    select
        f2.value:{{ unique_key_col }}::string as {{ unique_key_col }},
        f2.value as raw_json,
        file_name as _source_file,
        file_last_modified as _file_last_modified,
        current_timestamp() as _loaded_at
    from {{ source('capstone_raw', source_table) }} t,
    lateral flatten(input => t.raw_json) f1,
    lateral flatten(input => f1.value) f2
)

select * from flattened

{% if is_incremental() %}
where _file_last_modified > (select coalesce(max(_file_last_modified), '1900-01-01'::timestamp_ntz) from {{ this }})
{% endif %}

{% endmacro %}