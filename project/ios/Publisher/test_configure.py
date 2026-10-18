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

    def _copy_tree(self, root):
        for name in [configure.PROJECT, "Runner/Info.plist", "Runner/Info-Publisher.plist",
                     *[f"Runner/{p}{l}.lproj/InfoPlist.strings"
                       for p in ("", "PublisherStrings/") for l in configure.LANGUAGES]]:
            destination = root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(configure.ROOT / name, destination)
        (root / "Flutter").mkdir()

    def test_disable_after_xcodeproj_rewrite_preserves_pods(self):
        with tempfile.TemporaryDirectory(prefix="hadayah-publisher-") as directory:
            root = Path(directory)
            self._copy_tree(root)
            configure.configure(root, True)
            project = root / configure.PROJECT
            text = project.read_text(encoding="utf-8")
            text = "\n".join(line for line in text.split("\n")
                             if "HADAYAH_PUBLISHER_" not in line)
            # Xcodeproj expands some single-line dictionaries and lists.
            text = text.replace("{isa = XCRemoteSwiftPackageReference;",
                                "{\n\t\t\tisa = XCRemoteSwiftPackageReference;")
            text = text.replace(f"packageReferences = ({configure.PREFIX}01, {configure.PREFIX}02);",
                                f"packageReferences = (\n{configure.PREFIX}01,\n{configure.PREFIX}02,\n);")
            pods = ('\t\tB00000000000000000000001 /* Pods */ = {isa = PBXGroup; children = (); name = Pods; };\n'
                    '\t\tB00000000000000000000002 /* [CP] Check Pods */ = {isa = PBXShellScriptBuildPhase; files = (); shellScript = "echo {Pods}"; };\n')
            text = text.replace("/* Begin PBXBuildFile section */",
                                pods + "/* Begin PBXBuildFile section */")
            project.write_text(text, encoding="utf-8")
            configure.configure(root, False)
            clean = project.read_text(encoding="utf-8")
            for forbidden in [configure.PREFIX, "HaishinKit", "Logboard",
                              "PublisherStrings", "PublisherPrivacy", "Info-Publisher"]:
                self.assertNotIn(forbidden, clean)
            self.assertEqual(clean.count("INFOPLIST_FILE = Runner/Info.plist;"), 3)
            self.assertIn("path = PrivacyInfo.xcprivacy;", clean)
            for language in configure.LANGUAGES:
                self.assertIn(f"path = {language}.lproj/InfoPlist.strings;", clean)
            self.assertIn(pods, clean)
            self.assertFalse((root / configure.CONFIG).exists())

    def test_unrecognized_reserved_entry_refuses_without_writing(self):
        with tempfile.TemporaryDirectory(prefix="hadayah-publisher-") as directory:
            root = Path(directory)
            self._copy_tree(root)
            configure.configure(root, True)
            project = root / configure.PROJECT
            text = "\n".join(line for line in project.read_text(encoding="utf-8").split("\n")
                             if "HADAYAH_PUBLISHER_" not in line)
            text = text.replace("/* Begin PBXBuildFile section */",
                                f"{configure.PREFIX}99 = (unexpected, shape);\n/* Begin PBXBuildFile section */")
            project.write_text(text, encoding="utf-8")
            before = project.read_bytes()
            config_before = (root / configure.CONFIG).read_bytes()
            with self.assertRaisesRegex(ValueError, "publisher|reserved"):
                configure.configure(root, False)
            self.assertEqual(project.read_bytes(), before)
            self.assertEqual((root / configure.CONFIG).read_bytes(), config_before)

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
