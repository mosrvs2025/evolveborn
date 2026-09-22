# EVOLVEBORN

An original, standalone Godot 4.7.1 / GDScript browser action RPG. Start as a Wisp, hunt eight species, Devour their adaptations, configure a capacity-limited body, evolve, and confront the Root Devourer.

## Play

- **Vercel:** https://evolveborn.vercel.app
- **GitHub Pages:** https://mosrvs2025.github.io/evolveborn/
- **Windows:** download the executable from the GitHub release, or run this project in Godot.

The game needs WebGL 2. Once loaded, gameplay has no network dependency. Progress is stored locally in the browser's IndexedDB-backed Godot user filesystem. Clearing site data clears the save. Saves are separate for each hosting origin and the Windows version.

## Controls

| Action | Keyboard | One hand | Controller |
|---|---|---|---|
| Move | WASD / arrows | arrows | left stick |
| Primary | left mouse / 0 | numpad 0 | X / Square |
| Secondary | right mouse / Enter | numpad Enter | Y / Triangle |
| Burst | Space / Shift | Space / Shift | A / Cross |
| Hold Devour | E / Ctrl | Ctrl | B / Circle |
| Recenter | period | period | left shoulder |
| Body | Tab / HUD button | remappable | View / Back |
| Pause | Escape / HUD button | remappable | Menu / Start |
| Camera | middle-mouse drag | Smart Camera | right stick |

Touch has a floating left joystick, right-side camera drag, large action buttons, and a contextual Devour button. Keyboard bindings, hold/toggle Devour, camera sensitivity, inversion, target assistance, captions, numbers, audio, motion, shake, quality, and touch settings are configurable.

## Progression

Explore five connected chambers. Consume three local organisms to cross each living membrane; the Ancient Nest additionally requires evolution. Memory Pools heal, checkpoint, and enable evolution at 180 Essence. Eight traits cost between two and four Core points. The Wisp has nine points, Predator and Bulwark thirteen, and Arcane sixteen. Five pairings unlock synergies. Death preserves discoveries, the equipped body, essence, and evolution. The boss has three phases and copies an equipped adaptation in its last phase. Devouring its fragment triggers the ending, statistics, replay, and continued exploration.

## Development

Install **Godot 4.7.1 stable**, including its export templates. Open `project.godot`, or:

```sh
godot --headless --editor --import --quit
godot --headless -- --self-test
godot --path .
mkdir -p build/web
godot --headless --export-release Web
```

Serve `build/web` through an HTTP server, not `file://`. The single-threaded Compatibility export needs no cross-origin isolation headers. `vercel.json` serves a pre-exported `build/web` directory. The GitHub Actions workflow independently installs Godot, validates the source, exports, and publishes Pages on pushes to `main`.

Windows: create `build/windows`, then `godot --headless --export-release Windows`. The executable embeds its PCK.

## Structure

- `data/`: typed CreatureData, TraitData and AbilityData Resources plus individual `.tres` definitions.
- `player/`: acceleration, physics, burst, animation and visible adaptations.
- `creatures/`: readable AI states, ecosystem hunting, telegraphs, statuses and boss phases.
- `world/`: deterministic authored region dressing, adjacent-region streaming and terrain shader.
- `systems/`: action mapping, versioned local saves, original procedural audio.
- `ui/`: HUD, body, evolution, settings, remapping and touch controls.
- `game.gd`: run progression, combat resolution and integration checks.

No external art, audio, font, API, account or gameplay service is required. Geometry, shader work, sound effects, and the tonal music bed are original procedural content.

## Validation and limits

Automated checks cover real movement/attack/held-Devour input, trait capacity, synergy, evolution, death recovery, boss victory, ending state, and disk save/load. Desktop and emulated mobile browsers are visually checked for launch, layout, menus, and console errors.

This is the first playable implementation of the brief. The 20–40 minute first-play target and subjective balance need human playtesting; they are not validated timing guarantees. Real iOS/Android hardware and physical gamepads have not been tested. Art and music are procedural and modest in scope. Quick-swap loadout slots are not included. The five chambers follow a linear main route with optional relic alcoves; they are not a large open world.

## Two builds

There are two EVOLVEBORN projects in this repository, both published from the
one GitHub Pages site, and neither replaces the other:

| | Where it lives | Plays at |
|---|---|---|
| Original (Godot 4.7.1) | repository root | https://mosrvs2025.github.io/evolveborn/ |
| Vertical slice (Godot 4.3) | `slice/` | https://mosrvs2025.github.io/evolveborn/slice/ |

The slice is a separate, larger implementation of the same design: five
regions, ten adaptations, six synergies, three evolutions, the Root Devourer
and an ending, with all art and audio generated at build time. See
`slice/README.md` for it and `slice/README-DEPLOY.md` for how the two are kept
apart. Its full history is on the `vertical-slice` branch.
