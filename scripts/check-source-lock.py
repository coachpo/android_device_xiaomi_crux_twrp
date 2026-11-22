#!/usr/bin/env python3
"""Read-only check that the TWRP build tree matches the invoking Git commit."""
import argparse
import concurrent.futures
import hashlib
import os
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
LOCK = "manifests/crux-twrp.xml"
DEVICE = Path("device/xiaomi/crux")


def git(path, *args):
    return subprocess.check_output(["git", "--no-optional-locks", "-C", str(path), *args],
                                   stderr=subprocess.DEVNULL)


def check_project(tree, project):
    path = project.get("path", project.get("name"))
    directory = tree / path
    pin = project.get("revision")
    if not pin or not re.fullmatch("[0-9a-f]{40}", pin):
        return f"{path}: missing full commit pin"
    if not (directory / ".git").exists():
        return f"{path}: not checked out"
    try:
        actual = git(directory, "rev-parse", "HEAD").decode().strip()
        if actual != pin:
            return f"{path}: HEAD {actual}, expected {pin}"
        if git(directory, "status", "--porcelain", "--untracked-files=no"):
            return f"{path}: tracked changes"
    except subprocess.CalledProcessError:
        return f"{path}: cannot read checkout"
    for entry in project:
        src, dest = directory / entry.get("src"), tree / entry.get("dest")
        if entry.tag == "linkfile":
            valid = dest.is_symlink() and dest.resolve() == src.resolve()
        elif entry.tag == "copyfile":
            valid = dest.is_file() and not dest.is_symlink() and dest.read_bytes() == src.read_bytes()
        else:
            return f"{path}: unsupported lock entry {entry.tag}"
        if not valid:
            return f"{entry.get('dest')}: differs from the locked {entry.tag}"
    return None


def check_device(tree):
    files = set()
    problems = []
    for entry in git(ROOT, "ls-tree", "-rz", "HEAD", "--", str(DEVICE)).split(b"\0"):
        if not entry:
            continue
        fields, name = entry.split(b"\t", 1)
        mode, _, digest = fields.split()
        path = Path(os.fsdecode(name))
        files.add(path)
        installed = tree / path
        if mode == b"120000" and installed.is_symlink():
            contents = os.fsencode(os.readlink(installed))
        elif (mode in (b"100644", b"100755") and installed.is_file() and not installed.is_symlink()
              and bool(installed.stat().st_mode & 0o111) == (mode == b"100755")):
            contents = installed.read_bytes()
        else:
            problems.append(f"{path}: missing file or wrong mode")
            continue
        actual = hashlib.sha1(f"blob {len(contents)}\0".encode() + contents).hexdigest().encode()
        if actual != digest:
            problems.append(f"{path}: differs from invoking commit")
    for path in (tree / DEVICE).rglob("*"):
        if (not path.is_dir() or path.is_symlink()) and path.relative_to(tree) not in files:
            problems.append(f"{path.relative_to(tree)}: not in invoking commit")
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tree", type=Path)
    tree = parser.parse_args().tree.resolve()
    lock = git(ROOT, "show", f"HEAD:{LOCK}")
    commit = git(ROOT, "rev-parse", "HEAD")
    if (ROOT / LOCK).read_bytes() != lock:
        parser.exit(1, "The working-tree lock differs from HEAD.\n")
    manifest = tree / ".repo/manifests"
    selected = tree / ".repo/manifest.xml"
    if (not selected.is_file() or not (manifest / LOCK).is_file()
            or git(manifest, "rev-parse", "HEAD") != commit
            or (manifest / LOCK).read_bytes() != lock
            or ET.parse(selected).getroot().find("include[@name='" + LOCK + "']") is None
            or list((tree / ".repo/local_manifests").glob("*.xml"))):
        parser.exit(1, "The sync tree does not select this commit's lock; run setup-twrp.sh.\n")

    projects = ET.fromstring(lock).findall("project")
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        problems = [problem for problem in pool.map(lambda p: check_project(tree, p), projects) if problem]
    problems += check_device(tree)
    if problems:
        parser.exit(1, "\n".join(problems) + "\n")
    print(f"Source lock verified: {len(projects)} projects and the committed Crux device leaf")


if __name__ == "__main__":
    main()
