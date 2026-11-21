#!/usr/bin/env python3
"""Print the kernel revision that manifests/crux-twrp.xml pins."""
from pathlib import Path
import xml.etree.ElementTree as ET

manifest = Path(__file__).resolve().parents[1] / "manifests/crux-twrp.xml"
pins = [p.get("revision") for p in ET.parse(manifest).getroot().findall("project") if p.get("path") == "kernel/xiaomi/crux"]
assert len(pins) == 1 and len(pins[0]) == 40, f"{manifest}: expected one SHA-pinned kernel project"
print(pins[0])
