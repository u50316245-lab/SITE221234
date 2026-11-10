"""Material / name statistics for parts of a .rbxlx place."""
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict

MATERIALS = {256: "Plastic", 272: "SmoothPlastic", 288: "Neon", 512: "Wood", 528: "WoodPlanks", 784: "Marble", 788: "Basalt", 800: "Slate", 804: "CrackedLava", 816: "Concrete", 820: "Limestone", 832: "Granite", 836: "Pavement", 848: "Brick", 864: "Pebble", 880: "Cobblestone", 896: "Rock", 912: "Sandstone", 1040: "CorrodedMetal", 1056: "DiamondPlate", 1072: "Foil", 1088: "Metal", 1280: "Grass", 1284: "LeafyGrass", 1296: "Sand", 1312: "Fabric", 1328: "Snow", 1344: "Mud", 1360: "Ground", 1376: "Asphalt", 1392: "Salt", 1536: "Ice", 1552: "Glacier", 1568: "Glass", 1584: "ForceField", 1792: "Air", 2048: "Water", 1584 + 1: "?", 1088 + 1: "?", 1056 + 1: "?", 818: "Plaster", 1312 + 1: "?", 1281: "?", 2304: "Cardboard", 2305: "Carpet", 2306: "CeramicTiles", 2307: "ClayRoofTiles", 2308: "RoofShingles", 2309: "Leather", 2310: "Plaster", 2311: "Rubber"}


def props(item):
    out = {}
    p = item.find("Properties")
    if p is None:
        return out
    for e in p:
        out[e.get("name")] = e
    return out


def main(path):
    root = ET.parse(path).getroot()
    by_folder = defaultdict(Counter)
    names = defaultdict(Counter)
    prop_names = Counter()

    def walk(item, folder):
        cls = item.get("class")
        pr = props(item)
        n = pr["Name"].text if "Name" in pr else "?"
        if cls in ("Part", "WedgePart", "SpawnLocation", "CornerWedgePart", "TrussPart"):
            mat = pr.get("Material")
            m = MATERIALS.get(int(mat.text), mat.text) if mat is not None else "Plastic(default)"
            by_folder[folder][m] += 1
            names[folder][n] += 1
            for k in pr:
                prop_names[k] += 1
        sub = folder
        if cls in ("Folder", "Model") and folder.count("/") < 3:
            sub = f"{folder}/{n}"
        for k in item.findall("Item"):
            walk(k, sub)

    for i in root.findall("Item"):
        walk(i, "")
    for f in sorted(by_folder):
        print(f, dict(by_folder[f].most_common(12)))
        print("   names:", names[f].most_common(25))
    print("PART PROPS:", prop_names.most_common())


if __name__ == "__main__":
    main(sys.argv[1])
