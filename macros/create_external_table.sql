{% macro create_external_table(table_name, source_folder, database='CT_HARSH_JOSHI_DB', schema='DBT_HARSHJOSHI2206') %}

{% set stage_path = database ~ '.' ~ schema ~ '.SNWFLK_CAPSTONE_STAGE/Capstone_Project_Data/' ~ source_folder ~ '/' %}

{% set create_table_sql %}
    CREATE OR REPLACE EXTERNAL TABLE {{ database }}.{{ schema }}.{{ table_name }} (
        raw_json VARIANT AS (VALUE:c1::VARIANT),
        file_name STRING AS (VALUE:c1:metadata$filename::STRING),
        file_row_number NUMBER AS (VALUE:c1:metadata$file_row_number::NUMBER),
        file_last_modified TIMESTAMP_NTZ AS (VALUE:c1:metadata$file_last_modified::TIMESTAMP_NTZ)
    )
    WITH LOCATION = @{{ stage_path }}
    AUTO_REFRESH = FALSE
    FILE_FORMAT = (TYPE = JSON)
{% endset %}

{% do run_query(create_table_sql) %}
{% do log('Created external table: ' ~ database ~ '.' ~ schema ~ '.' ~ table_name, info=True) %}

{% endmacro %}