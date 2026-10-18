# iOS plugin privacy manifest source audit

W21, 2026-10-18. E1 source reading only. No Pods/SDK resolution, archive, Xcode
privacy report, binary scan, hosted access or submission validation was performed.
Versions were matched to project/pubspec.lock and project/.dart_tool/package_config.json.
Sources were read from the existing local Pub cache, not downloaded or modified.

All 16 locked cached packages with an `ios/` or shared `darwin/` directory were
inspected, including native Swift/Objective-C/C/C++ sources and manifests. Searches
covered timestamp attribute keys/accessors/stat families, uptime/mach clocks,
filesystem capacity/statfs, UserDefaults/NSUserDefaults and activeInputModes.
Matching source was read to distinguish calls from comments/generated names/build
scripts. Tests/examples and macOS-only implementations do not describe iOS use.
The table uses paths relative to each package's cache root.

T = file timestamps; B = system boot time; D = disk space; U = user defaults;
K = active keyboard. A dash means no direct required-reason API call found in
the inspected iOS source, not proof about transitive native libraries.

| Locked package | T | B | D | U | K | Own PrivacyInfo.xcprivacy / source evidence |
|---|---|---|---|---|---|---|
| app_links 7.0.0 | - | - | - | - | - | Yes: ios/app_links/Sources/app_links/PrivacyInfo.xcprivacy; empty accessed-API array |
| connectivity_plus 6.1.5 | - | - | - | - | - | Yes: ios/connectivity_plus/Sources/connectivity_plus/PrivacyInfo.xcprivacy; no accessed reasons |
| firebase_core 4.15.0 | - | - | - | - | - | No wrapper manifest in ios/; underlying Firebase Pods must be checked on Mac |
| firebase_messaging 16.7.0 | - | - | - | standardUserDefaults | - | Yes: ios/firebase_messaging/Sources/firebase_messaging/Resources/PrivacyInfo.xcprivacy, CA92.1. FLTFirebaseMessagingPlugin.m:241–242,544–545 stores presentation options |
| firebase_messaging_web 4.2.5 | - | - | - | - | - | ios/ is a source-empty stub; no iOS implementation or manifest |
| geolocator_apple 2.3.14 | - | - | - | - | - | Yes: darwin/geolocator_apple/Sources/geolocator_apple/PrivacyInfo.xcprivacy, no accessed reasons. Location permissions are a separate disclosure |
| image_picker_ios 0.8.13+6 | - | - | - | - | - | Yes: ios/image_picker_ios/Sources/image_picker_ios/Resources/PrivacyInfo.xcprivacy, no accessed reasons; photo metadata is not a filesystem timestamp API |
| package_info_plus 9.0.1 | creation/modification dates | - | - | - | - | Yes, but accessed reasons empty: ios/package_info_plus/Sources/package_info_plus/PrivacyInfo.xcprivacy. FPPPackageInfoPlusPlugin.m:55–70 reads Documents NSFileCreationDate and bundle fileModificationDate |
| permission_handler_apple 9.6.1 | - | - | - | standardUserDefaults, conditional | - | Yes: ios/permission_handler_apple/Sources/permission_handler_apple/PrivacyInfo.xcprivacy, 1C8F.1. strategies/LocationPermissionStrategy.m:8,51,94 is guarded by PERMISSION_LOCATION/WHENINUSE/ALWAYS; these are not enabled by this Podfile. Package.swift's modification-date probe is a build script, not shipped runtime code |
| share_plus 10.1.4 | - | - | - | - | - | Yes: ios/share_plus/Sources/share_plus/PrivacyInfo.xcprivacy, no accessed reasons. FPPSharePlusPlugin.m:211 reads fileSize for a share preview, not free/total disk capacity or a timestamp |
| shared_preferences_foundation 2.5.6 | - | - | - | UserDefaults | - | Yes: darwin/shared_preferences_foundation/Sources/shared_preferences_foundation/Resources/PrivacyInfo.xcprivacy, 1C8F.1 wrapper reason. SharedPreferencesPlugin.swift:18,24,87–162 reads/writes app preferences; generated messages names are not additional API calls |
| sign_in_with_apple 8.1.0 | - | - | - | - | - | No manifest under ios/ or darwin/; AuthenticationServices calls have no direct five-category access found |
| sqflite_darwin 2.4.2 | - | - | - | - | - | Yes: darwin/sqflite_darwin/Sources/sqflite_darwin/Resources/PrivacyInfo.xcprivacy, no accessed reasons. fileSystemRepresentation is a path conversion, not a timestamp/capacity query; system SQLite internals not scanned |
| url_launcher_ios 6.4.1 | - | - | - | - | - | Yes: ios/url_launcher_ios/Sources/url_launcher_ios/Resources/PrivacyInfo.xcprivacy, no accessed reasons |
| wakelock_plus 1.5.2 | - | - | - | - | - | Yes: ios/wakelock_plus/Sources/wakelock_plus/Resources/PrivacyInfo.xcprivacy, no accessed reasons; idle-timer control is not system boot time |
| webview_flutter_wkwebview 3.25.1 | - | - | - | - | - | Yes: darwin/webview_flutter_wkwebview/Sources/webview_flutter_wkwebview/Resources/PrivacyInfo.xcprivacy, no accessed reasons. WKWebsiteDataStore is not UserDefaults; generated Pigeon code inspected |

The locked path_provider_foundation 2.6.0 and objective_c 9.5.0 use native-assets/
Objective-C interoperability instead of ios/darwin plugin directories. Their
local Dart/native source was also searched: no direct five-category call or own
xcprivacy found. Directory URL lookup alone is not a file timestamp call. These
packages and their generated native assets remain part of the Mac archive audit.

## App comparison and result

Both Runner/PrivacyInfo.xcprivacy and Runner/PublisherPrivacy/PrivacyInfo.xcprivacy
already declare exactly:

- NSPrivacyAccessedAPICategoryUserDefaults, CA92.1: app-owned preference data.
- NSPrivacyAccessedAPICategoryFileTimestamp, C617.1: timestamps within the app's
  own container/bundle, including package_info_plus install/update metadata.

No missing app-level category/reason was found in this source scope, so neither
manifest was changed. Do not add boot-time/disk-space/keyboard reasons without
an actual API call and matching allowed purpose. Do not copy the SDK-only 1C8F.1
wrapper reason into the app in place of its own CA92.1 purpose.

package_info_plus ships an empty accessed-API array despite the two timestamp
reads. The app already declares C617.1, but this does not establish that the SDK's
own manifest satisfies Apple's SDK requirements. Check the resolved package and
archive report on Mac, and resolve any SDK manifest warning upstream or in a
separately reviewed dependency change. Do not edit the shared cache as a fix.
Firebase is runtime-disabled in the default iOS app; its Pod/native dependencies
can still be linked and must be audited after resolution. Manifest presence is
not proof it is bundled: inspect podspec resource_bundles and the built archive.

Mac gate: resolve the pinned dependencies, inspect each resource bundle/native
asset, generate Xcode's privacy report for viewer and opted-in publisher, and
reconcile any additional native SDK reasons before submission. No E2/E3 claim.

References: [Apple required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api),
[Apple TN3183](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest).
