-- Scheduled Tasks that load staged files into RAW
-- Runs daily 03:00 IST; COPY INTO skips files already loaded

USE ROLE SKYPOINTS_ENGINEER;
USE WAREHOUSE SKYPOINTS_WH;
USE DATABASE SKYPOINTS_DEV;
USE SCHEMA RAW;


-- Members: $1 is empty (leading pipe), $2 is record type

CREATE OR REPLACE TASK TASK_LOAD_MEMBERS
    WAREHOUSE = SKYPOINTS_WH
    SCHEDULE  = 'USING CRON 0 3 * * * Asia/Kolkata'
    COMMENT   = 'Daily load of member files into MEMBERS'
AS
COPY INTO MEMBERS (
    RECORD_TYPE,
    MEMBER_NAME,
    MEMBER_ID,
    ENROLLMENT_DATE,
    LAST_FLIGHT_DATE,
    TIER_CODE,
    AGENT_NAME,
    STATE,
    COUNTRY,
    DOB,
    IS_ACTIVE,
    SOURCE_FILE_NAME,
    SOURCE_FILE_ROW_NUMBER,
    LOADED_AT
)
FROM (
    SELECT
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8,
        $9,
        $10,
        $11,
        $12,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
    FROM @LANDING_STAGE/members/
)
PATTERN     = '.*MEMBERS_[0-9]{8}_[0-9]{8}[.]dat'
FILE_FORMAT = (FORMAT_NAME = 'FF_MEMBER_PIPE')
ON_ERROR    = 'CONTINUE';


-- Redemptions: each JSON line stored whole in RAW_PAYLOAD

CREATE OR REPLACE TASK TASK_LOAD_REDEMPTIONS
    WAREHOUSE = SKYPOINTS_WH
    SCHEDULE  = 'USING CRON 0 3 * * * Asia/Kolkata'
    COMMENT   = 'Daily load of redemption files into REDEMPTIONS'
AS
COPY INTO REDEMPTIONS (
    RAW_PAYLOAD,
    SOURCE_FILE_NAME,
    SOURCE_FILE_ROW_NUMBER,
    LOADED_AT
)
FROM (
    SELECT
        $1,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
    FROM @LANDING_STAGE/redemptions/
)
PATTERN     = '.*REDEMPTIONS_[0-9]{8}_[0-9]{8}[.]json'
FILE_FORMAT = (FORMAT_NAME = 'FF_REDEMPTION_JSON')
ON_ERROR    = 'CONTINUE';


-- Tasks are created suspended
-- Run once:        EXECUTE TASK TASK_LOAD_MEMBERS;
-- Start schedule:  ALTER TASK TASK_LOAD_MEMBERS RESUME;