# Separate checkpoint closure

All owner acceptance cells for this candidate start **NOT RUN**. Automated results belong in VERIFICATION and never substitute for the phone/backend/platform acceptance matrix. Scores are source-review assessments, not acceptance.

| Checkpoint | Implemented / independently verified locally | Physically unverified or blocked | Approved deferral / unresolved decision | Acceptance |
|---|---|---|---|---|
| **P5 / map** | Bundled vector pack; retained viewport, real pin selection, selected-card repair, no fabricated directions/distance, three-city catalog filter, app-versioned offline generations and fault handling. Local archive/widget/browser checks documented separately. | SM-S936B first offline start/reboot, TalkBack/large text, actual selected cards, performance/memory with live player, exact coordinates through real application approval. Accurate city outlines absent. | Extra basemap coverage is navigation padding only. Nearby-town venue expansion not accepted. Suitable licensed official geometry not obtained; do not claim none exists globally. | **NOT ACCEPTED** |
| **P6 / chat and admin** | Existing server RLS/moderation/account/device fences retained; fresh disposable SQL and concurrency checks; chat/admin widget regressions. | Two-phone/Chrome chat convergence, persistence, ordinary/admin End propagation, account isolation, flags, actual audit trail, latency and accessibility. | Organization broadcast deferral does not waive unrelated org/admin/chat behavior. Each P6 tool still requires evidence; unavailable tooling is an open requirement. | **NOT ACCEPTED** |
| **P6S / streaming** | Camera geometry/display/capture lifecycle source audit; orientation geometry assertions; bounded authoritative recovery; real player command/intent logic; truthful unavailable controls. | Upright independent received output on both physical phones, duplicate-audio/drop/thermal checks, background/lock behavior, long durations, native sparse-frame/ANR diagnosis, exact Google/YouTube configuration. **D8 HIGH retained release blocker.** | Organization broadcast, upcoming management and return-chip limitations were previously owner-deferred. Front-camera switching explicitly Coming Soon. Local/private/external-phone/direct-laptop/PiP scope is not silently accepted; see below. | **INCOMPLETE / NOT ACCEPTED** |

| P6S decision | Current behavior | Status / next action |
|---|---|---|
| Android direct video | RtmpStream, fixed encoded canvas, device geometry transform, both landscape directions | W02/S01/S07 required on two physical phones; no physical PASS here. |
| Audio-only capture | Video output can be hidden; camera remains active | Camera release requirement remains unmet. Record indicator/resource evidence; requires scoped implementation or explicit owner exclusion, not a new name for video mute. |
| Background survival | Notification/service presence does not prove authorization-safe Home/lock survival | S08 measures actual receiver continuity and release; no unconditional survival promise. |
| YouTube ownership D8 | Fail-closed client watch checks exist, authoritative server ownership is absent | Explicit pre-existing HIGH release blocker; separate server authorization work required. Not downgraded by local SQL or scores. |
| OBS laptop | External encoder, manually configured exact YouTube event | S05 plus independent receivers and ordinary/admin End semantics. App listing End does not claim to stop OBS. |
| External phone / in-app laptop sender | Unavailable controls | No transport acceptance; formal mode scope exclusion still needed. |
| Local Wi-Fi / private internet | Unavailable; YouTube unlisted is not private access control | Separate transport/authorization scope decision. No new OAuth/media architecture in this task. |
| Organization broadcasting / upcoming management | Entry/provider gates; no activation | Explicit owner deferral retained. Negative safety and unrelated org flows still tested in S09/C07. |
| Front camera | Disabled localized Coming Soon; rear stream continues | Explicit owner deferral; negative interruption check remains required. |
| Retained player / return chip / system PiP | Retained in-room media and real controls; return shortcut is not a floating player; PiP unavailable | Preserve owner return-chip deferral. Real PiP/mini acceptance is not established by a shortcut or build. |
| Quality presets | Supported encoded presets are validated; unsupported preparation fails safely | Test supported/unsupported choices, Auto and actual output. Any unresolved 740/720 scope wording is not a fabricated resolution. |

The historical [P6/P6S matrix](../../2026-09-26/p6s-wave4v2/P6_P6S_CLOSURE_MATRIX.md), [map results](../../2026-09-26/p5-tricity-map-upgrade/ACCEPTANCE_RESULTS.md) and [camera evidence](../p6s-camera-landscape/NATIVE_PROBE.md) remain unchanged. New consolidated cases replace duplicate actions, not historical records.
