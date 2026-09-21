# EVOLVEBORN — first playable release

- Play: https://evolveborn.vercel.app
- Source: https://github.com/mosrvs2025/evolveborn
- Pages mirror: https://mosrvs2025.github.io/evolveborn/
- Windows releases: https://github.com/mosrvs2025/evolveborn/releases

Built with Godot 4.7.1 stable, GDScript, Compatibility renderer, single-threaded WebAssembly. The compressed engine transfer is substantially smaller than its approximately 39.5 MB uncompressed WASM size; game-specific packed data is approximately 100 KB.

Validated: headless input/combat/Devour integration, capacity enforcement, trait synergies, all evolution prerequisites, boss phase transitions and victory, ending trigger, respawn retention, save-file round trip, browser reload persistence, desktop layout, emulated mobile portrait and landscape layouts, and an empty browser runtime error log.

Not yet validated: 20–40 minute first-play pacing, physical controllers, real mobile hardware, and broad hardware performance. See README for scope and controls.

Vercel serves the locally tested export. GitHub Pages rebuilds from source through the included GitHub Actions workflow. To update Vercel after exporting, run `vercel deploy build/web --prod --scope moeflows-projects`.
