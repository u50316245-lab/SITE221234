"""Dump structure, lighting and scripts of a .rbxlx place file."""
import os
import sys
import xml.etree.ElementTree as ET
from collections import Counter

SCRIPT_CLASSES = ("Script", "LocalScript", "ModuleScript")


def prop(item, key):
    props = item.find("Properties")
    if props is None:
        return None
    for p in props:
        if p.get("name") == key:
            return p
    return None


def name_of(item):
    p = prop(item, "Name")
    return p.text if p is not None else "?"


def main(path, outdir):
    root = ET.parse(path).getroot()
    print("=====", path)
    print(Counter(i.get("class") for i in root.iter("Item")).most_common(50))
    os.makedirs(outdir, exist_ok=True)

    def walk(item, depth, parent_path):
        cls = item.get("class")
        n = name_of(item)
        full = f"{parent_path}/{n}"
        kids = item.findall("Item")
        if cls in SCRIPT_CLASSES:
            src = prop(item, "Source")
            text = (src.text or "") if src is not None else ""
            print(f"  SCRIPT {cls} {full} {len(text.splitlines())} lines")
            fname = full.strip("/").replace("/", ".") + {"Script": ".server.lua", "LocalScript": ".client.lua", "ModuleScript": ".lua"}[cls]
            with open(os.path.join(outdir, fname), "w") as fh:
                fh.write(text)
        elif depth <= 2 and cls not in ("Part", "WedgePart", "MeshPart", "UnionOperation"):
            print("  " * depth + f"{cls} {n} ({len(kids)})")
        if cls in ("Lighting", "Atmosphere", "BloomEffect", "ColorCorrectionEffect", "SunRaysEffect", "DepthOfFieldEffect", "Sky", "SoundService", "Workspace"):
            props = item.find("Properties")
            for p in props:
                if p.get("name") not in ("Name",) and len(list(p)) == 0:
                    print("      ", p.tag, p.get("name"), "=", (p.text or "")[:60])
                elif p.tag in ("Color3", "Color3uint8"):
                    print("      ", p.tag, p.get("name"), "=", [c.text for c in p] or p.text)
        for k in kids:
            walk(k, depth + 1, full)

    for i in root.findall("Item"):
        walk(i, 0, "")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
