"""
Palata13 place tool.

  python3 tools/places.py extract   # one-time: pull scripts out of places/*.rbxlx into src/
  python3 tools/places.py build     # write src/ scripts + environment upgrades into places/*.rbxlx
  python3 tools/places.py sourcemap # write sourcemap-<place>.json for luau-lsp

Layout (Rojo-like):
  src/shared/*.lua                 -> ReplicatedStorage.Shared.<Name>        (both places)
  src/server/Core/*.lua            -> ServerScriptService.Core.<Name>        (both places)
  src/client/*.client.lua          -> StarterPlayer.StarterPlayerScripts     (both places)
  src/first/*.client.lua           -> ReplicatedFirst                        (both places)
  src/<place>/server/*.server.lua  -> ServerScriptService
  src/<place>/server/Core/*.lua    -> ServerScriptService.Core
  src/<place>/client/*.client.lua  -> StarterPlayer.StarterPlayerScripts
"""
import glob
import json
import os
import sys
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape, quoteattr

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLACES = {
    "lobby": os.path.join(ROOT, "places", "Palata13_Lobby.rbxlx"),
    "game": os.path.join(ROOT, "places", "Palata13_Game.rbxlx"),
}
SCRIPT_CLASSES = ("Script", "LocalScript", "ModuleScript")
HEADER = (
    '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
    'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
    '<Meta name="ExplicitAutoJoints">true</Meta>\n'
    "<External>null</External><External>nil</External>\n"
)

# --------------------------------------------------------------------------- tree helpers


def props_of(item):
    p = item.find("Properties")
    if p is None:
        p = ET.SubElement(item, "Properties")
    return p


def get_prop(item, name):
    for e in props_of(item):
        if e.get("name") == name:
            return e
    return None


def name_of(item):
    e = get_prop(item, "Name")
    return e.text if e is not None else ""


_ref_counter = [0]


def new_item(parent, cls, name):
    _ref_counter[0] += 1
    item = ET.SubElement(parent, "Item", {"class": cls, "referent": f"RBXP13AAA{_ref_counter[0]:06d}"})
    props = ET.SubElement(item, "Properties")
    n = ET.SubElement(props, "string", {"name": "Name"})
    n.text = name
    return item


def child(parent, name, cls=None):
    for it in parent.findall("Item"):
        if name_of(it) == name and (cls is None or it.get("class") == cls):
            return it
    return None


def ensure_child(parent, name, cls):
    return child(parent, name, cls) or new_item(parent, cls, name)


def service(root, cls):
    for it in root.findall("Item"):
        if it.get("class") == cls:
            return it
    return new_item(root, cls, cls)


def set_prop(item, tag, name, value):
    """value: scalar -> text; dict -> child elements (Color3 R/G/B etc.)."""
    props = props_of(item)
    e = get_prop(item, name)
    if e is None:
        e = ET.SubElement(props, tag, {"name": name})
    else:
        e.tag = tag
        for c in list(e):
            e.remove(c)
    if isinstance(value, dict):
        e.text = None
        for k, v in value.items():
            ET.SubElement(e, k).text = fmt(v)
    else:
        e.text = fmt(value)
    return e


def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return f"{v:.4f}".rstrip("0").rstrip(".") if v != int(v) else str(int(v))
    return str(v)


def color3(r, g, b):
    return {"R": r / 255, "G": g / 255, "B": b / 255}


# --------------------------------------------------------------------------- serialization (keeps CDATA sources)


def serialize(el, out):
    if el.tag == "ProtectedString":
        text = el.text or ""
        assert "]]>" not in text, "script source contains ]]>"
        out.append(f'<ProtectedString name={quoteattr(el.get("name"))}><![CDATA[{text}]]></ProtectedString>')
        return
    attrs = "".join(f" {k}={quoteattr(v)}" for k, v in el.attrib.items())
    kids = list(el)
    if not kids and (el.text is None or el.text == ""):
        out.append(f"<{el.tag}{attrs}></{el.tag}>")
        return
    out.append(f"<{el.tag}{attrs}>")
    if el.text:
        out.append(escape(el.text))
    for k in kids:
        serialize(k, out)
    out.append(f"</{el.tag}>")
    if el.tag == "Item":
        out.append("\n")


def write_place(root, path):
    out = [HEADER]
    for it in root.findall("Item"):
        serialize(it, out)
    out.append("</roblox>\n")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("".join(out))


# --------------------------------------------------------------------------- script manifest


def manifest(place):
    """List of (container path, class, name, file)."""
    entries = []

    def add(pattern, container, cls, suffix):
        for f in sorted(glob.glob(os.path.join(ROOT, pattern))):
            name = os.path.basename(f)[: -len(suffix)]
            entries.append((container, cls, name, f))

    add("src/shared/*.lua", "ReplicatedStorage/Shared", "ModuleScript", ".lua")
    add("src/server/Core/*.lua", "ServerScriptService/Core", "ModuleScript", ".lua")
    add(f"src/{place}/server/Core/*.lua", "ServerScriptService/Core", "ModuleScript", ".lua")
    add(f"src/{place}/server/*.server.lua", "ServerScriptService", "Script", ".server.lua")
    add("src/client/*.client.lua", "StarterPlayer/StarterPlayerScripts", "LocalScript", ".client.lua")
    add(f"src/{place}/client/*.client.lua", "StarterPlayer/StarterPlayerScripts", "LocalScript", ".client.lua")
    add("src/first/*.client.lua", "ReplicatedFirst", "LocalScript", ".client.lua")
    return entries


CONTAINER_CLASSES = {
    "ReplicatedStorage": "ReplicatedStorage",
    "ServerScriptService": "ServerScriptService",
    "StarterPlayer": "StarterPlayer",
    "ReplicatedFirst": "ReplicatedFirst",
    "StarterPlayerScripts": "StarterPlayerScripts",
}


def container(root, path):
    parts = path.split("/")
    node = service(root, CONTAINER_CLASSES[parts[0]])
    for p in parts[1:]:
        node = ensure_child(node, p, CONTAINER_CLASSES.get(p, "Folder"))
    return node


def sync_scripts(root, place):
    for cont, cls, name, f in manifest(place):
        parent = container(root, cont)
        item = child(parent, name, cls) or new_item(parent, cls, name)
        with open(f, encoding="utf-8") as fh:
            source = fh.read()
        e = get_prop(item, "Source")
        if e is None:
            e = ET.SubElement(props_of(item), "ProtectedString", {"name": "Source"})
        e.text = source


# --------------------------------------------------------------------------- environment upgrades


def walk(item, fn, path=""):
    full = f"{path}/{name_of(item)}"
    fn(item, full)
    for k in item.findall("Item"):
        walk(k, fn, full)


MAT = {"SmoothPlastic": 272, "Concrete": 816, "Slate": 800, "Plaster": 2310, "CeramicTiles": 2306}

# (path prefix, part name, current material) -> new material
MATERIAL_RULES = {
    "game": [
        ("/Workspace/Map/Structure/", "Wall", "Concrete", "Plaster"),
        ("/Workspace/Map/Structure/", "Header", "Concrete", "Plaster"),
        ("/Workspace/Map/Structure/", "Ceiling", "Concrete", "Plaster"),
        ("/Workspace/Map/Structure/", "Wainscot", "SmoothPlastic", "Plaster"),
        ("/Workspace/Map/Structure/", "Cladding", "Slate", "CeramicTiles"),
    ],
    "lobby": [
        ("/Workspace/Lobby/Structure/", "Wall", "Concrete", "Plaster"),
        ("/Workspace/Lobby/Structure/", "Lintel", "Concrete", "Plaster"),
        ("/Workspace/Lobby/Structure/", "Ceiling", "Concrete", "Plaster"),
        ("/Workspace/Lobby/Structure/", "Wainscot", "SmoothPlastic", "Plaster"),
    ],
}

# Film grade per place: ColorCorrection "Grade" + Bloom + new DepthOfField.
GRADE = {
    "game": dict(Brightness=-0.01, Contrast=0.24, Saturation=-0.34, Tint=(226, 236, 232)),
    "lobby": dict(Brightness=0.0, Contrast=0.22, Saturation=-0.3, Tint=(240, 228, 226)),
}


def upgrade_environment(root, place):
    rules = MATERIAL_RULES[place]
    changed = [0]

    def fix(item, path):
        if item.get("class") != "Part":
            return
        for prefix, pname, old, new in rules:
            if path.startswith(prefix) and name_of(item) == pname:
                m = get_prop(item, "Material")
                if m is not None and int(m.text) == MAT[old]:
                    m.text = str(MAT[new])
                    changed[0] += 1

    for it in root.findall("Item"):
        walk(it, fix)

    lighting = service(root, "Lighting")
    set_prop(lighting, "float", "EnvironmentSpecularScale", 0.85)
    set_prop(lighting, "float", "ShadowSoftness", 0.14)

    g = GRADE[place]
    grade = ensure_child(lighting, "Grade", "ColorCorrectionEffect")
    set_prop(grade, "float", "Brightness", g["Brightness"])
    set_prop(grade, "float", "Contrast", g["Contrast"])
    set_prop(grade, "float", "Saturation", g["Saturation"])
    set_prop(grade, "Color3", "TintColor", color3(*g["Tint"]))
    set_prop(grade, "bool", "Enabled", True)

    bloom = ensure_child(lighting, "Bloom", "BloomEffect")
    set_prop(bloom, "float", "Intensity", 0.85)
    set_prop(bloom, "float", "Size", 30)
    set_prop(bloom, "float", "Threshold", 1.15)
    set_prop(bloom, "bool", "Enabled", True)

    dof = ensure_child(lighting, "DepthOfField", "DepthOfFieldEffect")
    set_prop(dof, "float", "FarIntensity", 0.18)
    set_prop(dof, "float", "FocusDistance", 28)
    set_prop(dof, "float", "InFocusRadius", 32)
    set_prop(dof, "float", "NearIntensity", 0)
    set_prop(dof, "bool", "Enabled", True)

    return changed[0]


# --------------------------------------------------------------------------- commands


def load(path):
    return ET.parse(path).getroot()


def cmd_extract():
    for place, path in PLACES.items():
        root = load(path)

        def dump(item, p):
            cls = item.get("class")
            if cls not in SCRIPT_CLASSES:
                return
            src = get_prop(item, "Source")
            text = (src.text or "") if src is not None else ""
            parts = p.strip("/").split("/")
            name = parts[-1]
            if parts[0] == "ReplicatedStorage":
                rel = f"src/shared/{name}.lua"
            elif parts[0] == "ServerScriptService" and len(parts) == 3:
                rel = f"src/server/Core/{name}.lua" if name != "MonsterAI" else f"src/{place}/server/Core/{name}.lua"
            elif parts[0] == "ServerScriptService":
                rel = f"src/{place}/server/{name}.server.lua"
            elif name == "Signs":
                rel = f"src/client/{name}.client.lua"
            else:
                rel = f"src/{place}/client/{name}.client.lua"
            out = os.path.join(ROOT, rel)
            os.makedirs(os.path.dirname(out), exist_ok=True)
            if os.path.exists(out):
                with open(out, encoding="utf-8") as fh:
                    if fh.read() != text:
                        sys.exit(f"conflict: {rel} differs between places")
            with open(out, "w", encoding="utf-8") as fh:
                fh.write(text)
            print(place, p, "->", rel)

        for it in root.findall("Item"):
            walk(it, dump)


def cmd_build():
    for place, path in PLACES.items():
        root = load(path)
        sync_scripts(root, place)
        n = upgrade_environment(root, place)
        write_place(root, path)
        print(f"{place}: {len(manifest(place))} scripts synced, {n} parts re-materialed -> {os.path.relpath(path, ROOT)}")


def cmd_sourcemap():
    """Minimal Rojo-style sourcemap so luau-lsp can resolve requires and instance paths."""
    for place, path in PLACES.items():
        root = load(path)

        def node(item):
            cls = item.get("class")
            n = {"name": name_of(item), "className": cls}
            kids = [node(k) for k in item.findall("Item") if k.get("class") not in ("Part", "SpecialMesh", "Weld", "SurfaceLight", "PointLight", "SpotLight", "StringValue", "Motor6D", "Attachment") or name_of(k) in ("HumanoidRootPart", "Head", "MenuCamera", "ShopPrompt", "PassPrompt", "SpawnLocation", "ExitZone", "Slot", "Door", "Inside")]
            if kids:
                n["children"] = kids
            return n

        files = {(c + "/" + n): f for c, _, n, f in manifest(place)}
        tree = {"name": "Game", "className": "DataModel", "children": [node(i) for i in root.findall("Item")]}

        def attach(n, p):
            full = f"{p}/{n['name']}".lstrip("/")
            key = full.split("/", 0)[0]
            if full in files:
                n["filePaths"] = [os.path.relpath(files[full], ROOT)]
            for k in n.get("children", []):
                attach(k, full)

        for s in tree["children"]:
            attach(s, "")
        with open(os.path.join(ROOT, f"sourcemap-{place}.json"), "w") as fh:
            json.dump(tree, fh)
        print("sourcemap", place)


if __name__ == "__main__":
    {"extract": cmd_extract, "build": cmd_build, "sourcemap": cmd_sourcemap}[sys.argv[1]]()
