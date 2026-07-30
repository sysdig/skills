# Log Source Customization — EventBridge "Select Sources" (AWS)

How to mirror the Sysdig AWS UI's **"Select Sources" (optional)** step of
EventBridge Log Ingestion setup. **Load this only when the user asks to
customize which log sources are forwarded** — the default path does not need it.

**Scope:** AWS, EventBridge capture method only. The UI shows "Select Sources"
only under EventBridge (not the S3/CloudTrail capture method), and only when
Threat Detection and/or Advanced CIEM (Cloud Logs) are being enabled. Skip
entirely for GCP/Azure and for the S3/CloudTrail capture method.

---

## The three tiers (UI parity)

The UI presents three radio options:

| UI option | What we generate |
|---|---|
| **Default Setup** (preselected, recommended) | **Omit `event_pattern`** — the module's built-in default forwards all sources required by Advanced CIEM + Threat Detection. |
| **Guided Customization** | An explicit `event_pattern` built from the selected source checkboxes (algorithm below). |
| **Advanced Customization** | A fully custom `event_pattern` the user supplies verbatim (pass-through). |

**Default is the recommended path.** Only generate an `event_pattern` when the
user actively chooses to trim sources. If the user keeps every **non-Insight**
source enabled, treat it as Default and omit `event_pattern` (cleaner config).

**Important — Default does not capture Insights.** The module's built-in default
`event_pattern` (and the UI's "Guided + everything checked" output) contains only
`AWS API Call via CloudTrail` for CloudTrail — it has **no `AWS Insight via
CloudTrail` match**, so real Insight events are not forwarded by the default
pattern. Therefore, if the user wants Insights, we must **not** omit
`event_pattern`; emit an explicit pattern that includes the Insight branch
(below).

---

## Interview sub-step (only when customizing)

This file is loaded only when the user has **asked to trim log sources** — it is
not raised proactively (see SKILL.md / interview-questions.md). When that
happens, in EventBridge mode and after the Cloud Logs region question
(interview-questions.md Step 3d-ii), show this gateway. Its "All sources" option
is the **escape hatch** if the user changes their mind and wants the default:

```json
{
  "question": "EventBridge forwards all log sources by default (recommended). Customize which sources are forwarded?",
  "header": "Log sources",
  "multiSelect": false,
  "options": [
    {"label": "All sources (recommended)", "description": "Default Setup — forward everything Advanced CIEM and Threat Detection need"},
    {"label": "Customize sources", "description": "Pick which CloudTrail / sign-in / S3 / GuardDuty sources to forward (trims log volume/cost)"},
    {"label": "Advanced — custom pattern", "description": "Provide your own EventBridge event pattern"}
  ]
}
```

- **All sources** → **delete** the `{{EVENT_BRIDGE_EVENT_PATTERN}}` line and its
  comment block from the template entirely (Default Setup). Do **not** leave the
  `{{…}}` token and do **not** emit an empty `event_pattern = ""`. Done.
- **Advanced** → ask the user for their raw EventBridge event pattern JSON and
  emit it verbatim inside the `event_pattern` heredoc. Done.
- **Customize sources** → present the source picker below, then build the
  pattern with the algorithm.

### Source picker (Guided Customization)

Mirror the UI's nested checkbox tree:

```json
{
  "question": "Which log sources should EventBridge forward?",
  "header": "Sources",
  "multiSelect": true,
  "options": [
    {"label": "CloudTrail — Management", "description": "Management events (control-plane API calls)"},
    {"label": "CloudTrail — Data", "description": "Data events (e.g. S3 object-level, Lambda invoke)"},
    {"label": "CloudTrail — Insights", "description": "CloudTrail Insights events"},
    {"label": "Console Sign In", "description": "AWS console sign-in events"},
    {"label": "Service Event", "description": "AWS service events"},
    {"label": "Object events (S3 notifications)", "description": "S3 object notifications"},
    {"label": "GuardDuty Findings", "description": "GuardDuty findings"}
  ]
}
```

Recommend keeping **CloudTrail — Management** at minimum — Advanced CIEM and
Threat Detection rely on CloudTrail management events. If the user selects only
**Data** and/or **Object events** without Management, warn them it may forward
nothing unless data-event logging is separately enabled (see the Data caveat
below). (`NetworkActivity`, a fourth CloudTrail eventCategory, is intentionally
not offered — it mirrors the UI, which does not expose it.)

---

## Checkbox → event-pattern mapping

The `log_sources` token column is the canonical identifier for autonomous mode
(see [autonomous-mode.md](autonomous-mode.md)); the guided picker uses the label.

| Selected source (picker label) | `log_sources` token | Contributes |
|---|---|---|
| CloudTrail — Management | `cloudtrail_management` | `detail-type: "AWS API Call via CloudTrail"` + `eventCategory: "Management"` |
| CloudTrail — Data | `cloudtrail_data` | `detail-type: "AWS API Call via CloudTrail"` + `eventCategory: "Data"` |
| CloudTrail — Insights | `cloudtrail_insights` | `eventCategory: "Insight"` **only** — matched independently, **not** pinned to a detail-type (see note) |
| Console Sign In | `console_signin` | `detail-type: "AWS Console Sign In via CloudTrail"` |
| Service Event | `service_event` | `detail-type: "AWS Service Event via CloudTrail"` |
| Object events (S3) | `object_events` | the 10 `Object …` detail-types (see below) |
| GuardDuty Findings | `guardduty` | `detail-type: "GuardDuty Finding"` |

> **eventCategory values:** `Management` and `Data` are categories of
> `AWS API Call via CloudTrail` events, so they are matched as
> `detail-type: "AWS API Call via CloudTrail"` + `eventCategory`.
> **Insights are different:** a CloudTrail Insights event is delivered with
> `detail-type: "AWS Insight via CloudTrail"` and `eventCategory: "Insight"`
> (**singular**). It is therefore matched by **`eventCategory: ["Insight"]` alone**,
> in a branch that does **not** constrain `detail-type` — pinning it to
> `AWS API Call via CloudTrail` would exclude it.

> **`CloudTrail — Data` caveat:** a `Data` eventCategory branch is valid, but it
> only forwards events if the account/trail is actually delivering CloudTrail
> **data events** to EventBridge (data events have separate logging
> prerequisites). With the module's default management-only setup, this branch
> may match nothing.

> **`CloudTrail — Insights` caveat:** Insights is a niche source. The branch is
> EventBridge-correct, but forwarding Insight events does not by itself guarantee
> they surface in Sysdig end-to-end. Treat it as best-effort: after enabling,
> confirm Insight events actually appear in Sysdig, and omit it if not needed.

The 10 **Object events** detail-types (emit exactly these, as in Example A):

```
"Object Access Tier Changed", "Object ACL Updated", "Object Created",
"Object Deleted", "Object Restore Completed", "Object Restore Expired",
"Object Restore Initiated", "Object Storage Class Changed",
"Object Tags Added", "Object Tags Deleted"
```

---

## Generation algorithm

Selecting **"All sources (recommended)"** → omit `event_pattern` (Default Setup).
The steps below apply when the user **customizes** sources. Note Default Setup
does **not** include Insights — if the user wants Insights, they must customize
and tick it (we always emit an explicit pattern then).

Split the selections into:

- `api_cats` = selected ⊆ {Management, Data} (Insights is **not** here)
- `insights` = whether CloudTrail Insights is selected
- `plain` = detail-type strings from Console Sign In, Service Event, Object
  events (the 10), GuardDuty

If the user picked "Customize sources" but selected **nothing** (all three sets
empty), treat it as Default Setup — omit `event_pattern` (or re-prompt). Never
emit an empty pattern.

Build branches:

1. **API Call branch** — only if `api_cats` is non-empty:
   - both Management and Data → `{ "detail-type": ["AWS API Call via CloudTrail"] }` (no `eventCategory` — a *detail-type-only* branch)
   - exactly one → `{ "detail-type": ["AWS API Call via CloudTrail"], "detail": { "eventCategory": [<the one>] } }`
2. **Insight branch** — only if `insights`:
   `{ "detail": { "eventCategory": ["Insight"] } }`  ← **no `detail-type`** (the
   key fix; pinning the detail-type would exclude real Insight events).
3. **Plain branch** — only if `plain` is non-empty: `{ "detail-type": [<plain…>] }`

**Merge step:** collapse every *detail-type-only* branch (no `detail` key — i.e.
the both-Management-and-Data API Call branch and the Plain branch) into a
**single** `{ "detail-type": [<all their types…>] }`. Branches that carry a
`detail` constraint (the single-category API Call branch and the Insight branch)
stay separate. This is what makes the "all non-Insight sources" case collapse to
the flat list in example A rather than a redundant `$or`. Order within any
`detail-type` array is **not significant** — EventBridge treats it as a set, so
the examples' ordering is illustrative, not required.

Combine the resulting branches:

- One branch → emit it flat (just that object, no `$or`).
- More than one → wrap in `{ "$or": [ <branches…> ] }`.

Resolve `{{EVENT_BRIDGE_EVENT_PATTERN}}` to an `event_pattern = <<-EOF … EOF`
block holding the JSON. Use the **indented** heredoc form (`<<-EOF`, not `<<EOF`)
so the closing `EOF` can sit at the module's indentation. Indent every body line
at least as far as the closing `EOF`; Terraform's `<<-` strips the common leading
indentation, and any remaining whitespace is ignored by JSON — so it's cosmetic:

```
  event_pattern = <<-EOF
  <the JSON above>
  EOF
```

Fully-rendered — Example B placed in the `event-bridge` module exactly as it
should land in the template:

```hcl
module "event-bridge" {
  source                   = "sysdiglabs/secure/aws//modules/integrations/event-bridge"
  version                  = "~> 5.0"
  sysdig_secure_account_id = module.onboarding.sysdig_secure_account_id
  regions                  = ["us-east-1"]

  event_pattern = <<-EOF
  {
    "$or": [
      {
        "detail-type": ["AWS API Call via CloudTrail"],
        "detail": { "eventCategory": ["Management"] }
      },
      {
        "detail-type": [
          "AWS Console Sign In via CloudTrail",
          "AWS Service Event via CloudTrail"
        ]
      }
    ]
  }
  EOF
}
```

---

## Examples

**A. All non-Insight sources** (= Default Setup content; prefer omitting
`event_pattern`) — flat `detail-type` list, no `detail`:

```json
{
  "detail-type": [
    "AWS Console Sign In via CloudTrail",
    "AWS Service Event via CloudTrail",
    "Object Access Tier Changed",
    "Object ACL Updated",
    "Object Created",
    "Object Deleted",
    "Object Restore Completed",
    "Object Restore Expired",
    "Object Restore Initiated",
    "Object Storage Class Changed",
    "Object Tags Added",
    "Object Tags Deleted",
    "GuardDuty Finding",
    "AWS API Call via CloudTrail"
  ]
}
```

> Default Setup does **not** capture Insights — its pattern has no
> `AWS Insight via CloudTrail` match / Insight branch. Add the Insight branch
> (Examples C/D) only when the user explicitly selects Insights.

**B. CloudTrail Management only + Console Sign In + Service Event** — `$or` of an
API-Call/eventCategory branch and a plain detail-type branch:

```json
{
  "$or": [
    {
      "detail-type": ["AWS API Call via CloudTrail"],
      "detail": { "eventCategory": ["Management"] }
    },
    {
      "detail-type": [
        "AWS Console Sign In via CloudTrail",
        "AWS Service Event via CloudTrail"
      ]
    }
  ]
}
```

**C. CloudTrail Insights only** — single branch, `eventCategory` alone, **no
detail-type** (returns `true` against a real Insight event):

```json
{
  "detail": { "eventCategory": ["Insight"] }
}
```

**D. CloudTrail Management + Insights** — `$or` with the Insight branch kept
separate (un-pinned) from the API-Call branch:

```json
{
  "$or": [
    {
      "detail-type": ["AWS API Call via CloudTrail"],
      "detail": { "eventCategory": ["Management"] }
    },
    {
      "detail": { "eventCategory": ["Insight"] }
    }
  ]
}
```

---

## Offboarding note (Advanced CIEM → Basic)

When disabling Log Ingestion / downgrading Advanced CIEM back to Basic, removing
the advanced `identity_entitlement` resource reverts `CIEM_FEATURE_MODE` to
`basic` but leaves the EventBridge webhook component referenced in the
`FEATURE_SECURE_IDENTITY_ENTITLEMENT` feature's `components`. Because the Basic
CIEM resource normally sets `lifecycle { ignore_changes = [flags, components] }`,
Terraform won't reset `components`, and the webhook component then **fails to
delete** (still in use). To fully offboard, also reset the feature's
`components` to the posture component only (temporarily drop `components` from
`ignore_changes`, apply, then the webhook component deletes).
