"""(name, material, color) combos for parts under a folder path: part_combos.py file.rbxlx Map/Structure"""
import sys
import xml.etree.ElementTree as ET
from collections import Counter

root = ET.parse(sys.argv[1]).getroot()
target = sys.argv[2].split("/")
mat_names = {}
for line in open(sys.argv[3]) if len(sys.argv) > 3 else []:
    pass


def name_of(item):
    for e in item.find("Properties"):
        if e.get("name") == "Name":
            return e.text
    return "?"


def find(items, path):
    for it in items:
        if name_of(it) == path[0]:
            return it if len(path) == 1 else find(it.findall("Item"), path[1:])
    return None


folder = find(root.iter("Item"), target)
combos = Counter()
for it in folder.iter("Item"):
    if it.get("class") != "Part":
        continue
    pr = {e.get("name"): e for e in it.find("Properties")}
    c = int(pr["Color3uint8"].text) & 0xFFFFFF
    size = pr["size"]
    dims = tuple(round(float(size.find(a).text), 1) for a in "XYZ")
    combos[(pr["Name"].text, pr["Material"].text, f"#{c:06x}", "flat" if min(dims) < 1.2 else "block")] += 1
for k, v in combos.most_common(40):
    print(v, k)
