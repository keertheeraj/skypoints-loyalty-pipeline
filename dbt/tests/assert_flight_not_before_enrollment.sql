-- A member cannot fly before enrolling; reported, not blocking

{{ config(severity = 'warn') }}

select
    member_id,
    member_name,
    enrollment_date,
    last_flight_date,
    source_file_name
from {{ ref('stg_members') }}
where last_flight_date < enrollment_date
