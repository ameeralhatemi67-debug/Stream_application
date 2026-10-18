"""Host checks for the reversible Xcode edit, not an iOS compilation test."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("configure", Path(__file__).with_name("configure.py"))
configure = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(configure)


class PublisherConfigurationTest(unittest.TestCase):
    def test_opt_in_is_idempotent_and_byte_reversible(self):
        with tempfile.TemporaryDirectory(prefix="hadayah-publisher-") as directory:
            root = Path(directory)
            for name in [configure.PROJECT, "Runner/Info.plist", "Runner/Info-Publisher.plist",
                         *[f"Runner/{p}{l}.lproj/InfoPlist.strings"
                           for p in ("", "PublisherStrings/") for l in configure.LANGUAGES]]:
                destination = root / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(configure.ROOT / name, destination)
            (root / "Flutter").mkdir()
            project = root / configure.PROJECT
            baseline = project.read_bytes()
            self.assertNotIn(b"XCRemoteSwiftPackageReference", baseline)
            configure.configure(root, True)
            enabled = project.read_bytes()
            self.assertEqual(enabled.count(b"isa = XCRemoteSwiftPackageReference;"), 2)
            self.assertEqual(enabled.count(b"isa = XCSwiftPackageProductDependency;"), 3)
            self.assertEqual(enabled.count(b"INFOPLIST_FILE = Runner/Info-Publisher.plist;"), 3)
            self.assertIn(b"PublisherPrivacy/PrivacyInfo.xcprivacy", enabled)
            self.assertEqual(enabled.count(b"path = PublisherStrings/"), 2)
            # Signing rules must survive either toggle byte-for-byte.
            signing = lambda raw: [line for line in raw.splitlines() if b"CODE_SIGN" in line]
            self.assertEqual(signing(baseline), signing(enabled))
            configure.configure(root, True)
            self.assertEqual(project.read_bytes(), enabled)
            configure.configure(root, False)
            self.assertEqual(project.read_bytes(), baseline)
            self.assertFalse((root / configure.CONFIG).exists())
            configure.configure(root, False)
            self.assertEqual(project.read_bytes(), baseline)

    def test_viewer_resources_declare_no_capture_purposes(self):
        for name in ["Runner/Info.plist", "Runner/en.lproj/InfoPlist.strings", "Runner/ar.lproj/InfoPlist.strings"]:
            text = (configure.ROOT / name).read_text(encoding="utf-8")
            for key in ("NSCameraUsageDescription", "NSMicrophoneUsageDescription", "UIBackgroundModes"):
                self.assertNotIn(key, text, f"{name} must not contain {key}")
        self.assertNotIn("PublisherStrings", (configure.ROOT / configure.PROJECT).read_text(encoding="utf-8"))

    def test_changed_project_anchor_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "three Runner plist"):
            configure.transform("unrecognized project", True)

    def test_unrelated_custom_xcconfig_is_never_overwritten(self):
        with tempfile.TemporaryDirectory(prefix="hadayah-publisher-") as directory:
            root = Path(directory)
            for name in [configure.PROJECT, "Runner/Info.plist", "Runner/Info-Publisher.plist",
                         *[f"Runner/{p}{l}.lproj/InfoPlist.strings"
                           for p in ("", "PublisherStrings/") for l in configure.LANGUAGES]]:
                destination = root / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(configure.ROOT / name, destination)
            config = root / configure.CONFIG
            config.parent.mkdir()
            config.write_text("Owner configuration", encoding="utf-8")
            before = (root / configure.PROJECT).read_bytes()
            with self.assertRaisesRegex(ValueError, "unmanaged"):
                configure.configure(root, True)
            self.assertEqual((root / configure.PROJECT).read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
