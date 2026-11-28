#!/usr/bin/env python3
"""Prüft echte Cache-Treffer und Neubauten mit kleinen Framework-Fixtures."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
BASH = os.environ.get("BBT_TEST_BASH") or shutil.which("bash")


class NativeCacheTest(unittest.TestCase):
    def test_kotlin_cache_follows_extractor_sources_and_build_configuration(self):
        with tempfile.TemporaryDirectory(prefix="bbt-native-cache-") as directory:
            root = Path(directory)

            def write(name, content):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8", newline="\n")
                path.chmod(0o755)

            write("scripts/ci-ios-native-cache.sh", (ROOT / "scripts/ci-ios-native-cache.sh").read_text(encoding="utf-8"))
            write("shared/src/main.kt", "shared-v1")
            write("vendor/innertubex/src/main.kt", "extractor-v1")
            write("vendor/innertubex/build.gradle.kts", "configuration-v1")
            write("AppleApp/Sources/View.swift", "view-v1")
            write("scripts/build-shared-framework.sh", """#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p AppleApp/Frameworks/RedBitShared.xcframework
cat shared/src/main.kt vendor/innertubex/src/main.kt vendor/innertubex/build.gradle.kts > AppleApp/Frameworks/RedBitShared.xcframework/evidence
printf 'build\n' >> build-count
""")
            write("native-core/src/lib.rs", "rust-v1")
            for name in ("xcodebuild", "java", "rustc", "cargo"):
                write(f"tools/{name}", "#!/usr/bin/env bash\nprintf 'fixture-toolchain-v1\\n'\n")
            if os.name == "nt":
                # Git Bash liefert sha256sum statt des macOS-Werkzeugs shasum.
                write("tools/shasum", '#!/usr/bin/env bash\nshift 2\nexec sha256sum "$@"\n')
            subprocess.run(["git", "init", "--quiet", str(root)], check=True, capture_output=True)
            subprocess.run(["git", "-C", str(root), "add", "."], check=True, capture_output=True)

            def fingerprint(kind="kotlin"):
                result = subprocess.run(
                    [BASH, "-c", 'export PATH="$PWD/tools:$PATH" JAVA_HOME="$PWD/tools" '
                     'BBT_IOS_FRAMEWORK_CACHE_DIR="$PWD/cache"; bash scripts/ci-ios-native-cache.sh "$1" --fingerprint', "_", kind],
                    cwd=root, text=True, encoding="utf-8", capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                value = result.stdout.strip()
                self.assertRegex(value, r"^[0-9a-f]{64}$")
                return value

            def run(expected, count):
                # Relative Pfade funktionieren in Git Bash, Linux und macOS gleich.
                result = subprocess.run(
                    [BASH, "-c", 'export PATH="$PWD/tools:$PATH" JAVA_HOME="$PWD/tools" '
                     'BBT_IOS_FRAMEWORK_CACHE_DIR="$PWD/cache"; bash scripts/ci-ios-native-cache.sh kotlin'],
                    cwd=root, text=True, encoding="utf-8", capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(f"BBT_NATIVE_CACHE_{expected}=kotlin", result.stdout)
                self.assertEqual(len((root / "build-count").read_text().splitlines()), count)
                return (root / "AppleApp/Frameworks/RedBitShared.xcframework/evidence").read_text()

            kotlin_key, rust_key = fingerprint(), fingerprint("rust")
            self.assertFalse((root / "cache").exists(), "Nur Schlüssel berechnen erzeugt keinen Cache")
            run("MISS", 1)
            run("HIT", 1)
            write("AppleApp/Sources/View.swift", "view-v2")
            self.assertEqual((fingerprint(), fingerprint("rust")), (kotlin_key, rust_key))
            run("HIT", 1)
            write("vendor/innertubex/src/main.kt", "extractor-v2")
            self.assertNotEqual(fingerprint(), kotlin_key)
            self.assertEqual(fingerprint("rust"), rust_key)
            self.assertIn("extractor-v2", run("MISS", 2))
            run("HIT", 2)
            write("vendor/innertubex/build.gradle.kts", "configuration-v2")
            self.assertIn("configuration-v2", run("MISS", 3))
            write("shared/src/main.kt", "shared-v2")
            self.assertIn("shared-v2", run("MISS", 4))
            current = fingerprint()
            write("native-core/src/lib.rs", "rust-v2")
            self.assertEqual(fingerprint(), current)
            self.assertNotEqual(fingerprint("rust"), rust_key)
            write("local.properties", "LISTEN_TOGETHER_SERVER=fixture")
            self.assertNotEqual(fingerprint(), current)
            run("MISS", 5)
            (root / "cache/kotlin.tar.gz").write_bytes(b"corrupt")
            run("MISS", 6)
            run("HIT", 6)


if __name__ == "__main__":
    unittest.main()
