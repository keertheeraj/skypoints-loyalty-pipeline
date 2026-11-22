-- Redemption feed flattened: one row per transaction, cleaned and typed
-- Incremental: only rows loaded since the last run

{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'append'
    )
}}

with source_rows as (

    select *
    from {{ source('raw', 'redemptions') }}

    {% if is_incremental() %}
        where LOADED_AT > (select max(loaded_at) from {{ this }})
    {% endif %}

),

flattened as (

    select
        source_rows.RAW_PAYLOAD:member_id::varchar                              as member_id,
        try_to_date(source_rows.RAW_PAYLOAD:feed_date::varchar, 'YYYYMMDD')     as feed_date,
        redemption.value:txn_id::varchar                                        as txn_id,
        try_to_date(redemption.value:txn_date::varchar, 'YYYYMMDD')             as txn_date,
        redemption.value:partner::varchar                                       as partner,
        try_to_number(redemption.value:miles_redeemed::varchar)                 as miles_redeemed,
        upper(redemption.value:status::varchar)                                 as status,
        source_rows.SOURCE_FILE_NAME                                            as source_file_name,
        source_rows.SOURCE_FILE_ROW_NUMBER                                      as source_file_row_number,
        source_rows.LOADED_AT                                                   as loaded_at
    from source_rows,
        lateral flatten(input => source_rows.RAW_PAYLOAD:redemptions) as redemption

)

select * from flattened
