# ETL: PostgreSQL to DuckDB

## Overview

This ETL process exports the application's primary financial data from PostgreSQL into a local DuckDB file for lightweight, fast analysis on developer machines or in ad-hoc analytics.

## Usage

Run the Rake task via Docker Compose:

```bash
docker-compose run --rm web bundle exec rake etl:to_duckdb
```

The task connects to the app's PostgreSQL database and writes a DuckDB database file locally.

## Output

The generated DuckDB database is written to [db/production.duckdb](db/production.duckdb).

## Exported Data

The ETL exports the core domain tables used for financial reporting and analysis, including:

- families
- accounts
- entries
- transactions
- categories
- merchants
- users
- transfers
- budgets
- security_prices

## Notes

- The process is read-only against PostgreSQL and safe to run repeatedly; the DuckDB file is overwritten on each run.
- The DuckDB schema mirrors the PostgreSQL sources for the listed tables, enabling joins and aggregations in DuckDB.