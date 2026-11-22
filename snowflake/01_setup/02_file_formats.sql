-- File formats used by COPY INTO to read each feed

USE ROLE SKYPOINTS_ENGINEER;
USE WAREHOUSE SKYPOINTS_WH;
USE DATABASE SKYPOINTS_DEV;
USE SCHEMA RAW;


-- Member flat file: pipe delimited

CREATE OR REPLACE FILE FORMAT FF_MEMBER_PIPE
    TYPE                           = 'CSV'
    FIELD_DELIMITER                = '|'
    SKIP_HEADER                    = 0
    EMPTY_FIELD_AS_NULL            = TRUE
    NULL_IF                        = ()
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    ENCODING                       = 'UTF8'
    COMMENT                        = 'Member flat file, pipe delimited';


-- Redemption feed: one JSON object per line

CREATE OR REPLACE FILE FORMAT FF_REDEMPTION_JSON
    TYPE              = 'JSON'
    STRIP_OUTER_ARRAY = FALSE
    COMMENT           = 'Redemption feed, newline delimited JSON';