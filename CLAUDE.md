# CLAUDE.md

Guidance for Claude Code working in this repository.

## Scenario

SkyPoints is a global airline loyalty program. Members get a Membership Card for partner lounges,
miles redemption and tier status. All members sit in one database; the business wants them split
into per country tables.

A Source System sends **two feeds every day**:

1. **Member flat file**: pipe delimited, `|H|` header line then `|D|` member lines.
2. **Redemption feed**: newline delimited JSON, one member object per line with a nested
   `redemptions` array (txn_id, txn_date, partner, miles_redeemed, status).

Design for billions of records per day.

## Source contract (member flat file)

| Pos | Column | Length | Type | Mandatory |
|---|---|---|---|---|
| 1 | Member Name | 255 | VARCHAR | Y |
| 2 | Member ID | 18 | VARCHAR | Y |
| 3 | Enrollment Date | 8 | DATE | Y |
| 4 | Last Flight Date | 8 | DATE | N |
| 5 | Tier Code | 5 | CHAR | N |
| 6 | Agent Name | 255 | CHAR | N |
| 7 | State | 5 | CHAR | N |
| 8 | Country | 5 | CHAR | N |
| 9 | Post Code | 5 | INT | N |
| 10 | Date of Birth | 8 | DATE | N |
| 11 | Active Member | 1 | CHAR | N |

File names: `<NAME>_<YYYYMMDD>_<HHMMSSTT>.<ext>`, for example `MEMBERS_20240115_02300000.dat`.

### Layer rules

* **ingest.py** only validates file names and uploads (PUT). It never loads tables.
* **RAW**: all VARCHAR (JSON as VARIANT) plus `SOURCE_FILE_NAME`, `SOURCE_FILE_ROW_NUMBER`, `LOADED_AT`.
* **STAGING**: cleanup only. Keep `RECORD_TYPE = 'D'`, trim, empty and `'NULL'` text to null (`clean_string`
  macro), `TRY_TO_DATE` (`YYYYMMDD`, DOB `MMDDYYYY`), `TRY_TO_NUMBER`, flatten JSON. No new columns, no
  business logic. Incremental append on `LOADED_AT`.
* **CORE**: all business logic and new columns. Filter mandatory fields, `file_timestamp` macro, country via
  seed (inner join, unknown country excluded), latest record wins, Age and Stale_Member.
* **GOLD**: `country_members()` macro selects core members where `target_table = this.name`;
  `member_redemptions` joins redemptions to members.

### Key decisions

* Member_Id is the key (contract says Member Name; names are not unique).
* Latest record: `order by file_timestamp desc, last_flight_date desc nulls last, source_file_row_number desc`.
* Age: `floor(months_between(run_date, date_of_birth) / 12)`; Stale: no flight, or more than
  `stale_after_days` (90) before `run_date`. `run_date` is a dbt var (default `2024-01-16` for the sample data).
* Tests: staging **warn**, everything else **error**; all store failures in `TEST_FAILURES`.
* Reference samples (AUS.xlsx, IND.csv, USA.csv) are not inputs; they inspired test scenarios.
* Deliberately not built: Spark, aggregate gold tables, Excel handling, staging unit tests, real PROD deployment.

## Snowflake objects

| Object | Name |
|---|---|
| Role / Warehouse / Database | `SKYPOINTS_ENGINEER` / `SKYPOINTS_WH` (XS) / `SKYPOINTS_DEV` |
| Schemas | `RAW`, `STAGING`, `CORE`, `GOLD`, `REFERENCE`, `TEST_FAILURES` |
| File formats | `RAW.FF_MEMBER_PIPE`, `RAW.FF_REDEMPTION_JSON` |
| Stage | `RAW.LANDING_STAGE` |
| Raw tables | `RAW.MEMBERS`, `RAW.REDEMPTIONS` |
| Load tasks | `RAW.TASK_LOAD_MEMBERS`, `RAW.TASK_LOAD_REDEMPTIONS` (03:00 IST, created suspended) |
| Seed | `REFERENCE.COUNTRY_MAPPING` (target tables `usa_member`, `india_member`, ...) |

Auth: key pair (`SNOWFLAKE_JWT`); `.env` for Python, `~/.dbt/profiles.yml` for dbt, both outside Git.

## Repository layout

```
data/                     sample feeds (two days), reference_samples, README.md
snowflake/01_setup/       01 roles and database, 02 file formats, 03 stage, 04 raw tables
snowflake/02_task/        01_load_raw_tasks.sql
ingest/ingest.py
dbt/                      project skypoints_transformations
  macros/                 generate_schema_name, clean_string, file_timestamp, country_members
  seeds/                  country_mapping.csv, _seeds.yml
  models/01_staging/      _sources.yml, _staging.yml, stg_members, stg_redemptions
  models/02_core/         _core.yml, core_members, core_redemptions
  models/03_gold/         _gold.yml, five country tables, member_redemptions
  tests/generic/          max_length, non_negative
docs/                     snowflake_key_pair_setup.md
```

## Conventions

* Conventional commits (`feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`), present tense, small commits.
* Branches `type/short-description`, merged to `main` by pull request; branch from an up to date `main`.
* Readable, step by step code: descriptive names, one action per line, minimal comments that explain why.
* SQL: CTE per step, one column per line, rerunnable DDL.
* Prose (README, docs, PRs, comments): no dash characters; use "to" for ranges, avoid hyphenated words.
* Never commit `.env`, `*.p8`, `*.pem`, `profiles.yml`, `target/`, `logs/`. LF line endings.
* dbt State is disabled (`flags: manage_state: false`); the `dbt-state` package must not be installed.

## Commands

```powershell
.venv\Scripts\Activate.ps1
python -m ingest.ingest --dry-run
python -m ingest.ingest
cd dbt
dbt seed
dbt build --vars "{run_date: '2024-01-16'}"
```

```sql
EXECUTE TASK SKYPOINTS_DEV.RAW.TASK_LOAD_MEMBERS;
EXECUTE TASK SKYPOINTS_DEV.RAW.TASK_LOAD_REDEMPTIONS;
```

## Status

* Done: setup, ingest, raw load tasks, staging, core, gold, tests, README.
* Optional next: CI workflow, dbt build task chained after the load tasks.