# dbt project: skypoints_transformations

Transforms the raw SkyPoints feeds into staging, core and per country gold tables.
See the repository [README](../README.md) for the architecture, decisions and how to run.

| Folder | Contents |
|---|---|
| `models/01_staging` | Cleaned and typed copies of the raw feeds, incremental on `LOADED_AT` |
| `models/02_core` | One row per member and per transaction; country, Age and Stale_Member |
| `models/03_gold` | Per country member tables and member redemptions |
| `seeds` | `country_mapping` (REFERENCE schema) |
| `macros` | Schema naming, string cleaning, file timestamp, country members |
| `tests` | Generic tests (`max_length`, `non_negative`) and singular data tests |

```powershell
dbt seed
dbt build                                      # Age and Stale_Member as of today
dbt build --vars "{run_date: '2024-01-16'}"    # reproduce the sample data results
```
