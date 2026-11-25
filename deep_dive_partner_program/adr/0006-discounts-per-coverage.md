# 0006 · Discounts stored per coverage

**Status:** Accepted for modeling; semantics pending Q-03, permissibility Q-01

## Context
Discounts are questions answered per application but rated per coverage.

## Decision
New applications store discounts in `application_discount` per coverage. Programs narrow underwriter limits and define program discounts in config. Stacking rules come from the manifest once confirmed.

## Consequences
- + Unambiguous discounts per coverage.
- − Historical discount answers stay in legacy storage.
