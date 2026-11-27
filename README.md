# InsureNext Partner Programs: Case Study

> **Start here: read only `partner-programs-design.html` (or the same content in `partner-programs-design.md`).** That's the submission. Everything else in this folder is supporting material.

This is my response to the engineering case study in `eng_case_study.pdf`: a design for offering partner-specific programs, with customizable questions, rating and discounts in any combination, on top of InsureNext's existing Django, Postgres and Lambda rater platform. I chose to expand what's already there rather than rebuild it. The design adds versioned programs with full version history, keeps question definitions immutable per rater version, lets the rater declare its inputs once in code so keys are never typed twice, and gives partners an external API that publishes each program's data contract. That contract stops junk data before it's stored. The doc covers the data model, how a program gets rated, the APIs, the change workflows, how missing or bad data is stopped before it reaches the rater, rollout, and the trade-offs and assumptions I made. The diagrams it uses are in `diagrams/`.

`demo/` is the build artifact. It has an interactive walkthrough page (questions worded per partner, and the generated partner contract rejecting junk data) and the runnable question data model in Postgres, with a script that tries 12 forbidden writes and shows the database refusing each one. See `demo/README.md`.

`deep_dive_partner_program/` holds my working notes for the live review: detailed schema with every key and constraint, API design, workflows, observability, infrastructure, risks, open questions, and ADRs. It goes deeper than the submission and isn't meant to be read cold.
