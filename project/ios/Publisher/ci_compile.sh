#!/usr/bin/env bash
# Unsigned, example-config compile only. Run from project/ on Codemagic.
set -euo pipefail
mode=${1:?viewer or publisher required}
[[ "$mode" == viewer || "$mode" == publisher ]]
mkdir -p build/ci-logs
activated=false

excerpt() {
  local log=$1 first start end
  first=$(grep -n -m1 -Ei 'error:|fatal error|exception|failed|Error \(' "$log" || true)
  first=${first%%:*}
  if [[ -z "$first" ]]; then first=1; fi
  start=$((first > 30 ? first - 30 : 1))
  end=$((start + 149))
  printf '\nFirst error context: %s (lines %s-%s)\n' "$log" "$start" "$end"
  sed -n "${start},${end}p" "$log"
}

run() {
  local label=$1 status
  shift
  printf '\nRunning %s\n' "$label"
  if "$@" >"build/ci-logs/$label.log" 2>&1; then
    tail -n 8 "build/ci-logs/$label.log"
  else
    status=$?
    excerpt "build/ci-logs/$label.log"
    return "$status"
  fi
}

publisher_project_clean() {
  local status
  if grep -nE 'A117000000000000000000|HaishinKit|Logboard|PublisherStrings|PublisherPrivacy|Info-Publisher' ios/Runner.xcodeproj/project.pbxproj; then
    echo 'error: publisher content survived project cleanup'
    return 1
  else
    status=$?
    if [[ $status != 1 ]]; then return "$status"; fi
  fi
  echo 'Viewer project contains no opt-in publisher references'
}

publisher_flag_absent() {
  if [[ -e ios/Flutter/Publisher.generated.xcconfig ]]; then
    echo 'error: generated publisher flag survived cleanup'
    return 1
  fi
  echo 'Generated publisher flag is absent'
}

finish() {
  local status=$? cleanup=0
  trap - EXIT
  set +e
  if [[ "$activated" == true ]]; then
    run disable python3 ios/Publisher/configure.py --disable
    cleanup=$?
  fi
  run ios-clean git diff --exit-code HEAD -- \
    ios/Runner/Info.plist \
    ios/Runner/en.lproj/InfoPlist.strings ios/Runner/ar.lproj/InfoPlist.strings \
    ios/Runner/Runner.entitlements ios/Runner/PrivacyInfo.xcprivacy ios/Podfile
  if [[ $? != 0 ]]; then cleanup=1; fi
  run publisher-project publisher_project_clean
  if [[ $? != 0 ]]; then cleanup=1; fi
  run publisher-flag publisher_flag_absent
  if [[ $? != 0 ]]; then cleanup=1; fi
  # CocoaPods may integrate the tracked project/workspace on its first run.
  run ios-diff-stat git diff --stat -- ios/
  if [[ $status == 0 && $cleanup != 0 ]]; then status=$cleanup; fi
  exit "$status"
}
trap finish EXIT

run flutter-version flutter --version
run xcode-version xcodebuild -version
run ios-sdk xcrun --sdk iphoneos --show-sdk-version
# codemagic.yaml pins Xcode 26.6; keep Apple's upload SDK floor if the pin moves.
xcode_major=$(awk '/^Xcode / {split($2,v,"."); print v[1]}' build/ci-logs/xcode-version.log)
sdk_major=$(cut -d. -f1 build/ci-logs/ios-sdk.log | head -n1)
[[ "$xcode_major" -ge 26 && "$sdk_major" -ge 26 ]] || {
  echo 'error: use a stable Codemagic Xcode 26+/iOS 26+ image'; exit 1;
}
run pods-version pod --version
run packages flutter pub get
if [[ "$mode" == publisher ]]; then
  # Set before enable so a partial enable failure also attempts rollback.
  activated=true
  run enable python3 ios/Publisher/configure.py --enable
fi
run pods bash -c 'cd ios && pod install'
if [[ "$mode" == viewer ]]; then
  run analyze flutter analyze
  run tests flutter test --reporter expanded
  run build flutter build ios --release --no-codesign --dart-define-from-file=dart_define.example.json
else
  run build flutter build ios --release --no-codesign --dart-define-from-file=dart_define.example.json --dart-define=IOS_PHONE_PUBLISHING=true
fi
