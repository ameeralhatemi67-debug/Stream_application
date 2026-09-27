# Independent integration critic

Maximum three formal integration cycles. Source-branch historical reviews remain unchanged. The independent critic inspected actual combined source and evidence; preliminary streaming triage was not a scored cycle.

## Cycle 1 — NEEDS WORK

Reviewed `c70058914b73ccd5a8cfc1bcd82606fc3e4f880a` against master `7b54cb5`, streaming `818cc12`, map `74157ba`. Scores: functionality **7**, accessibility/platform compatibility **8**, integration/connectivity **7**, ease of use **8**. Four confirmed P2 findings:

1. Initial page claimed after worker installation has no durable build pin; Save then offline asset requests can fail.
2. Another tab can prune a reserved navigation client before it commits.
3. Organization catalog reload invents Khobar/26.2871,50.2125; application location did not persist through reload.
4. Four existing wizard choices (Ahsa/Jubail/Riyadh/Other) failed the new three-city DB constraint.

No new critical/high implementation defect was found. D8 remains the pre-existing HIGH release blocker. The target was not met; scores were provisional for physical/backend behavior. The critic inspected the actual Arabic offline map screenshot, which does not establish selected-card interaction. Full Flutter JIT OOM is not PASS. Native 9.91fps and System UI ANR remain unexplained; available traces cannot prove an app cause or emulator-only limitation.

Repairs for next review: commit `7cab6d0023a588f23b425249df6171822c6b59ea`. Page build handshake with acknowledgement before Save; recent reserved-client grace; seven application city values; approved public organization application link guarded by same applicant/type/approved status. Private organization branches remain private and unchanged. New tests exercise worker failure reproductions, application/catalog mapping, all city constraints and public-view privacy. Fresh results for these repairs are recorded in VERIFICATION; original failing logs remain.

Additional verified source before cycle 2:12f081d worker-upgrade handshake,1ec9a04 absent organization directions plus test isolation,34d074a adversarial privacy assertions. App source frozen at34d074a.

## Cycle 2 — TARGET MET; physical acceptance still open

Reviewed source **`34d074a5c577cd35944813f0a3db5315f4c85e96`**, including repairs `7cab6d0`, `12f081d`, `1ec9a04` and `34d074a`. The independent critic inspected the combined diff and final evidence, independently reran the actual worker/page checks and checked every full-suite log, artifact hash, source tree, APK identity/callback/signing and configuration hash. No application, SQL or build-script change followed this review.

All four cycle-1 P2 causes are closed: first-page identity before Save; reserved-client survival during concurrent cleanup within the documented five-minute grace; exact approved organization public location with owner/type/status guards; and persistence of every offered city while the map remains limited to three cities. **No unresolved new critical/high implementation defect found. D8 remains the explicit pre-existing HIGH release blocker.**

| Category | Final score | Concrete reason below 10 / evidence | Next action |
|---|---:|---|---|
| Functionality | **8/10** | Physical outgoing/received geometry and continuity unverified; inherited 9.91 fps and System UI ANR unexplained. Audio-only camera release and accurate outlines unmet. Geometry/widget/browser evidence supports implementation only. | S01/S07/S08 on both phones; resolve M07 licensed geometry/scope. |
| Accessibility / supported-platform compatibility | **8/10** | 72 populated-card combinations and short End regressions pass; actual phone keyboard prevention, TalkBack, large text and other supported-platform behavior unverified. | W03/W04 and A01/A02 on both physical models. |
| Integration / connectivity | **8/10** | Fresh SQL/concurrency and real old/new Chrome builds pass; configured Google/YouTube and multi-device End/recovery/transfer/revocation untested. D8 remains HIGH. | Authorized W00 setup, then S03/S04/C06/I02; D8 remains separate release work. |
| Ease of use | **8/10** | Tested actions reachable and absent locations truthful; smoke stop rules clear. Diagnostic artifact requires configuration/rebuild and actual phone usability remains unverified. | Complete W00–W06 before longer acceptance. |

**All four scores are provisional for physical/backend acceptance.** The source-review numerical target is met; scores do not establish P5/P6/P6S acceptance or release readiness. Stop at cycle 2. Two of the maximum three integration reviews were used; no third cycle was needed and old source-branch histories were not changed.

Evidence assessed: **847 Flutter tests** across eight final disjoint shards (110,110,99,119,99,109,100,101); analyzer 0; gates 0 failures; disposable SQL 23 files/462 assertions plus 3 concurrency cases; actual-source worker/page checks independently PASS; final Chrome 52/52 files, distinct actual old/new app hashes, safe publication fault, empty settled locks, cold Arabic rendering and 4,072 ms hanging fallback. APK/web artifact hashes and actual APK package/label/version/callback/certificate match [identity.json](identity.json). Three diagrams render; 36 cases match all 144 NOT RUN cells. Exact logs/limits are in [VERIFICATION](VERIFICATION.md).

The critic explicitly advised against merging into the current dirty master because protected owner documentation overlaps incoming changes. The final closure consists only of evidence/documentation and preservation/link checks. P5/map **NOT ACCEPTED**; P6 **NOT ACCEPTED**; P6S **INCOMPLETE / NOT ACCEPTED**.
