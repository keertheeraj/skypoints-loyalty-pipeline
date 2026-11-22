-- Members whose target_table matches the calling model's name
-- Example: model usa_member selects members with target_table = 'usa_member'

{% macro country_members() %}

select
    member_id,
    member_name,
    enrollment_date,
    last_flight_date,
    tier_code,
    agent_name,
    state,
    country_code,
    country_name,
    date_of_birth,
    age,
    stale_member,
    is_active
from {{ ref('core_members') }}
where target_table = '{{ this.name }}'

{% endmacro %}
