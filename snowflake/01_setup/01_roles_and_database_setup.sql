-- Create the role, One role owns every object specific to the usecase

USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS SKYPOINTS_ENGINEER
    COMMENT = 'Owns and runs the SkyPoints loyalty pipeline';

GRANT ROLE SKYPOINTS_ENGINEER TO ROLE SYSADMIN;

-- assign the role to the current user
SET current_user_name = CURRENT_USER();
GRANT ROLE SKYPOINTS_ENGINEER TO USER IDENTIFIER($current_user_name);


-- Create the warehouse compute
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS SKYPOINTS_WH
    WAREHOUSE_SIZE      = 'XSMALL'
    AUTO_SUSPEND        = 60
    AUTO_RESUME         = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT             = 'compute for SkyPoints ingestion and dbt runs';

GRANT USAGE   ON WAREHOUSE SKYPOINTS_WH TO ROLE SKYPOINTS_ENGINEER;
GRANT OPERATE ON WAREHOUSE SKYPOINTS_WH TO ROLE SKYPOINTS_ENGINEER;


-- create the database and its access to the pipeline role

CREATE DATABASE IF NOT EXISTS SKYPOINTS_DEV
    COMMENT = 'SkyPoints loyalty pipeline, development environment';

GRANT OWNERSHIP ON DATABASE SKYPOINTS_DEV
    TO ROLE SKYPOINTS_ENGINEER
    COPY CURRENT GRANTS;


-- Allow the role to run scheduled Tasks
USE ROLE ACCOUNTADMIN;

GRANT EXECUTE TASK ON ACCOUNT TO ROLE SKYPOINTS_ENGINEER;


-- Create the four layer schemas as the pipeline role

USE ROLE SKYPOINTS_ENGINEER;
USE WAREHOUSE SKYPOINTS_WH;
USE DATABASE SKYPOINTS_DEV;

CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Landing layer: files loaded as is, all VARCHAR';

CREATE SCHEMA IF NOT EXISTS STAGING
    COMMENT = 'Cleaned and typed data';

CREATE SCHEMA IF NOT EXISTS CORE
    COMMENT = 'Single source of truth per object';

CREATE SCHEMA IF NOT EXISTS GOLD
    COMMENT = 'Consumption layer';