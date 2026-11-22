-- Fails for values longer than the length in the source contract

{% test max_length(model, column_name, length) %}

select {{ column_name }}
from {{ model }}
where length({{ column_name }}) > {{ length }}

{% endtest %}
