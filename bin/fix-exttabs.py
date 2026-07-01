#!/usr/bin/env python3
#
# Re-indent the ExtConfig block of a Helix Core extension spec with tabs.
#
# The p4d extension spec expects the lines below "ExtConfig:" to be indented
# with tab characters: one tab for a setting name (ending in a colon) and two
# tabs for its value. Some editors or copy/paste steps replace those tabs with
# spaces, which p4d silently ignores, leaving the extension misconfigured.
#
# This filter restores the tabs. It reads the spec on stdin and writes the
# corrected spec to stdout, so it drops into the p4 pipeline:
#
#   p4 extension --configure Auth::loginhook -o \
#     | python3 fix-exttabs.py \
#     | p4 extension --configure Auth::loginhook -i
#
# Indentation is classified by relative depth rather than an exact space count:
# the shallowest indent used in the block is treated as a setting name, and any
# line indented markedly deeper (>= 1.5x that) is treated as a value. This is
# robust to inconsistent space counts and is a no-op on already-correct input.
#
# Copyright 2026, Perforce Software Inc. All rights reserved.
#
import sys

lines = sys.stdin.read().splitlines()

# Pass 1: find the shallowest indent used in the ExtConfig block.
in_block, widths = False, []
for line in lines:
    if line.startswith("ExtConfig:"):
        in_block = True
        continue
    if in_block:
        if line and not line[:1].isspace():   # a column-0 line ends the block
            in_block = False
            continue
        if line.strip():
            widths.append(len(line) - len(line.lstrip(" \t")))
base = min(widths) if widths else 1
threshold = base * 1.5                          # names ~= base, values ~= 2*base

# Pass 2: rewrite each block line with 1 tab (name) or 2 tabs (value).
out, in_block = [], False
for line in lines:
    out.append(line)
    if line.startswith("ExtConfig:"):
        in_block = True
        continue
    if in_block:
        if line and not line[:1].isspace():
            in_block = False
            continue
        if not line.strip():
            continue
        width = len(line) - len(line.lstrip(" \t"))
        out[-1] = ("\t\t" if width >= threshold else "\t") + line.strip()

sys.stdout.write("\n".join(out) + "\n")
