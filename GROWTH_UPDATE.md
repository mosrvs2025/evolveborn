# The world is food — v0.2 working build

Implemented locally in response to the growth direction. Public v0.1 remains available; this revision has not yet been pushed or deployed.

## The new loop

**Absorb → grow → unlock larger food → mutate your appetite → revisit a smaller-feeling world.**

- Start at 0.75 m wide; grow beyond 10 m. Growth uses cube-root volume, so larger meals matter more as the slime becomes huge.
- 240 authored, deterministically placed edible objects across five chambers: dew, seeds, fungi, crystals, boulders, trees, ancient pillars, and elder roots.
- Objects retain their world size. The slime's body and collision shape grow, the camera pulls back, and larger sightlines reveal more of the Hollow.
- Oversized food physically blocks the slime and displays the required size. Eligible food spirals into its body and briefly leaves colored morsels in the membrane.
- Creatures become prey you can swallow whole once outgrown. Larger threats still use the combat-and-Devour loop.
- Secondary action combines a special attack with a short inhale pulse.
- Armor digests minerals earlier; heat and venom digest plants earlier; Echo expands absorption radius; electricity attracts minerals; regeneration improves biomass yield.
- Abilities change with size: Body Slam → Rolling Crush → Seismic Bellyflop; electrical attacks chain to more targets; enormous flame and venom attacks spread around the body.
- Save/load and death preserve growth and consumed scenery. New-run resets both. Existing v0.1 saves migrate without losing traits or evolution.

## Checks

The headless integration suite passes the existing combat/Devour/evolution/boss tests plus growth volume, food thresholds, appetite modifiers, growth save snapshots, attack upgrades, and enough accessible food to clear every chamber's size requirement.

Browser visual checks cover starter absorption, the new size HUD, an 11 m growth stage, automatic scenery intake, upgraded abilities, and camera pullback. Balance and pacing are still experimental.

## Publishing status

An automatic approval review failed because of an account usage limit during the previous turn's final Pages verification. The failure was not a finding that the action was unsafe. Local development continued; publishing this revision requires restored approval-review availability. No alternate route was used to bypass that review failure.
