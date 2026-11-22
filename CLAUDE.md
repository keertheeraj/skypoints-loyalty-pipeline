# CLAUDE.md

Guidance for Claude Code working in this repository.

## Scenario

SkyPoints is a global airline loyalty program with lounges and partner airlines worldwide.
Every member gets a Membership Card used to access partner lounges, redeem miles and track
tier status.

All members (millions) currently sit in one database. The business wants members split by
country into separate country tables.

A Source System extracts member data from wherever it lives and sends **two feeds every day**:

1. **Member profile flat file**: pipe delimited, an `|H|` header line followed by `|D|` detail lines.
2. **Redemption feed**: JSON from partner airlines, one member object per line with a nested
   `redemptions` array (txn_id, txn_date, partner, miles_redeemed, status).

The pipeline must be designed for billions of records per day.

## Problem

Build an ELT pipeline that takes the daily feeds and produces trustworthy, per country member
tables plus a queryable redemptions table. The raw extracts are messy: mixed country codes,
inconsistent date formats, missing mandatory fields, invalid values and duplicates.

## What to build

1. DDL for raw (landing), staging and per country target tables in Snowflake.
2. Staging with derived columns:
   * `Age` from DOB
   * `Stale_Member` flag when more than 90 days have passed since the last flight
3. Per country member tables. **Latest record wins**: if a member appears with a new country,
   they move to the new country table and leave the old one.
4. Flatten the JSON redemption feed into one row per transaction, joinable to members on member_id.
5. Data validations: mandatory fields, key uniqueness, and checks for known data quality issues.
   Bad rows go to a rejects model with a reason, never silently dropped.

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

## Decisions and assumptions (keep README in sync)

* **Member_Id is the key**. The contract marks Member Name as key, but names are not unique.
* Post Code appears in the contract but not in the header or sample rows. Columns are mapped
  as received; `post_code` stays nullable if it appears later.
* DOB in samples is `MMDDYYYY`; other dates are `YYYYMMDD`.
* Country codes are inconsistent (`AU`, `PHIL`); normalise via a `country_mapping` seed.
* The file timestamp from the file name decides "latest record wins".
* Redemption files are newline delimited JSON.
* "Today" for Age and Stale_Member is a dbt var `run_date`, never `CURRENT_DATE` directly,
  so results and tests are deterministic.
* `data/reference_samples/` (AUS.xlsx, IND.csv, USA.csv) do not follow the contract. They are
  examples of data quality issues used to design validation tests, not pipeline inputs.
* Files that do not match the agreed name, extension or format are rejected at ingestion.
  New formats are onboarded as new feeds, not converted ad hoc.

## Architecture

```
data/ (sample feeds)
  -> ingest/ingest.py: validates file names, PUT to internal stage (folders by feed and date)
  -> Snowflake Tasks: COPY INTO RAW tables (all VARCHAR + audit columns)
  -> dbt STAGING: clean, type, derive Age and Stale_Member, route bad rows to rejects
  -> dbt CORE: one row per member (latest wins, incremental MERGE), deduplicated redemptions
  -> dbt GOLD: per country member tables, redemptions joined to members
```

* Stack: Snowflake, dbt Core 1.12, one small Python script.
* `ingest.py` **only simulates the Source System file drop** (PUT). It never loads tables.
* Loading runs **inside Snowflake** as scheduled Tasks, so it can be scheduled and deployed by CI/CD.
* A later Task will run dbt (`EXECUTE DBT PROJECT`) `AFTER` the load Tasks.
* Production design (documented, not deployed): external stage on Azure Blob or S3 with
  Snowpipe auto ingest; ADF or Airflow orchestration; CI/CD deploying to a PROD database.
* Incremental strategy:
  * Local to stage: `PUT ... OVERWRITE = FALSE` skips files already staged.
  * Stage to RAW: COPY INTO load history skips files already loaded.
  * RAW to STAGING: dbt incremental on `LOADED_AT`.
  * STAGING to CORE: dbt incremental MERGE on member key.
* Gold country tables are filters on CORE, so a member who moves country disappears from the
  old table automatically.

### Deliberately not built

* No Spark / PySpark.
* No aggregate gold tables.
* No Excel or CSV handling.
* No real PROD deployment (described in README instead).

## Snowflake objects

| Object | Name |
|---|---|
| Role | `SKYPOINTS_ENGINEER` |
| Warehouse | `SKYPOINTS_WH` (XS, auto suspend 60s) |
| Database | `SKYPOINTS_DEV` |
| Schemas | `RAW`, `STAGING`, `CORE`, `GOLD` |
| File formats | `RAW.FF_MEMBER_PIPE`, `RAW.FF_REDEMPTION_JSON` |
| Stage | `RAW.LANDING_STAGE` (internal, directory table enabled) |
| Raw tables | `RAW.MEMBERS`, `RAW.REDEMPTIONS` |
| Load tasks | `RAW.TASK_LOAD_MEMBERS`, `RAW.TASK_LOAD_REDEMPTIONS` (daily 03:00 IST, created suspended) |

* Stage layout: `@RAW.LANDING_STAGE/<feed>/YYYY/MM/DD/<file>` (feed = `members` or `redemptions`).
* `RAW.MEMBERS` columns: `RECORD_TYPE`, `MEMBER_NAME`, `MEMBER_ID`, `ENROLLMENT_DATE`,
  `LAST_FLIGHT_DATE`, `TIER_CODE`, `AGENT_NAME`, `STATE`, `COUNTRY`, `DOB`, `IS_ACTIVE`,
  plus audit columns `SOURCE_FILE_NAME`, `SOURCE_FILE_ROW_NUMBER`, `LOADED_AT`.
* `RAW.REDEMPTIONS` columns: `RAW_PAYLOAD` (VARIANT) plus the same audit columns.
* `RECORD_TYPE`: `H` header line, `D` member line. Staging keeps only `D`.
* Member COPY skips `$1` (always empty due to the leading pipe) and maps `$2` to `$12`.
* File format keeps the text `NULL` as text (`NULL_IF = ()`) and loads short rows
  (`ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE`) so staging can reject them with a reason.
* Authentication: key pair (`SNOWFLAKE_JWT`). Credentials in `.env` and `~/.dbt/profiles.yml`,
  both outside version control. See `docs/snowflake_key_pair_setup.md`.

## Repository layout

```
data/                     sample feeds (members, redemptions), reference_samples, README.md
snowflake/01_setup/       01 roles and database, 02 file formats, 03 stage, 04 raw tables
snowflake/02_task/        scheduled load tasks
ingest/                   ingest.py and tests/ (pytest)
dbt/                      dbt project "skypoints_transformations" (models/staging, core, gold)
docs/                     ai_usage.md, snowflake_key_pair_setup.md
```

## Test scenarios

`data/README.md` lists every scenario in the day 2 files with its expected result: country move,
stale flag change, new member, NULL text DOB, month 13, missing mandatory fields, unknown tier and
country, duplicate rows, flight before enrollment, invalid leap day, short row, PENDING to COMPLETED
status, duplicate txn_id, orphan member_id, negative miles, empty redemptions array.
Each scenario should be covered by a dbt unit test, a dbt data test or a pytest test.

## Working conventions

### TDD and commits

* Write the failing test first, make it pass, then refactor. Commit each step.
* Conventional commits, present tense, lowercase:
  `feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`, `ci:`.
* Small commits, one logical change each.
* Branches `type/short-description` (for example `feat/staging-models`), merged to `main` via
  pull request. Always branch from an up to date `main`.

### Code style

Readable, step by step code, like a tutorial:

* Clear, descriptive names. No single letter variables.
* One action per line. Avoid dense one liners.
* Comments minimal and to the point; explain **why**, not what.
* SQL: one column per line, uppercase keywords, short header comment, rerunnable DDL
  (`IF NOT EXISTS` for tables, `CREATE OR REPLACE` for formats and tasks).
* Keep code short enough to explain clearly in a walkthrough.

### Writing style

* In prose (README, docs, PR descriptions, comments), do not use dash characters. Use words such
  as "to" for ranges and avoid hyphenated words. Code, flags and file names are exempt.
* README separates "What was asked" from "Decisions made and why".

### dbt conventions

* Model names: `stg_` (staging), `core_` (core), gold country tables such as `table_india`, `table_usa`.
* RAW tables are dbt sources; seeds only for small reference data
  (`country_mapping.csv`, `tier_mapping.csv`).
* Add a `generate_schema_name` macro so custom schemas are used as is (avoid `STAGING_STAGING`).
* Rejected rows go to a rejects model with a reason column.
* dbt unit tests for logic (Age, Stale_Member, date parsing, latest wins); data tests for constraints.

### Safety

* Never commit `.env`, `*.p8`, `*.pem`, `profiles.yml`, `target/`, `logs/`.
* LF line endings (enforced by `.gitattributes`); CRLF would leave `\r` in the last pipe column.
* Never hardcode credentials or the database name in Python; read from `.env`.

## Common commands

```powershell
.venv\Scripts\Activate.ps1
pip install -r requirements.txt

pytest ingest/tests
python -m ingest.ingest --dry-run
python -m ingest.ingest

cd dbt
dbt debug
dbt seed
dbt build --vars "{run_date: '2024-01-16'}"
```

```sql
EXECUTE TASK SKYPOINTS_DEV.RAW.TASK_LOAD_MEMBERS;
EXECUTE TASK SKYPOINTS_DEV.RAW.TASK_LOAD_REDEMPTIONS;
```

## Current status

* Done: repo setup, dbt init (`dbt debug` passes), sample data, Snowflake setup scripts,
  load tasks, ingest.py with tests. RAW tables loaded with two days of data.
* Next: `feat/staging-models` (sources, `generate_schema_name` macro, seeds, staging models,
  rejects, unit tests), then core and gold models, README, CI workflow, `docs/ai_usage.md` entries.