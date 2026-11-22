-- RAW tables: files loaded as is
-- All source columns VARCHAR so bad values never fail the load
-- Audit columns trace every row to its file and line

USE ROLE SKYPOINTS_ENGINEER;
USE WAREHOUSE SKYPOINTS_WH;
USE DATABASE SKYPOINTS_DEV;
USE SCHEMA RAW;



CREATE TABLE IF NOT EXISTS MEMBERS (
    RECORD_TYPE             VARCHAR,
    MEMBER_NAME             VARCHAR,
    MEMBER_ID               VARCHAR,
    ENROLLMENT_DATE         VARCHAR,
    LAST_FLIGHT_DATE        VARCHAR,
    TIER_CODE               VARCHAR,
    AGENT_NAME              VARCHAR,
    STATE                   VARCHAR,
    COUNTRY                 VARCHAR,
    DOB                     VARCHAR,
    IS_ACTIVE               VARCHAR,
    SOURCE_FILE_NAME        VARCHAR         NOT NULL,
    SOURCE_FILE_ROW_NUMBER  NUMBER          NOT NULL,
    LOADED_AT               TIMESTAMP_NTZ   NOT NULL
)
COMMENT = 'Member flat file, loaded as is';



CREATE TABLE IF NOT EXISTS REDEMPTIONS (
    RAW_PAYLOAD             VARIANT,
    SOURCE_FILE_NAME        VARCHAR         NOT NULL,
    SOURCE_FILE_ROW_NUMBER  NUMBER          NOT NULL,
    LOADED_AT               TIMESTAMP_NTZ   NOT NULL
)
COMMENT = 'Redemption JSON feed, loaded as is';