-- Read the file timestamp from a name like .../MEMBERS_20240115_02300000.dat
-- Uses YYYYMMDD and HHMMSS; hundredths (TT) are ignored

{% macro file_timestamp(file_name_column) -%}
    TRY_TO_TIMESTAMP(
        REPLACE(REGEXP_SUBSTR({{ file_name_column }}, '[0-9]{8}_[0-9]{6}'), '_', ''),
        'YYYYMMDDHH24MISS'
    )
{%- endmacro %}
