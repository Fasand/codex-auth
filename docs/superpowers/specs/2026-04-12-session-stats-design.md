# Session Statistics Design

## Goal
Add global historical session usage statistics to `codex-auth`, based on Codex rollout JSONL files under `~/.codex/sessions`, with a new `stats` command (`statistics` alias) and a compact two-line footer in `list`.

## Scope
- Global statistics across all local sessions on the machine
- Calendar-aligned rolling windows: today, 7d, 14d, 30d, all-time
- Verbose `stats` output with overview, daily breakdown, model breakdown, and cost notes
- Compact `list` footer with today + 7d summaries
- Estimated API-equivalent cost using official OpenAI pricing cached locally

## Non-goals
- Per-profile historical attribution
- Interactive arrow-key/TUI navigation in v1
- Exact ChatGPT subscription billing reconstruction

## Data source
Parse `event_msg` records with `payload.type == "token_count"` from rollout JSONL files. Use `last_token_usage` rather than cumulative `total_token_usage` to avoid double counting. Use `turn_context.model` as the per-event model when available.

## Time semantics
Use local timezone by default and UTC with `--utc`.
- today: local midnight to now
- 7d: start of day 6 days ago to now
- 14d: start of day 13 days ago to now
- 30d: start of day 29 days ago to now
- all: earliest token event day to now, labeled with inclusive day count

## Statistics shown
### `list` footer
Two lines only:
- today: sessions, total tokens, estimated API-equivalent cost
- 7d: sessions, total tokens, estimated API-equivalent cost

### `stats`
- overview table with periods as columns and metrics as rows
- daily activity breakdown for a focused period (default 30d)
- model breakdown for the focused period
- cost coverage / pricing basis notes

Metrics:
- sessions
- active days
- total tokens
- input tokens
- cached input tokens
- output tokens
- reasoning output tokens
- estimated API-equivalent cost

## Cost estimation
Use the official pricing docs page and cache parsed rates for 24 hours.
- Exact model match when available
- Unknown-model sessions use fallback pricing from the latest flagship model (`gpt-5.4`)
- Cached input is treated as a subset of input tokens
- Reasoning output is treated as informational and priced within output tokens, not added twice
- Wording must explicitly say “estimated API-equivalent cost”

## Output style
Reuse the existing CLI’s restrained colorized terminal style:
- aligned tables
- colored headers
- dim explanatory notes
- no heavy ASCII chrome

## Testing
Add smoke coverage for:
- help/completion/docs version updates
- list footer summary
- default `stats` output
- period focusing and all-time labeling/capping behavior
- pricing cache / local fixture loading and fallback-model wording
