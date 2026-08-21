# 🏛️ Document Vault & Archive

> **Status:** Archived / Historical Reference  
> **Active Sources of Truth:** `doc/Audit/` and `doc/Roadmap/`

---

## 📌 Purpose of this Directory

This directory contains early planning documents, initial feature brainstorming notes, and preliminary audit reports created during earlier phases of development. 

All actionable items, security findings, UX recommendations, and milestone goals from these files have been **consolidated, reconciled, and superseded** by:
1. **`doc/Audit/`** — The 8-phase Publishing Readiness Audit (comprehensive security, legal, permissions, feature inventory, and store compliance checklist).
2. **`doc/Roadmap/`** — The structured Master Roadmap (`v0.5` through `v1.1`), detailing phase-by-phase execution from backend migration to store submission.

---

## 🗂️ Archived Documents

| File | Original Purpose | Replaced / Superseded By |
|---|---|---|
| `roadmap to publishing.md` | Initial high-level 8-phase publishing draft | `doc/Roadmap/00_Roadmap_Overview.md` |
| `roadmap_admin_hub_and_broadcaster_auth.md` | Early Admin & Broadcaster plan | `doc/Roadmap/v0.5_Backend_Foundation.md` & `v0.8_Admin_Upgrade.md` |
| `technical_specs_admin_hub_and_governance.md` | Early Admin Hub technical specification | `doc/Roadmap/v0.8_Admin_Upgrade.md` & `supabase/migrations/` |
| `Security, Vulnerability & Platform Hardening Audit.md` | First security pass (Aug 18, 2026) | `doc/Audit/01_Security_Data_Protection_Audit.md` |
| `User Flow & UX Ergonomics Comprehensive Audit.md` | Initial UX heuristic analysis | `doc/Audit/06a_Admin_Side_Audit.md` – `06d_Viewer_Side_Audit.md` |
| `Performance, Rendering & Resource Optimization Report.md` | Initial performance profiling report | `doc/Audit/05_Performance_Optimization_Audit.md` |
| `fix bug list.md` | Legacy bug backlog | `doc/Audit/04_Missing_Incomplete_Features_Inventory.md` |
| `new feature list.md` | Legacy feature wishlist | `doc/Audit/04_Missing_Incomplete_Features_Inventory.md` & Roadmap |
| `Organization_featrue_brainStorming.md` | Initial organization architecture ideas | `doc/Audit/06c_Organization_Side_Audit.md` & DB migrations |
| `Notifications.md` | Brainstorming on push notifications | Integrated into Roadmap v0.6/v1.0 |
| `more thing to add.md` | Scratch notes | Integrated into Roadmap & Audit |

---

> [!NOTE]
> AI agents (like Claude Code) should refer to `doc/Roadmap/` and `doc/Audit/` as the active authorities. Consult files in `Vault/` only when historical context on specific legacy decisions is needed.
