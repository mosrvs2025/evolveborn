extends Node
## Global signal bus. Systems talk through here so nothing needs to know who is
## listening; the HUD, audio, FX and stats all hang off these.

# --- Echo (the player's internal analyst) -------------------------------------
signal echo_message(text: String, kind: String)      # kind: info / alert / discovery
signal echo_analysis(lines: Array)                   # multi-line devour readout

# --- Traits / build -----------------------------------------------------------
signal trait_discovered(trait_id: String)
signal loadout_changed()
signal synergy_discovered(synergy_id: String)
signal capacity_changed(used: int, total: int)

# --- Progression --------------------------------------------------------------
signal essence_changed(current: int, needed: int)
signal evolution_available()
signal evolved(form_id: String)

# --- Player -------------------------------------------------------------------
signal player_health_changed(current: float, maximum: float)
signal player_died()
signal player_respawned()
signal player_spawned(player: Node3D)

# --- World --------------------------------------------------------------------
signal creature_died(creature: Node3D)
signal creature_devoured(species_id: String, trait_id: String)
signal region_entered(region_id: String)
signal memory_pool_reached(pool_id: String)
signal secret_found(secret_id: String)
signal boss_phase_changed(phase: int)
signal boss_defeated()

# --- UI / shell ---------------------------------------------------------------
signal prompt_changed(text: String, action: String)  # empty text clears
signal input_device_changed(device: String)          # keyboard / gamepad / touch
signal settings_changed()
signal toast(text: String, color: Color)
signal request_state(state: String, payload: Dictionary)
