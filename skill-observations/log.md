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

2026-09-23 Admin Hub deliverable checkpoint: no new skill observation. Existing observation 3 covers the URL-aware browser and Flutter accessibility workflow.

### Observation 5: Separate an initial data snapshot from Realtime subscription readiness

**Status:** OPEN
**Date:** 2026-09-23
**Session context:** A local two-session acceptance probe initially missed a transfer event, then passed after the existing channel joined.
**Skill:** New candidate for a reusable realtime verification workflow
**Type:** open-source
**Phase/Area:** Runtime verification

**Issue:** A stream API can emit an HTTP snapshot before its event channel is subscribed. Treating the snapshot as readiness can misclassify a startup timing window as a missing publication or listener.

**Suggested improvement:** Verify snapshot readiness and channel subscription separately; test a mutation after join, then test the startup window and documented fallback without adding duplicate listeners.

**Principle:** A successful initial read does not establish readiness to receive subsequent events.

### Observation 6: Match each acceptance claim to the captured media

**Status:** OPEN
**Date:** 2026-09-24
**Session context:** Reviewed owner-run physical broadcast results and attached screenshots against release gates.
**Skill:** New skill candidate: Evidence-to-gate review
**Type:** open-source
**Phase/Area:** Acceptance evidence review

**Issue:** A screenshot attached to a claimed live broadcast showed an unrelated prerecorded video. The narrative also reported chat delivery, while the image showed an empty chat. The owner observation remained useful, but the image could not prove those two subchecks.

**Suggested improvement:** For each gate, record the exact artifact and what it visibly or measurably proves. Compare stream identifiers across sender, ingest dashboard and viewer. Keep owner observation and automated evidence separate, and mark unmatched media claims unverified.

**Principle:** Evidence proves only the state it directly captures; related end-to-end claims need matching identifiers across clients.
**Reference file:** brief/evidence/2026-09-24/p6-wave3-review.md

### Observation 7: Keep independent task states across manager handoffs

**Status:** OPEN
**Date:** 2026-09-27
**Session context:** Owner requested persistent coordination records while implementation, integration and physical testing ran on different timelines.
**Skill:** New skill candidate: Concurrent project coordination
**Type:** open-source
**Phase/Area:** Handoffs and dependency tracking

**Issue:** A manager relying on conversational order can treat one returned task as completion of unrelated running work, duplicate an assignment or send a tester to an obsolete build.

**Suggested improvement:** Maintain stable task IDs with prompt/dispatch/response provenance, branch and build identity, execution/review/merge/acceptance states, dependencies and observed timestamps. Update only tasks supported by new evidence. Record manager-owned concurrent documentation changes so preservation checks do not erase them.

**Principle:** Completion is scoped to a task and artifact; it does not propagate to parallel work or dependent acceptance without evidence.

### Observation 8: Verify publication and client commitment separately

**Status:** OPEN
**Date:** 2026-09-27
**Skill:** task-observer / reusable offline verification candidate
**Issue:** Download-interruption tests passed while final cache publication, initial page claim and concurrent navigation cleanup still failed. An update can also complete installation after a page has messaged its old controller.
**Suggested improvement:** Probe final publication after all downloads, first-claimed pages, reserved navigation clients, controller replacement, worker restart and real concurrent tabs against actual artifacts. Keep deterministic state fixtures distinct from browser/physical evidence.
**Principle:** Successful download and compilation do not establish a safely published, usable application generation.
