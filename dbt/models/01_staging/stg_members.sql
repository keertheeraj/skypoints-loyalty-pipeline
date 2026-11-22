-- Member lines from the flat file: cleaned and typed
-- Incremental: only rows loaded since the last run

{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'append'
    )
}}

with source_rows as (

    select *
    from {{ source('raw', 'members') }}
    where RECORD_TYPE = 'D'

    {% if is_incremental() %}
        and LOADED_AT > (select max(loaded_at) from {{ this }})
    {% endif %}

),

cleaned as (

    select
        {{ clean_string('MEMBER_ID') }}                                  as member_id,
        {{ clean_string('MEMBER_NAME') }}                                as member_name,
        try_to_date({{ clean_string('ENROLLMENT_DATE') }}, 'YYYYMMDD')   as enrollment_date,
        try_to_date({{ clean_string('LAST_FLIGHT_DATE') }}, 'YYYYMMDD')  as last_flight_date,
        upper({{ clean_string('TIER_CODE') }})                           as tier_code,
        {{ clean_string('AGENT_NAME') }}                                 as agent_name,
        upper({{ clean_string('STATE') }})                               as state,
        upper({{ clean_string('COUNTRY') }})                             as country,
        try_to_date({{ clean_string('DOB') }}, 'MMDDYYYY')               as date_of_birth,
        upper({{ clean_string('IS_ACTIVE') }})                           as is_active,
        SOURCE_FILE_NAME                                                 as source_file_name,
        SOURCE_FILE_ROW_NUMBER                                           as source_file_row_number,
        LOADED_AT                                                        as loaded_at
    from source_rows

)

select * from cleaned
