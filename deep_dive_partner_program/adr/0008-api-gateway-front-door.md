# 0008 · Amazon API Gateway (REST) and Cognito as the front door

**Status:** Accepted (internal exposure depends on Q-14)

## Context
We need per-partner identity, throttling, coarse validation and access logs, and a stable entry point as services are added.

## Decision
Amazon API Gateway, REST type, fronts both surfaces. WAF on the external one. Cognito issues partner client-credential tokens and federates staff SSO. CI lints and diff-checks every spec before deploying it to the gateway.

## Consequences
- + One place for identity, limits, logs and routing; AWS-managed.
- − Per-request cost, the 29 s integration timeout, the 10 MB payload limit; partners must cache tokens.
