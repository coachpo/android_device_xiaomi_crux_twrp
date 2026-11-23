import runpy
import subprocess
import tempfile
import unittest
from pathlib import Path
from xml.etree.ElementTree import Element


lock = runpy.run_path(str(Path(__file__).with_name("check-source-lock.py")))


class KernelSourceLockTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.tree = Path(temporary.name)
        self.kernel = self.tree / lock["KERNEL"]
        self.kernel.mkdir(parents=True)
        self.git("init", "-q")
        self.commit()
        self.pin = self.git("rev-parse", "HEAD").strip()
        self.project = Element("project", path=lock["KERNEL"], revision=self.pin)

    def git(self, *args):
        return subprocess.check_output(
            ["git", "-C", str(self.kernel), "-c", "user.name=Source Lock Test",
             "-c", "user.email=source-lock@example.invalid", "-c", "commit.gpgsign=false",
             *args], text=True,
        )

    def commit(self):
        self.git("commit", "-q", "--allow-empty", "-m", "Fixture")

    def test_accepts_untagged_pin(self):
        self.assertIsNone(lock["check_project"](self.tree, self.project))

    def test_rejects_reachable_annotated_tag(self):
        self.git("tag", "-a", "local-base", "-m", "Fixture")
        self.commit()
        self.project.set("revision", self.git("rev-parse", "HEAD").strip())
        self.assertIn("use an independent checkout", lock["check_project"](self.tree, self.project))

    def test_rejects_lightweight_tag_at_pin(self):
        self.git("tag", "local-tip")
        self.assertIn("a reachable Git tag", lock["check_project"](self.tree, self.project))

    def test_accepts_unreachable_tag(self):
        self.commit()
        self.git("tag", "newer-tip")
        self.git("checkout", "-q", "--detach", self.pin)
        self.assertIsNone(lock["check_project"](self.tree, self.project))


if __name__ == "__main__":
    unittest.main()
