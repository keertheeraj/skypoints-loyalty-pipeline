-- One row per transaction: latest status wins, only for known members

{{ config(schema = 'CORE') }}

with valid_redemptions as (

    select *
    from {{ ref('stg_redemptions') }}
    where txn_id is not null
      and txn_date is not null
      and miles_redeemed >= 0

),

with_file_timestamp as (

    select
        valid_redemptions.*,
        {{ file_timestamp('source_file_name') }} as file_timestamp
    from valid_redemptions

),

latest_record as (

    -- A later file can update a transaction (PENDING to COMPLETED)
    select *
    from with_file_timestamp
    qualify row_number() over (
        partition by txn_id
        order by file_timestamp desc, source_file_row_number desc
    ) = 1

),

known_members as (

    -- Redemptions for members not in core are left out (reported by staging tests)
    select latest_record.*
    from latest_record
    inner join {{ ref('core_members') }} as core_members
        on latest_record.member_id = core_members.member_id

)

select
    txn_id,
    member_id,
    txn_date,
    partner,
    miles_redeemed,
    status,
    feed_date,
    file_timestamp,
    source_file_name,
    loaded_at
from known_members
