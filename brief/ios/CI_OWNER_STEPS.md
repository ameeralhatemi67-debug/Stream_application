# Pre-Mac Codemagic owner steps

Use this only before the Mac is available (D5). When the Mac arrives, skip cloud CI and follow MAC_SETUP.md / Track M. The builder has written configuration, not started a cloud job. No Apple account or paid Apple capability is needed for this unsigned compile gate.

1. The owner pushes the intended master commits to GitHub. The builder never pushes. Keep unrelated work under the owner's normal review/staging process.
2. Sign in to Codemagic, connect only the intended repository and select the YAML configuration. Review the service's current account terms, machine availability and minutes/billing before starting; this document does not promise free capacity.
3. Choose branch master and workflow `ios-compile-check`. It uses a mac_mini_m2 runner, Flutter 3.41.2, the latest stable Xcode image and its default CocoaPods. Do not add code signing, App Store Connect integrations, certificates, profiles, Apple keys or deployment/publishing steps.
4. Start one manual run. No triggering events are configured, so pushing alone does not start a job. The workflow runs from `project/`, records tool versions, resolves packages, analyzes, runs the full test suite and builds iOS release with `--no-codesign`.
5. Keep `dart_define.example.json` as the only define file. Its values are placeholders. Do not upload `dart_define.local.json`, add secrets to YAML, or substitute live credentials just to compile. This job proves buildability only, not a functioning backend or authentication flow.
6. On success, retain the commit SHA, run URL/date, Xcode/SDK/Flutter/CocoaPods versions, analyzer result, full test count and the native build completion with exit 0. An unsigned .app is a compile artifact; it cannot be installed on an iPhone or uploaded as a signed store build. Success supports E2 only, never E2S or E3.
7. On failure, provide the first actual error class with about 150 log lines around it, including the failing command and tool versions. Remove any accidental credentials/authorization URLs before sharing. A generic final exit-65/exit-1 line is insufficient. Do not repeatedly start the same failing build without a new fix.
8. W13 fixes the first error class only, commits it, then the owner pushes and reruns. After the same error class three times or six iterations without a new class, escalate per plan §6. First native suspects are path_provider_foundation / objective_c native assets; the Apple plugin and any later experimental publisher also need real native compilation. Do not remove plugins or suppress warnings.
9. This workflow is viewer-first by default. Do not add an experimental iOS publisher define to a review/submission build. Do not enable Firebase iOS/push or attach paid capabilities to Debug to satisfy the compile gate.

## Evidence handoff

Record only non-secret evidence:

```text
Commit:
Run URL/date:
Flutter / Dart:
Xcode / iOS SDK / CocoaPods:
Analyze:
Full test passed / failed / skipped:
Native build command and exit:
First error class, if any:
Log excerpt location:
```

Configuration syntax verified through Context7 against [Codemagic unsigned Flutter workflow](https://docs.codemagic.io/yaml-quick-start/first-signed-build), [monorepo working_directory](https://docs.codemagic.io/troubleshooting/common-ios-issues), [software versions](https://docs.codemagic.io/codemagic-yaml-cheatsheet.html), [machine type](https://docs.codemagic.io/specs/machine-type) and [manual/automatic triggers](https://docs.codemagic.io/yaml-running-builds/starting-builds-automatically). Flutter's build command installs required CocoaPods dependencies; no separate broad pod update is added.

