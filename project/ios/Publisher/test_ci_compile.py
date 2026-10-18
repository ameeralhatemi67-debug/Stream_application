"""Host fixtures only: fake every Mac tool; never compile, resolve or sign."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import sys
import configure


class CompileGateTest(unittest.TestCase):
    def run_gate(self, mode, fail_build=False, rewrite_pods=False,
                 strip_markers=False, broken_disable=False):
        bash = shutil.which('bash')
        if os.name == 'nt':
            bash = r'C:\Program Files\Git\bin\bash.exe'
        with tempfile.TemporaryDirectory(prefix='hadayah-ci-') as directory:
            root = Path(directory)
            (root / 'ios/Publisher').mkdir(parents=True)
            (root / 'ios/Flutter').mkdir()
            script = Path(__file__).with_name('ci_compile.sh')
            shutil.copyfile(script, root / 'ios/Publisher/ci_compile.sh')
            for name in [configure.PROJECT, "Runner.xcworkspace/contents.xcworkspacedata",
                         "Runner/Info.plist", "Runner/Info-Publisher.plist",
                         "Runner/Runner.entitlements", "Runner/PrivacyInfo.xcprivacy", "Podfile",
                         *[f"Runner/{p}{l}.lproj/InfoPlist.strings"
                           for p in ("", "PublisherStrings/") for l in configure.LANGUAGES]]:
                destination = root / 'ios' / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(configure.ROOT / name, destination)
            shutil.copyfile(Path(__file__).with_name('configure.py'), root / 'ios/Publisher/configure.py')
            for args in [('init',), ('config', 'core.autocrlf', 'false'), ('add', 'ios'),
                         ('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                          '-c', 'commit.gpgsign=false', 'commit', '-m', 'fixture baseline')]:
                subprocess.run(['git', *args], cwd=root, check=True, capture_output=True, timeout=30)
            (root / 'fixture_pod.py').write_text(r'''
import os
from pathlib import Path
root = Path(os.environ["FIXTURE_ROOT"])
project = root / "ios/Runner.xcodeproj/project.pbxproj"
text = project.read_text(encoding="utf-8")
if os.environ["STRIP_MARKERS"] == "1":
    text = "\n".join(line for line in text.split("\n") if "HADAYAH_PUBLISHER_" not in line)
pods = ('B00000000000000000000001 /* Pods */ = {isa = PBXGroup; children = (); name = Pods; };\n'
        'B00000000000000000000002 /* [CP] Check Pods */ = {isa = PBXShellScriptBuildPhase; files = (); shellScript = "echo Pods"; };\n')
project.write_text(text.replace("/* Begin PBXBuildFile section */",
                               pods + "/* Begin PBXBuildFile section */"), encoding="utf-8")
workspace = root / "ios/Runner.xcworkspace/contents.xcworkspacedata"
workspace.write_text(workspace.read_text(encoding="utf-8").replace("</Workspace>",
                     '<FileRef location="group:Pods/Pods.xcodeproj"></FileRef>\n</Workspace>'), encoding="utf-8")
''', encoding='utf-8')
            driver = root / 'fixture.sh'
            driver.write_text(r'''
set -eu
export CALLS="$PWD/calls"
flutter() {
  echo "flutter $*" >> "$CALLS"
  if [[ "$1" == build && "$FAIL_BUILD" == 1 ]]; then
    for ((i=1;i<=200;i++)); do
      if [[ $i == 60 ]]; then echo "error: fixture first compile error"; else echo "line $i"; fi
    done
    return 7
  fi
  echo "fixture success"
}
xcodebuild() { echo 'Xcode 26.3'; }
xcrun() { echo '26.3'; }
pod() {
  echo "pod $*" >> "$CALLS"
  if [[ "$1" == install && "$REWRITE_PODS" == 1 ]]; then
    "$FIXTURE_PYTHON" "$FIXTURE_ROOT/fixture_pod.py"
  fi
  echo '1.16.2'
}
python3() {
  echo "$*" >> "$CALLS"
  if [[ "$*" == *--disable && "$BROKEN_DISABLE" == 1 ]]; then
    rm -f ios/Flutter/Publisher.generated.xcconfig
  else
    "$FIXTURE_PYTHON" "$@"
  fi
}
git() {
  echo "git $*" >> "$CALLS"
  command git "$@"
}
export -f flutter xcodebuild xcrun pod python3 git
bash ios/Publisher/ci_compile.sh "$MODE"
''', encoding='utf-8')
            result = subprocess.run([bash, 'fixture.sh'], cwd=root,
                                    env={**os.environ, 'MODE': mode,
                                         'FAIL_BUILD': str(int(fail_build)),
                                         'REWRITE_PODS': str(int(rewrite_pods)),
                                         'STRIP_MARKERS': str(int(strip_markers)),
                                         'BROKEN_DISABLE': str(int(broken_disable)),
                                         'FIXTURE_ROOT': root.as_posix(),
                                         'FIXTURE_PYTHON': Path(sys.executable).as_posix()},
                                    capture_output=True, text=True, timeout=45)
            result.project = (root / 'ios' / configure.PROJECT).read_text(encoding='utf-8')
            result.workspace = (root / 'ios/Runner.xcworkspace/contents.xcworkspacedata').read_text(encoding='utf-8')
            return result, (root / 'calls').read_text(encoding='utf-8')

    def test_viewer_accepts_pods_diff_and_logs_stat(self):
        result, calls = self.run_gate('viewer', rewrite_pods=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('ios-diff-stat', result.stdout)
        self.assertIn('git diff --stat -- ios/', calls)
        self.assertIn('Pods', result.project)
        self.assertIn('[CP]', result.project)
        self.assertIn('Pods/Pods.xcodeproj', result.workspace)

    def test_publisher_accepts_markerless_pods_rewrite(self):
        result, calls = self.run_gate('publisher', rewrite_pods=True, strip_markers=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('ios-diff-stat', result.stdout)
        self.assertNotIn(configure.PREFIX, result.project)
        self.assertNotIn('HaishinKit', result.project)
        self.assertIn('Pods', result.project)
        self.assertIn('[CP]', result.project)
        self.assertIn('Pods/Pods.xcodeproj', result.workspace)
        self.assertIn('--disable', calls)

    def test_broken_disable_fails_isolation_and_preserves_build_failure(self):
        for fail_build in (False, True):
            with self.subTest(fail_build=fail_build):
                result, calls = self.run_gate('publisher', rewrite_pods=True,
                                              strip_markers=True, broken_disable=True,
                                              fail_build=fail_build)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                if fail_build:
                    self.assertEqual(result.returncode, 7)
                self.assertIn(configure.PREFIX, result.project)
                self.assertIn('publisher-project', result.stdout)
                self.assertIn('--disable', calls)

    def test_viewer_never_enables_publisher(self):
        result, calls = self.run_gate('viewer')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('flutter analyze', calls)
        self.assertIn('flutter test --reporter expanded', calls)
        self.assertNotIn('--enable', calls)
        for path in ['ios/Runner/Info.plist', 'ios/Runner/en.lproj/InfoPlist.strings',
                     'ios/Runner/ar.lproj/InfoPlist.strings', 'ios/Runner/Runner.entitlements',
                     'ios/Runner/PrivacyInfo.xcprivacy', 'ios/Podfile']:
            self.assertIn(path, calls)
        self.assertNotIn('git diff --exit-code HEAD -- ios/\n', calls)
        self.assertIn('Running publisher-project', result.stdout)
        self.assertIn('Running publisher-flag', result.stdout)

    def test_publisher_restores_viewer(self):
        result, calls = self.run_gate('publisher')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertLess(calls.index('--enable'), calls.index('pod install'))
        self.assertIn('--dart-define=IOS_PHONE_PUBLISHING=true', calls)
        self.assertLess(calls.index('--disable'), calls.index('git diff'))

    def test_failed_build_keeps_exit_and_prints_150_lines_then_cleans(self):
        result, calls = self.run_gate('publisher', fail_build=True)
        self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
        excerpt = result.stdout.split('First error context:', 1)[1].splitlines()
        self.assertIn('error: fixture first compile error', excerpt)
        self.assertEqual(len(excerpt[1:151]), 150)
        self.assertEqual(excerpt[1], 'line 30')
        self.assertEqual(excerpt[150], 'line 179')
        self.assertIn('--disable', calls)
        for path in ['ios/Runner/Info.plist', 'ios/Runner/en.lproj/InfoPlist.strings',
                     'ios/Runner/ar.lproj/InfoPlist.strings', 'ios/Runner/Runner.entitlements',
                     'ios/Runner/PrivacyInfo.xcprivacy', 'ios/Podfile']:
            self.assertIn(path, calls)
        self.assertNotIn('git diff --exit-code HEAD -- ios/\n', calls)
        self.assertIn('Running publisher-project', result.stdout)
        self.assertIn('Running publisher-flag', result.stdout)


if __name__ == '__main__':
    unittest.main()
