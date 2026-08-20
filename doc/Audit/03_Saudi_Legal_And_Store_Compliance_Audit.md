---
type: audit
project: Streamer_app
phase: 3 of 8
created: 2026-08-20
status: complete
---

# 🇸🇦 Phase 3 — Saudi Legal & Store Policy Compliance

**Important framing before anything else:** this section covers regulation and platform policy, not engineering. I'm not a lawyer, this isn't legal advice, and Saudi PDPL enforcement details plus CST/media-licensing specifics change and carry real penalties — before you submit to either store, get this section (especially 1.2 and 1.3) checked by a Saudi lawyer or a local compliance consultant who can read the current Arabic-language regulations directly. What follows is meant to tell you *what to ask them about* and *what's clearly missing from the app today*, not to be the final word.

---

## 1. Saudi Personal Data Protection Law (PDPL) — what applies here

Saudi Arabia's PDPL is enforced by SDAIA (Saudi Data & AI Authority). Based on current public guidance:

- **Explicit consent is required** before collecting or processing personal data, unless another lawful basis applies. The app today has **no consent screen or privacy-notice acceptance step anywhere in onboarding** — `welcome_screen.dart` → `viewer_setup_screen.dart` → `role_select_screen.dart` collect a display name and (for broadcasters) full legal name, phone number, and venue coordinates with no consent capture at any point.
- **Data subject rights** required: access, correction, deletion, and consent withdrawal. The app has **none of these** — no "export my data," no "delete my account," no way to review or correct what was submitted in the broadcaster application after submission besides the (currently missing, see the UX audit) inability to edit prior steps.
- **Cross-border data transfer restrictions** — transfers of personal data outside Saudi Arabia require either regulatory approval or an adequate-protection mechanism. This matters concretely here because: the only "backend" today is `SharedPreferences` (on-device, so no transfer issue by itself), but the **YouTube Data API v3 calls send data to Google's US/global infrastructure**, and if a real backend is built later (Phase 1 flagged this as necessary for security), *where that backend is hosted* becomes a PDPL question worth asking a lawyer before choosing a cloud region.
- **No explicit data-residency mandate** was found in the guidance reviewed, but this is exactly the kind of detail that changes with implementing regulations — confirm current status before architecture decisions on a backend are finalized.

**Concrete gap list for this app specifically:**
1. No consent/privacy-notice acceptance step in onboarding (for both guest viewers and broadcaster applicants).
2. No data subject access/export mechanism.
3. No account/data deletion mechanism (also a store-policy blocker — see §3).
4. Broadcaster applications collect precise home/venue coordinates, full legal name, and phone number and store them in **plaintext** (Phase 1, VULN-AUTH-03) — PDPL's "adequate protection mechanisms" language makes plaintext storage of this specific data category a likely finding if anyone audits it.

Sources: [SDAIA and Saudi PDPL: What Saudi Organizations Must Know in 2026](https://www.sgc.consulting/sdaia-saudi-personal-data-protection-law-pdpl-compliance-guide/), [Saudi Personal Data Protection Law: Compliance Guide 2026](https://www.securelink.sa/blogs/saudi-personal-data-protection-law-compliance-guide-2026/), [Saudi Arabia issues Implementing Regulations to the PDPL](https://www.clydeco.com/en/insights/2023/09/saudi-arabia-issues-implementing-regulations)

---

## 2. Content & platform licensing (CST / GCAM) — needs a direct answer from CST, not just web research

Two Saudi regulators potentially touch a live-streaming education app, and public sources didn't give a clean, current, citable answer on which applies to an app of this shape and size — this is the single item in this whole audit I'd most want a local lawyer or a direct query to CST to resolve before submission, rather than relying on my summary:

- **CST (Communications, Space & Technology Commission, formerly CITC)** implemented regulations for **"digital content platform services"** effective October 8, 2024, described as an "operational license requirement" applying to "local and international digital content platforms, such as social [media] and streaming services." The detail of what triggers this requirement (user count thresholds? revenue? UGC vs. curated content? live vs. VOD?) wasn't available in the sources reachable here — the actual regulation text sits behind further CST documentation.
- **GCAM (General Commission for Audiovisual Media)** separately governs audiovisual/media content and licensing in Saudi Arabia; multiple business-registration-service providers describe an "Audiovisual Media License" as required for platforms that broadcast or distribute video/audio content commercially in KSA.

**What this means practically:** before store submission, get a direct answer (from CST, GCAM, or a Saudi media/tech lawyer) to the question *"does an education-focused live-streaming and VOD app with user-submitted broadcaster applications, based in the Eastern Province, require a CST digital-content-platform registration and/or a GCAM audiovisual media license before public launch?"* This is not a question this audit can safely answer from public search results, and getting it wrong has real regulatory consequences (fines, forced takedown) that a code fix can't undo after the fact.

Sources: [Saudi Arabia: Implemented CST regulations for providing digital content platform services](https://digitalpolicyalert.org/event/23298-implemented-cst-regulations-for-providing-digital-content-platform-services), [CST Regulations & Licenses](https://www.cst.gov.sa/en/regulations-and-licenses), [Audiovisual Media License in Saudi Arabia](https://arnifi.com/blog/audiovisual-media-license-in-saudi-arabia/)

---

## 3. Apple App Store — policy blockers specific to this app's current state

| Requirement | Status in this app | Why it matters |
|---|---|---|
| **Guideline 5.1.1(v) — in-app account deletion.** Required since Jan 31, 2022 for all apps that support account creation. | ❌ **Missing entirely.** No delete-account path anywhere in `settings_screen.dart` or elsewhere. | This alone is enough for an automatic App Review rejection. Non-negotiable, straightforward fix: add an in-app "Delete My Account" flow that removes the locally-stored profile/application data (and, once a backend exists, the server-side record too). |
| **Guideline 4.8 — Login Services.** Apps offering third-party social login (this app only offers Google Sign-In) must also offer an alternative login meeting Apple's privacy bar — in practice this means Sign in with Apple for almost everyone, with narrow exceptions (proprietary-only login, institutional/education accounts, government ID, or being a client for one specific third-party service). | ❌ **Only Google Sign-In + guest mode exist.** No exception category obviously applies (this isn't an institutional-SSO-only app, nor tied to one specific external service by nature). | This is a real, likely rejection reason for the iOS build specifically — the Android build isn't affected by this Apple-only rule. Needs adding "Sign in with Apple" alongside Google Sign-In before iOS submission (Phase 7 territory, but flagging the requirement here since it's a store-policy item, not a build-config item). |
| **Guideline 1.2 — User-Generated Content / Safety.** Apps with live chat, live streaming, or UGC must implement moderation, reporting, and blocking, and be able to demonstrate this to reviewers. | ❌ **`live_chat_widget.dart` has no report-message, block-user, mute, or delete-message affordance for viewers or streamers** — confirmed by reading the chat widget; the only moderation-flavored feature that exists is `AdminHubScreen`'s broadcaster *application* verification queue, which is a completely different thing (it moderates who's allowed to stream, not what gets said in a live chat while streaming). | Live text chat between unauthenticated guest viewers and broadcasters, with zero in-the-moment moderation tooling, is exactly the shape of app this guideline targets. This is likely to draw a manual review hold or rejection with a request to "add moderation tools" — worth fixing proactively rather than finding out from a rejection email. |
| **Privacy Nutrition Label / App Privacy questions** | Not yet completable accurately — depends on finishing Phase 1's data-handling fixes first (can't honestly declare "data is protected in transit" while cleartext traffic is enabled) | Sequencing note for Phase 8: this should be filled in *after* the Phase 1 security fixes land, not before, or it'll need to be redone. |
| **`PrivacyInfo.xcprivacy` (Privacy Manifest)** | N/A yet — no iOS project exists | Covered in Phase 2/7; flagging here as it's also an App Review gate, not just a build step. |

---

## 4. Google Play Store — policy blockers specific to this app's current state

| Requirement | Status | Why it matters |
|---|---|---|
| **Account deletion (in-app path + web link), required since May 31, 2024** | ❌ **Missing.** Same gap as the Apple side — no in-app deletion, and (naturally) no web-based deletion-request page either. | Non-compliant apps face removal from Google Play. Needs both the in-app flow *and* a simple hosted page (even a static one) users can reach without the app installed, per Google's requirement that the web path work "without requiring reinstall." |
| **Data Safety section accuracy** | Not yet accurately completable — same sequencing note as Apple: fill this in after Phase 1 fixes (in-transit encryption claim) and after the account-deletion flow exists (there's a specific "does your app support account/data deletion" question in this exact form) | — |
| **Google Play pre-launch report / automated security scan** | Will very likely flag `usesCleartextTraffic="true"` and the hardcoded API key automatically, independent of manual review | Additional forcing function to land the Phase 1 fixes before submission, not just for security's own sake but because the automated scan will surface them regardless. |
| **Content rating questionnaire** | Not yet assessed — live chat with strangers typically pushes a content rating up a tier (e.g., from "Everyone" toward "Teen") in both Play's IARC questionnaire and Apple's age rating, *especially* absent the moderation tooling flagged in §3. Worth re-running the rating questionnaire honestly once moderation tools are added, since the answer may change the result. | — |

---

## 5. Cross-cutting: what to actually go build, in rough priority order

1. **In-app account/data deletion** — same fix serves PDPL (§1), Apple (§3), and Google (§4) simultaneously. Highest leverage single feature to add.
2. **Consent/privacy-notice step in onboarding** — serves PDPL directly and gives you a clean place to also link the Terms & Conditions that `Core_files/STATUS.md` says already exist as a governance viewer.
3. **Basic live-chat moderation** (report message, block/mute user, and ideally a profanity/keyword filter given the educational/family audience) — serves Apple 1.2 directly and is generally good practice for a platform serving students.
4. **Get a direct, current answer from CST/GCAM or a local lawyer on the licensing question in §2** before submission — this is the one item here that can't be resolved by writing code.
5. **Sign in with Apple**, scoped specifically to the iOS build (Phase 7).
6. Encrypt PII at rest (ties back to Phase 1, also strengthens the PDPL story).

None of this blocks continuing the other audit phases — it's meant to feed Phase 8's final go/no-go checklist, where all four phases' findings get merged into one prioritized list.
