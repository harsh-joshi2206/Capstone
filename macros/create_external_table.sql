{% macro create_external_table(source_name, table_name, file_path) %}

{% set ddl %}
    create or replace external table {{ source(source_name, table_name) }} (
        file_last_modified timestamp_ntz as to_timestamp_ntz(metadata$file_last_modified),
        source_file_name string as metadata$filename,
        raw_json variant as (value)
    )
    location = @snwflk_capstone_stage/{{ file_path }}/
    file_format = (type = json)
    auto_refresh = false
{% endset %}

{% do run_query(ddl) %}
{{ log("Created external table for " ~ table_name, info=True) }}

{% endmacro %}