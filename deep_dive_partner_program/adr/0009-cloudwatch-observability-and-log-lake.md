# 0009 · CloudWatch-native observability with an S3 + Athena log lake

**Status:** Accepted

## Context
We need alarms, one queryable log format, and long-term analytics without new vendors.

## Decision
structlog (Django) and Powertools (Lambda) with one schema; metrics via EMF from the same log lines; CloudWatch alarms and dashboards in IaC. CloudWatch Logs → Firehose → S3 → Athena for the long term, plus a daily Postgres export for business numbers.

## Consequences
- + One emission feeds metrics, debugging and analytics; low operational load.
- − Minutes of lake latency; log groups must be Standard class; EMF on ECS/EC2 needs verifying.
