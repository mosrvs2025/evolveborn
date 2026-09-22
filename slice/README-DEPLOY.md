# The vertical slice, deployed beside the original

This directory is a **second, self-contained Godot project** — a larger
EVOLVEBORN built from the same spec, on Godot 4.3 rather than 4.7.1. It is kept
next to the original rather than replacing it, and both are published from the
one GitHub Pages site:

- `/` — the original build, exported from the repository root by
  `.github/workflows/pages.yml` on every push.
- `/slice/` — this one, served from the pre-exported `slice/docs/` that the
  same workflow copies into the site.

The empty `.gdignore` beside this file is what keeps the two projects apart:
Godot skips any directory containing one, so the root project's import and
export steps never see this tree.

Re-exporting this build needs Godot 4.3 and its web export templates:

```bash
cd slice
bash tools/export_web.sh    # writes slice/docs/, which is what gets published
```

Its own source, tests and build notes are documented in `slice/README.md`.
Full history for it is on the `vertical-slice` branch.
