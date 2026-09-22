# EVOLVEBORN

A browser-playable 3D action RPG about becoming what you eat.

You wake in a cave as a small, weak organism with no abilities and no memory.
Everything living in the Hollow is stronger than you are. The only way forward
is to hunt something, devour its corpse, and grow its body part onto your own.

**START WEAK → HUNT → DEVOUR → ADAPT → EVOLVE → BECOME POWERFUL**

This repository is a complete vertical slice: a first playthrough runs about
20–40 minutes, start to finish, with a beginning, a boss and an ending.

## Play

Served from `docs/` by GitHub Pages: **https://mosrvs2025.github.io/evolveborn/**

Nothing to install, no account, no server. Progress saves in the browser.

## Controls

Every action is an `InputMap` action, and three schemes are live at the same
time — you can switch hands mid-fight without touching a menu. On-screen
prompts follow whichever device you last used.

| | One hand | Standard | Controller |
|---|---|---|---|
| Move | arrow keys | W A S D | left stick |
| Camera | `,` `/` | mouse | right stick |
| Recenter | `.` | Q | right stick click |
| Primary | `0` / numpad `0` | left mouse | X |
| Secondary | Enter | right mouse | Y |
| Mobility | Space / Shift | Space | A |
| Devour / interact | Right Ctrl / `\` | E | B |
| Body menu | `-` | Tab | back |
| Pause | Esc | Esc | start |

The whole game is playable one-handed from the arrow cluster, attacking
included. On a phone the touch HUD appears on its own: a forgiving floating
joystick on the left, large action buttons on the right, camera by dragging
anywhere on the right half. Every binding can be remapped in CONTROLS, which
also carries STANDARD / ONE-HAND / CONTROLLER presets.

## The three systems that matter

**DEVOUR.** Kill something and its corpse stays where it fell. Hold devour
over it and the body is pulled apart into you, with a readout naming what your
core just learned. That trait is now yours to equip.

**TRAIT COMBINATIONS.** Ten adaptations, each with a core cost, and a core
that cannot hold all of them. Six pairs do something neither does alone —
Electrical Organ with Web Gland is a conductive net, Heat Gland with a
Pressurized Sac is a breath weapon, Chitin with Power Legs is a meteor slam.
Nothing announces them in advance; the Body menu tells you once you find one.

**EVOLUTION.** Essence accrues from everything you kill and everything you
eat. At a Memory Pool a full meter opens three forms — Predator, Arcane,
Bulwark — each of which rewrites your body, your capacity and how the game
plays. One per run.

## The Hollow

Five connected regions: the Awakening Cavern teaches, the Fungal Grotto adds
poison and verticality, the Sunken Ruins add range and hidden chambers, the
Verdant Basin is an open ecosystem where creatures graze, flee, hunt and fight
each other whether or not you are watching, and the Ancient Nest holds the
Root Devourer, which eats what you left behind and grows it, then studies you
and copies what you are.

## Building it

Godot 4.3 stable, GDScript, `gl_compatibility` renderer, no addons, no
imported art or audio assets at all. Every mesh is welded from primitives at
runtime; every sound is synthesised.

```bash
godot --path .                                  # run it
godot --headless --path . tests/core_tests.tscn # 363 checks: data, builds, input, saves
godot --headless --path . tests/playthrough.tscn # 107 checks: every region, the boss, an ending
bash tools/export_web.sh                        # export into docs/ for Pages
```

The web export must stay the **single-threaded** variant: GitHub Pages cannot
send the COOP/COEP headers the threaded build needs.

Regenerating content:

```bash
python3 tools/gen_data.py     # writes data/*/*.tres from the authoring tables
python3 tools/make_audio.py   # synthesises every sound and music loop
python3 tools/set_audio_import.py
```

## Layout

```
autoload/    signal bus, settings, saves, input, audio, content DB, FX, run state
data/        TraitData / AbilityData / CreatureData resources (generated)
traits/      Loadout — capacity, modifiers, synergies, the whole build system
player/      body, movement, devour, camera rig, procedural visuals
creatures/   one AI for every species; corpses
abilities/   one dispatcher for every ability shape
world/       region layouts as data, terrain generation, props, pools, gates
boss/        the Root Devourer and its three phases
ui/          HUD, body menu, pools, evolution, settings, touch, endings
tests/       two headless suites
tools/       content, audio and export scripts
```

Content is data. Adding a creature is a row in `tools/gen_data.py` and a body
plan in `core/proc_creature.gd`; adding a trait is a row and, if it grants an
ability, an entry in the ability table. Nothing in the engine code knows the
name of any particular creature.

## Developer tools

Hidden in the release build. Append `?debug=1` to the URL, then F3 for the
readout (frame rate, draw calls, creature count, position) and F4–F10 for
heal, kill, every trait, next region, essence, the nest, and wiping the save.
`?god=1`, `?traits=1` and `?region=<id>` start a run where you need it.
