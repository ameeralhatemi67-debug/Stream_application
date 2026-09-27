# Hadayah camera / landscape test candidate

The requested camera framing, three-control landscape layout, read-only landscape chat/editing, scrolling settings and front-camera Coming Soon changes are implemented on `codex/p6s-wave4v2-repair`. **P6 and P6S remain NOT ACCEPTED.** Physical results are NOT RUN; D8 server-side YouTube authorization remains a HIGH release blocker by owner decision.

1. Read [the testing instructions](WAVE4V2_RETEST_SCRIPT.md). Start with C01–C10 on both phones, then run the linked checkpoint regressions. Use a separate viewer to judge received video, not the sender preview alone.
2. Fill [the fresh results file](WAVE4V2_ACCEPTANCE_RESULTS.md). Record the exact configured build/config hashes and evidence for every device/role; keep failures and missing checks visible.
3. Assess [the separate P6 and P6S matrices](P6_P6S_CLOSURE_MATRIX.md). Camera fixes alone do not close either checkpoint.

## Candidate identity and setup

Source: `ddcb52178e126894e1b456aa06516a3d789cdac0`. Full identities and artifact hashes: [identity.json](identity.json). This branch starts from the preserved master base `7b54cb5e565011c33dcd03351735b7cc45a0926a`; it contains the earlier Wave 4v2 repairs and this follow-up. No merge/push/deployment was performed.

The supplied Android APK and web archive use **local no-key diagnostic configuration**. They cannot complete Google/YouTube acceptance until disposable test OAuth/channel/API/ingest configuration is provisioned and the same source is rebuilt. [Setup and reproduction](HANDOFF.md) links the existing local-only instructions. The APK uses package `sa.hadayah.streamer_app.wave4v2`, label `Streamer Wave4v2`, to protect the installed Hadayah app; Wave 4v2 itself is the test round, not another product. No owner app was replaced.

Artifacts are preserved in `brief/.runtime/camera-landscape/` (ignored by Git): [Android diagnostic APK](../../../.runtime/camera-landscape/hadayah-ddcb521-no-key.apk) and [web archive](../../../.runtime/camera-landscape/hadayah-ddcb521-web-no-key.zip). Their exact hashes are in identity.json. The separate native-probe APK is a debug fixture, not the normal application.

## Evidence and remaining limits

[Verification](VERIFICATION.md) records the final tests and builds. [Repair report](REPAIR_REPORT.md) explains the causes and research. [Native evidence](NATIVE_PROBE.md) shows portrait/full-width landscape transitions and black video when hidden, but also low delivered frame rate and System UI ANR on the emulator. Physical uprightness, smoothness, YouTube reception, real keyboards/TalkBack, Home/lock and long-duration runs remain required.

The three permitted critic rounds were exhausted by the previous candidate, whose final scores were 8/7/7/7. **This changed source has no new independent score.** See [review status](CRITIC_REVIEW.md). Front-camera operation is explicitly deferred by the latest owner request; its unavailable/Coming Soon behavior must still be tested. Other open scope decisions are retained in the closure matrices.

Historical results and all six supplied screenshots are preserved. Main/master, both stashes and 54 protected file hashes are unchanged; see [preservation check](PRESERVATION_CHECK.json). Opus's map checkout/processes were not touched. After any separately authorized integration, rerun analyzer/full tests/gates/builds plus the end/recovery/account/map/player regressions in [HANDOFF](HANDOFF.md).
