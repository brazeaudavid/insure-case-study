# Diagrams

Every diagram has a rendered `.svg` next to its source. The submission doc uses copies of `c4-container`, `er-diagram`, `question-model` and `validation-chain` in `../../diagrams/`. Re-copy them after re-rendering.

| Diagram | Source | Used in |
|---|---|---|
| C4 context | `c4-context.d2` | 07 |
| C4 container | `c4-container.d2` | 07, submission §5 |
| Data model (ER, PK/FK) | `er-diagram.mmd` | 03, submission §3 |
| Question tables only | `question-model.mmd` | 03, submission §3 |
| Partner submission → rating (sequence) | `partner-submission.mmd` | 04, 05 |
| Program version lifecycle (state) | `program-version-lifecycle.mmd` | 05 |
| Rater change gate (sequence) | `rater-change-gate.mmd` | 05 |
| Validation chain (flow) | `validation-chain.mmd` | 05, submission §7 |
| Base rebase (flow) | `base-rebase.mmd` | 02 |
| Logging pipeline | `logging-pipeline.d2` | 06 |

## Re-render
- D2: `d2 c4-container.d2 c4-container.svg`
- Mermaid: `mmdc -p pptr.json -i er-diagram.mmd -o er-diagram.svg -b white`, where `pptr.json` is `{"executablePath": "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}` (mmdc's bundled browser isn't installed on this machine).
