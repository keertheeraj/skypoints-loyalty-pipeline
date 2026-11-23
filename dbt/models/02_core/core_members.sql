-- One row per member: latest valid record wins, with country, Age and Stale_Member
-- Age and Stale_Member use today, or --vars "{run_date: 'YYYY-MM-DD'}" to reproduce a past day

{{ config(schema = 'CORE') }}

{% set as_of_date = "'" ~ var('run_date', run_started_at.strftime('%Y-%m-%d')) ~ "'::date" %}

with valid_members as (

    -- Mandatory fields from the source contract
    select *
    from {{ ref('stg_members') }}
    where member_id is not null
      and member_name is not null
      and enrollment_date is not null

),

with_file_timestamp as (

    select
        valid_members.*,
        {{ file_timestamp('source_file_name') }} as file_timestamp
    from valid_members

),

with_country as (

    -- members with an unknown country cannot be routed to a country table
    select
        with_file_timestamp.*,
        country_mapping.country_code,
        country_mapping.country_name,
        country_mapping.target_table
    from with_file_timestamp
    inner join {{ ref('country_mapping') }} as country_mapping
        on with_file_timestamp.country = country_mapping.source_country_code

),

latest_record as (

    -- Newest file wins; then most recent flight; then file name and last line as final tie breakers
    select *
    from with_country
    qualify row_number() over (
        partition by member_id
        order by
            file_timestamp desc,
            last_flight_date desc nulls last,
            source_file_name desc,
            source_file_row_number desc
    ) = 1

),

final as (

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
        target_table,
        date_of_birth,
        is_active,

        floor(months_between({{ as_of_date }}, date_of_birth) / 12)::int as age,

        case
            when last_flight_date is null then true
            when datediff('day', last_flight_date, {{ as_of_date }}) > {{ var('stale_after_days') }} then true
            else false
        end as stale_member,

        file_timestamp,
        source_file_name,
        loaded_at
    from latest_record

)

select * from final