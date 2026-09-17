# On-brand output — the shared methodology

**Optional guidance, not a mandate — no skill is required to produce a report or
document.** But *when* a skill or a user needs to generate a **presentation artifact
the skill itself renders** — a report, a PDF, an HTML page or email, a dashboard or
slide — keep it on-brand with the Sysdig **report engine** and **brand kit** (MCP tools
on `secure-mcp-server`) instead of hand-crafting styling. This file is the shared source
of truth; skills link to it rather than restating it.

> **Scope.** This applies only to presentation artifacts a skill renders itself. It does
> **not** apply to:
> - Structured artifacts rendered by their own systems — **Jira tickets, pull requests**,
>   and the like (their host controls the styling).
> - Chat replies, logs, scratch, or other intermediate output.

> **Your own `allowed-tools` decide which path you can walk.** A skill carries this
> methodology, but not necessarily the tools for every path in it. Before you start,
> check that the path's tools are listed in *this* skill's frontmatter. If they aren't:
> hand the deliverable to the `sysdig-report` skill when that skill is installed, or say
> plainly that this skill can't render it. Never call a tool the skill doesn't list — the
> call is denied and the flow dies mid-way.

## The rule: when you do produce such an artifact, pick the path by what it is

| The artifact is… | Path | Guarantee |
|---|---|---|
| A **report / PDF** | **A · Governed** | The engine renders it → **guaranteed** on-brand; off-brand output is impossible. |
| **HTML / an email / a slide / a chart you render yourself** | **B · Brand kit** | You apply the tokens + `brand.css` → **advisory** (as on-brand as you make it). |
| A report **about a remediation Plan**, kept in Sysdig | **C · Plan report** | The server builds, renders **and stores** it → guaranteed on-brand, and it persists as a plan artifact. |

Prefer **Path A** whenever the artifact can be a report/PDF — it removes the styling
burden from the skill entirely. Use **Path C** instead when the subject *is* a Plan and
the report should live in Sysdig.

## Path A · Governed (author a Document → validate → render)

The engine turns a semantic **`Document`** (presentation-free blocks) into a branded
PDF. The skill only ever produces or edits the `Document`.

1. `get_report_grammar` — load the **live** authoring grammar (source of truth; don't author from memory). `get_report_schema` for exact field names/enums.
2. Author the `Document` (chrome + ordered content blocks). Content only.
3. `validate_report` — returns `{ valid, errors }` with **JSON-Pointer** error paths; fix and re-validate until clean.
4. `render_report` — returns the branded PDF as an `application/pdf` embedded resource. Hand it to the user; don't transcode it. `render_report` is **stateless**: it renders and stores nothing, so the resource it returns is the only copy. (Persisting a report inside Sysdig is Path C's job.)

## Path B · Brand kit (render it yourself, on-brand)

For content the engine can't render, fetch the brand assets and apply them.

1. `get_brand_kit` — one Markdown doc: token reference + a ready-to-use **`brand.css`** + usage. Paste `brand.css` into a `<style>` for HTML/email.
2. `get_design_tokens` — raw W3C DTCG tokens for programmatic use: neutral palette, the semantic **severity scale**, the positional **chart palette** (color series by index), fonts, spacing, radii, the type scale.
3. Apply, don't invent — color findings by severity, series by chart index; use the token fonts/spacing. Never hand-pick hex, fonts, or margins.

## Path C · Plan report (server-built, persisted)

Only for a report **about a remediation Plan** — `sysdig-investigate` owns this path. The
server assembles the `Document` from plan data, so there is nothing to author.

1. `get_plan_report_options(plan_id)` — the presets, components, and time ranges available for this plan.
2. `get_plan_report_data(plan_id, preset=…, time_range=…)` — build it; show the returned **outline** (block titles / types) to confirm scope before saving.
3. `save_plan_report(plan_id, …)` — validates, renders the branded PDF, **and stores it as a report artifact**. Read the result before announcing success:
   - `saved: true` → hand the user the returned `download_path`. It can be `null` (no artifact id came back); fall back to `source_path`, and if both are null say the report was stored but no link was returned rather than printing `null`.
   - `saved: false` → **not an exception**, a normal result carrying `validation_errors` (JSON-Pointer paths) and a `hint`. Fix those paths and retry; don't report a saved report.

Unlike Path A, this path deliberately persists — that is the point of it. On-brand by
construction; never hand-write the styling.

**It also writes.** Steps 1–2 only read the plan, but step 3 stores an artifact, so it
needs plan **write** access where the first two need read. A read-only identity gets
through the outline and then fails on save — if that happens, say the user lacks
permission to store a report on this plan and offer the outline instead.

## Tool catalog (`secure-mcp-server`)

| Tool | Path | Purpose |
|---|---|---|
| `get_report_grammar` | A | Live authoring grammar for a `Document` |
| `get_report_schema` | A | JSON Schema for a `Document` |
| `validate_report` | A | Validate a `Document` → `{ valid, errors }` (JSON-Pointer) |
| `render_report` | A | Render a `Document` → branded PDF (base64 resource) |
| `get_brand_kit` | B | Tokens + `brand.css` + usage (Markdown) |
| `get_design_tokens` | B | Raw design tokens (W3C DTCG JSON) |
| `get_plan_report_options` | C | Presets / components / time ranges for a Plan |
| `get_plan_report_data` | C | Build a Plan report → outline + data |
| `save_plan_report` | C | Validate + render + **store** a Plan report artifact |

## Invariants (all paths)

- **Presentation is engine-owned.** No hand-picked colors, fonts, sizes, or margins in any deliverable. Color is only ever a semantic severity name or a positional palette index.
- **Validate before you render** (Path A). Never render an unvalidated `Document`.
- **The engine's output is the source of truth** — don't reformat or "touch up" a returned PDF.
- **Auth is the MCP session** — never read, write, or display credentials.
- **Nothing to entitle-check for A and B.** Those tools are open to any authenticated Sysdig identity — no license tier or feature flag to probe first. (A region whose backend predates the engine answers `404`; that's a deployment gap, not a permission one.) **Path C is different**: it touches tenant data, so its reads need Plans read access and `save_plan_report` needs Plans **write** access. A `403` there is a real permission answer, not a deployment gap — don't retry it.

## For the full governed/brand-kit workflow

Everything you need is above — Paths A, B, and C are fully specified here. If the
`sysdig-report` skill is installed, it implements Paths A and B end-to-end (decision
rule, the author → validate → render loop, brand-kit examples) and a report/PDF
deliverable can be handed off to it. If it isn't installed, don't point the user at it —
follow the path here whose tools this skill actually lists.
