# Android build memory failure, 2026-09-27

Owner reports Chrome starts but the SM-S936B Android run fails. Checkout is main master, source `e820119`; the terminal's assembleDebug invocation failed before installing or launching the app. Package-update notices are not the reported failure.

The JVM fatal log for pid 39724 at 11:20 +03:00 states insufficient Java-runtime memory and a native malloc failure for 1,519,776 bytes. It records 233 MiB free physical RAM and 38 MiB available system commit capacity, with about 450 MiB resident in the failed process. Host physical memory is about 15.2 GiB. The 8 GiB heap and 4 GiB metaspace settings are upper bounds, not measured allocations. This establishes system-wide memory exhaustion; it does not establish an application/native-streaming defect.

At 11:23 +03:00 a read-only OS check found 479,512 KiB free physical memory and 2,603,204 KiB free virtual memory. Pressure remains high. No process was terminated. No broad Gradle stop, cache clean, dependency upgrade, JVM-setting change, credential read, rebuild or phone installation was performed.

Recommended recovery: save work, close unnecessary browser/IDE/build sessions, or restart Windows; reopen the main project only and retry the owner's same phone run command. A new successful build/launch is still needed. If failure recurs with adequate memory, inspect the new fatal log before selecting a build-setting repair. Android tests remain blocked; the reported Chrome launch is not a completed acceptance case.

Gradle documentation consulted through Context7: [Gradle 8.14.3 JVM/build configuration](https://github.com/gradle/gradle/blob/v8.14.3/platforms/documentation/docs/src/docs/userguide/unused/config_gradle.adoc). Historical integration verification used bounded heap/workers, but the exact user-host recovery is not yet verified.

Raw fatal logs can contain environment details and remain local. This summary contains no configuration values or account secrets.
