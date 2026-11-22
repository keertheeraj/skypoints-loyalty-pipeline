-- Internal stage: landing zone for daily files
-- Layout: @LANDING_STAGE/<feed>/YYYY/MM/DD/<file>

USE ROLE SKYPOINTS_ENGINEER;
USE WAREHOUSE SKYPOINTS_WH;
USE DATABASE SKYPOINTS_DEV;
USE SCHEMA RAW;

CREATE STAGE IF NOT EXISTS LANDING_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT   = 'Landing zone for member and redemption files';