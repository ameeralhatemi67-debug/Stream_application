# Skill Observation Log

Observations captured during task-oriented work.

**Status key:** OPEN = not yet actioned | ACTIONED (YYYY-MM-DD) = skill updated/created | DECLINED (YYYY-MM-DD) = user decided not to pursue

---

## 2026-09-21

### Observation 1: Reconcile roadmap claims against the latest resume block

**Status:** OPEN
**Date:** 2026-09-21
**Session context:** Updated a project roadmap from a long-running hardening ledger and pasted agent summaries.
**Skill:** Existing task-observer workflow
**Type:** open-source
**Phase/Area:** Documentation reconciliation

**Issue:** Historical roadmap entries and pasted summaries contained different test counts and phase boundaries. The latest ledger RESUME block was the reliable source for current status.

**Suggested improvement:** When updating a roadmap after an agent handoff, identify the latest resume/checkpoint block first, then use older entries only for history.

**Principle:** Current status should come from the newest evidence checkpoint, while historical notes should preserve chronology without overriding it.

### Observation 2: Reconcile roadmap charts with status evidence

**Status:** OPEN
**Date:** 2026-09-22
**Session context:** Reconciled a phase roadmap after an independent audit found that the status table and Gantt chart described different execution orders.
**Skill:** Existing task-observer workflow
**Type:** open-source
**Phase/Area:** Documentation reconciliation

**Issue:** Updating task checkboxes without checking dependency charts can leave a roadmap internally inconsistent. A phase may be marked complete in the evidence while the Gantt still places it after later work.

**Suggested improvement:** Treat status tables, task checkboxes and Gantt dependencies as one reconciliation unit. After updating checkboxes, scan the chart for stale `after` dependencies and mark partial evidence explicitly.

**Principle:** A project roadmap is consistent only when its task status, evidence summary and dependency chart agree.

### Observation 3: Use a URL-aware browser connection for Flutter web checks

**Status:** OPEN
**Date:** 2026-09-22
**Session context:** Local Flutter browser and emulator verification.
**Skill:** computer-use
**Type:** open-source
**Phase/Area:** Browser selection

**Issue:** Native Windows browser inspection stopped because the tool could not verify the current URL. A later user-authorized turn could inspect the same local app through the browser connector, which exposes the URL directly. Flutter accessibility then needed explicit activation before semantic controls appeared.

**Suggested improvement:** Prefer a URL-aware browser connector for web app testing. If it is unavailable, keep the policy block explicit and continue independent authorized engineering work. Separate native Chrome launch evidence from in-app browser interaction evidence.

**Principle:** Verification reports must identify both the runtime and the interface actually used to observe it.

### Observation 4: Validate usage-window duration before trusting a budget status

**Status:** OPEN
**Date:** 2026-09-23
**Session context:** A coding preflight exposed a weekly-only usage window mislabeled as five-hour by a local meter.
**Skill:** task-observer
**Type:** open-source
**Phase/Area:** Budget preflight

**Issue:** A fresh parser result said OK while its assumed window duration contradicted the provider's explicit metadata. Freshness alone did not establish a valid budget reading.
**Suggested improvement:** Compare window duration and percent units with the authoritative provider response before accepting any budget status. Reject mismatches and obtain authorization before changing protected budget rules.
**Principle:** Validate a measurement's units and scope as well as its age.
