"""Host fixtures only: fake every Mac tool; never compile, resolve or sign."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class CompileGateTest(unittest.TestCase):
    def run_gate(self, mode, fail_build=False):
        bash = shutil.which('bash')
        if os.name == 'nt':
            bash = r'C:\Program Files\Git\bin\bash.exe'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'ios/Publisher').mkdir(parents=True)
            (root / 'ios/Flutter').mkdir()
            script = Path(__file__).with_name('ci_compile.sh')
            shutil.copyfile(script, root / 'ios/Publisher/ci_compile.sh')
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
pod() { echo "pod $*" >> "$CALLS"; echo '1.16.2'; }
python3() {
  echo "$*" >> "$CALLS"
  if [[ "$*" == *--enable ]]; then
    touch ios/Flutter/Publisher.generated.xcconfig
  else
    rm -f ios/Flutter/Publisher.generated.xcconfig
  fi
}
git() {
  echo "git $*" >> "$CALLS"
  [[ ! -e ios/Flutter/Publisher.generated.xcconfig ]]
}
export -f flutter xcodebuild xcrun pod python3 git
bash ios/Publisher/ci_compile.sh "$MODE"
''', encoding='utf-8')
            result = subprocess.run([bash, 'fixture.sh'], cwd=root,
                                    env={**os.environ, 'MODE': mode,
                                         'FAIL_BUILD': str(int(fail_build))},
                                    capture_output=True, text=True)
            return result, (root / 'calls').read_text(encoding='utf-8')

    def test_viewer_never_enables_publisher(self):
        result, calls = self.run_gate('viewer')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('flutter analyze', calls)
        self.assertIn('flutter test --reporter expanded', calls)
        self.assertNotIn('--enable', calls)
        self.assertIn('git diff --exit-code HEAD -- ios/', calls)

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
        self.assertIn('git diff --exit-code HEAD -- ios/', calls)


if __name__ == '__main__':
    unittest.main()
