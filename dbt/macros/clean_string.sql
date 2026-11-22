-- Trim text and turn empty strings and the text 'NULL' into real NULLs

{% macro clean_string(column_name) -%}
    NULLIF(NULLIF(TRIM({{ column_name }}), ''), 'NULL')
{%- endmacro %}
