"""Print enum items from the Roblox API dump: python3 enum_values.py Material Technology ..."""
import json
import sys

dump = json.load(open(sys.argv[1]))
wanted = set(sys.argv[2:])
for e in dump["Enums"]:
    if e["Name"] in wanted:
        print(e["Name"], {i["Name"]: i["Value"] for i in e["Items"]})
