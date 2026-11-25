# 0003 · The rater declares its inputs once; the manifest is generated

**Status:** Accepted

## Context
Question keys are typed in the question system and again in the rater, and they drift (PM).

## Decision
The rater declares each input (key, type, values, required) in its own code and reads answers only through that declaration. The build generates a manifest (inputs, overridable tables and limits, modules, discount rules), and CI registers it with the rater version. Questions, publish validation, the Ops interface and Django's preflight all use the manifest.

## Consequences
- + One definition of every rating key, checked by machine everywhere else.
- − A one-time refactor of the rater's input handling.
