-- Redemptions joined to member profile on member_id

{{ config(schema = 'GOLD') }}

select
    redemptions.txn_id,
    redemptions.txn_date,
    redemptions.partner,
    redemptions.miles_redeemed,
    redemptions.status,
    members.member_id,
    members.member_name,
    members.tier_code,
    members.country_code,
    members.country_name
from {{ ref('core_redemptions') }} as redemptions
inner join {{ ref('core_members') }} as members
    on redemptions.member_id = members.member_id
