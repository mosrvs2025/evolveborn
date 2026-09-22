#!/usr/bin/env python3
"""Sets WAV import options Godot cannot infer: music loops, and QOA compression
so the browser download stays small. Run after generating or adding audio.

    python3 tools/make_audio.py && python3 tools/set_audio_import.py
"""
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def patch(path, loop):
    with open(path) as f:
        lines = f.read().splitlines()
    out = []
    for line in lines:
        if line.startswith("compress/mode="):
            line = "compress/mode=2"          # QOA
        elif line.startswith("edit/loop_mode="):
            line = "edit/loop_mode=%d" % (1 if loop else 0)
        out.append(line)
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")

count = 0
for folder, loop in [("music", True), ("sfx", False)]:
    d = os.path.join(ROOT, "audio", folder)
    if not os.path.isdir(d):
        continue
    for name in sorted(os.listdir(d)):
        if name.endswith(".wav.import"):
            patch(os.path.join(d, name), loop)
            count += 1
print("patched %d import files" % count)
if count == 0:
    sys.exit("no .import files found - run the Godot import first")
