#!/usr/bin/env python3
"""Authoring source for EVOLVEBORN's content tables.

Every creature, trait and ability is a row here; this script writes them out as
Godot .tres Resources under data/. Edit the tables, re-run, commit both.

    python3 tools/gen_data.py
"""
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# --------------------------------------------------------------------------- #
# ABILITIES
# --------------------------------------------------------------------------- #
# shape: melee_arc | projectile | cone | aoe | dash | web | slam | beam
ABILITIES = [
 dict(id="body_slam", display_name="Body Slam", description="Throw your whole mass forward. It is all you have.",
      shape="melee_arc", damage=11, cooldown=0.46, range=2.7, angle_deg=125, lunge=2.4,
      knockback=6.5, windup=0.07, recovery=0.2, color=(0.72,0.86,1.0), sfx="slam", vfx="impact"),
 dict(id="shell_bash", display_name="Shell Bash", description="Hardened plates turn the slam into a battering ram.",
      shape="melee_arc", damage=17, cooldown=0.62, range=2.9, angle_deg=115, lunge=2.8,
      knockback=11.0, windup=0.11, recovery=0.26, color=(0.85,0.72,0.42), sfx="bash", vfx="impact",
      flags={"armor_pierce": 2.0}),
 dict(id="venom_strike", display_name="Venom Strike", description="The strike opens the skin so the toxin has somewhere to go.",
      shape="melee_arc", damage=9, cooldown=0.42, range=2.7, angle_deg=125, lunge=2.4,
      knockback=4.0, windup=0.06, recovery=0.18, status="poison", status_power=4.0, status_time=5.0,
      color=(0.58,0.95,0.42), sfx="slash", vfx="venom"),
 dict(id="shock_slam", display_name="Concussive Slam", description="A pressurised sac vents on impact and the air does the rest.",
      shape="melee_arc", damage=13, cooldown=0.55, range=2.7, angle_deg=140, lunge=2.2,
      knockback=14.0, windup=0.08, recovery=0.24, radius=4.2, color=(0.7,0.95,0.95), sfx="burst",
      vfx="shockwave", flags={"shockwave": 1.0}),
 dict(id="burst", display_name="Burst", description="Collapse and re-form a body length away.",
      shape="dash", damage=0, cooldown=1.05, speed=21.0, duration=0.2, iframes=0.2,
      color=(0.6,0.9,1.0), sfx="burst_move", vfx="burst"),
 dict(id="leap", display_name="Leap", description="Rear limbs fold and release. Height, and the time to aim with it.",
      shape="dash", damage=0, cooldown=0.85, speed=15.0, duration=0.18, iframes=0.14,
      color=(0.75,1.0,0.6), sfx="leap", vfx="burst", flags={"vertical": 9.5, "air_uses": 1.0}),
 dict(id="phase_slip", display_name="Phase Slip", description="Briefly stop being solid enough to hit.",
      shape="dash", damage=0, cooldown=1.0, speed=24.0, duration=0.24, iframes=0.42,
      color=(0.55,0.4,0.75), sfx="phase", vfx="smoke", flags={"phase": 1.0, "mark": 1.0}),
 dict(id="meteor_slam", display_name="Meteor Slam", description="All that plate, dropped from height, on purpose.",
      shape="dash", damage=34, cooldown=1.5, speed=17.0, duration=0.2, iframes=0.25, radius=5.4,
      knockback=16.0, color=(1.0,0.75,0.35), sfx="meteor", vfx="quake",
      flags={"vertical": 9.5, "air_uses": 1.0, "ground_pound": 1.0}),
 dict(id="flame_burst", display_name="Flame Burst", description="Vent the gland. Short range, immediate consequences.",
      shape="cone", damage=15, cooldown=2.2, range=6.0, angle_deg=55, duration=0.35,
      status="burn", status_power=5.0, status_time=3.0, knockback=3.0, windup=0.18,
      color=(1.0,0.55,0.2), sfx="flame", vfx="flame"),
 dict(id="flame_breath", display_name="Flame Breath", description="Pressure behind heat. It keeps going as long as you do.",
      shape="cone", damage=11, cooldown=4.0, range=11.0, angle_deg=40, duration=1.9,
      status="burn", status_power=7.0, status_time=4.0, knockback=2.0, windup=0.22,
      color=(1.0,0.45,0.12), sfx="flame_long", vfx="flame", flags={"sustained": 1.0, "tick": 0.18}),
 dict(id="arc_bolt", display_name="Arc Bolt", description="A charge that prefers the shortest path between bodies.",
      shape="projectile", damage=14, cooldown=1.5, range=22.0, speed=26.0, radius=0.5,
      status="shock", status_power=3.0, status_time=2.0, windup=0.14,
      color=(0.6,0.85,1.0), sfx="arc", vfx="spark", flags={"chain": 2.0, "chain_range": 7.0}),
 dict(id="plasma_arc", display_name="Plasma Arc", description="Heat rides the charge. Everything it touches keeps burning.",
      shape="projectile", damage=18, cooldown=1.6, range=24.0, speed=28.0, radius=0.7,
      status="burn", status_power=6.0, status_time=4.0, windup=0.14,
      color=(1.0,0.7,0.95), sfx="arc", vfx="spark", flags={"chain": 3.0, "chain_range": 8.0, "ignite": 1.0}),
 dict(id="web_shot", display_name="Web Shot", description="Silk, thrown. Whatever it lands on stops going anywhere.",
      shape="web", damage=4, cooldown=2.4, range=16.0, speed=20.0, radius=3.0, duration=4.0,
      status="root", status_power=1.0, status_time=2.6, windup=0.12,
      color=(0.9,0.95,0.85), sfx="web", vfx="web"),
 dict(id="conductive_web", display_name="Conductive Web", description="The silk holds them still and the charge finds them all.",
      shape="web", damage=6, cooldown=2.8, range=17.0, speed=20.0, radius=3.6, duration=5.0,
      status="shock", status_power=9.0, status_time=5.0, windup=0.12,
      color=(0.7,0.95,1.0), sfx="web", vfx="web_shock", flags={"electrified": 1.0, "tick": 0.5}),
 dict(id="primordial_burst", display_name="Primordial Surge", description="Something older than the Hollow, briefly awake in you.",
      shape="aoe", damage=45, cooldown=8.0, radius=9.0, knockback=18.0, windup=0.3,
      color=(1.0,0.95,0.7), sfx="evolve", vfx="quake"),
 # --- creature abilities ---
 dict(id="eel_arc", display_name="Static Discharge", shape="projectile", damage=9, cooldown=2.6,
      range=18.0, speed=17.0, radius=0.45, status="shock", status_power=2.0, status_time=1.5,
      windup=0.5, color=(0.6,0.85,1.0), sfx="arc", vfx="spark"),
 dict(id="toad_spit", display_name="Pressure Spit", shape="projectile", damage=11, cooldown=3.0,
      range=20.0, speed=15.0, radius=0.6, knockback=7.0, windup=0.6,
      color=(0.75,0.9,0.5), sfx="spit", vfx="goo"),
 dict(id="silk_shot", display_name="Snare", shape="web", damage=3, cooldown=4.5, range=15.0,
      speed=16.0, radius=2.4, duration=3.0, status="root", status_power=1.0, status_time=1.8,
      windup=0.5, color=(0.9,0.95,0.85), sfx="web", vfx="web"),
 dict(id="spore_burst", display_name="Spore Burst", shape="aoe", damage=8, cooldown=3.5, radius=4.0,
      status="poison", status_power=3.0, status_time=4.0, windup=0.55,
      color=(0.6,0.9,0.45), sfx="spore", vfx="spore"),
 dict(id="mite_charge", display_name="Ember Charge", shape="melee_arc", damage=7, cooldown=1.6,
      range=2.0, angle_deg=100, lunge=3.4, status="burn", status_power=2.0, status_time=2.0,
      windup=0.35, color=(1.0,0.6,0.3), sfx="slash", vfx="ember"),
 # --- boss ---
 dict(id="root_slam", display_name="Root Slam", shape="aoe", damage=22, cooldown=3.4, radius=5.5,
      knockback=12.0, windup=0.95, color=(0.65,0.4,0.25), sfx="quake", vfx="quake",
      flags={"telegraph": 1.0}),
 dict(id="limb_sweep", display_name="Sweeping Limb", shape="melee_arc", damage=18, cooldown=4.2,
      range=9.0, angle_deg=180, knockback=15.0, windup=0.8, color=(0.6,0.45,0.3),
      sfx="sweep", vfx="impact", flags={"telegraph": 1.0}),
 dict(id="seed_volley", display_name="Seed Volley", shape="projectile", damage=12, cooldown=4.0,
      range=30.0, speed=16.0, radius=0.7, windup=0.7, color=(0.8,0.75,0.4), sfx="spit",
      vfx="goo", flags={"volley": 5.0, "spread": 26.0}),
 dict(id="devourer_charge", display_name="Consuming Charge", shape="dash", damage=26, cooldown=6.0,
      speed=22.0, duration=0.9, radius=3.0, knockback=16.0, windup=1.0,
      color=(0.7,0.3,0.4), sfx="charge", vfx="quake", flags={"telegraph": 1.0, "damage_on_contact": 1.0}),
 dict(id="corrupt_wave", display_name="Corrupting Wave", shape="aoe", damage=16, cooldown=5.0,
      radius=13.0, windup=1.3, status="poison", status_power=5.0, status_time=5.0,
      color=(0.55,0.25,0.6), sfx="wave", vfx="spore", flags={"telegraph": 1.0, "ring": 1.0}),
]

# --------------------------------------------------------------------------- #
# TRAITS
# --------------------------------------------------------------------------- #
TRAITS = [
 dict(id="chitin_armor", display_name="Chitin Armor", core_cost=3, trait_type="hybrid",
      description="Interlocking plates grow over the membrane. Physical damage reduced 30%. Slightly slower.",
      stat_modifiers={"phys_resist": 0.30, "move_speed": -0.06, "knockback_resist": 0.5, "max_health": 0.10},
      active_ability="shell_bash", ability_slot="primary", visual_mutation="plates",
      synergy_tags=["armor", "physical"], color=(0.85,0.7,0.4),
      echo_note="Structural lattice. It will cost you speed and give it back as time."),
 dict(id="regenerative_tissue", display_name="Regenerative Tissue", core_cost=4, trait_type="passive",
      description="Wounds close on their own. Health returns steadily, faster out of combat.",
      stat_modifiers={"regen": 1.5, "max_health": 0.18},
      visual_mutation="veins", synergy_tags=["vital", "organic"], color=(0.5,0.95,0.6),
      echo_note="Tissue that refuses to stay damaged. Expensive to keep running."),
 dict(id="heat_gland", display_name="Heat Gland", core_cost=3, trait_type="active",
      description="An internal furnace. Grants Flame Burst on the secondary action.",
      stat_modifiers={"ability_power": 0.08},
      active_ability="flame_burst", ability_slot="secondary", visual_mutation="heat_core",
      synergy_tags=["heat", "energy"], color=(1.0,0.55,0.2),
      echo_note="Exothermic organ. Contained, for now."),
 dict(id="power_legs", display_name="Power Legs", core_cost=2, trait_type="hybrid",
      description="Folded rear limbs. Faster, and Burst becomes a Leap you can steer in the air.",
      stat_modifiers={"move_speed": 0.13, "air_control": 0.35},
      active_ability="leap", ability_slot="mobility", visual_mutation="haunches",
      synergy_tags=["mobility", "kinetic"], color=(0.75,1.0,0.55),
      echo_note="Stored tension. Cheap, and it changes every room you enter."),
 dict(id="echo_sense", display_name="Echo Sense", core_cost=2, trait_type="passive",
      description="Sensory antennae. Creatures are outlined through terrain, strikes track better, and Devour yields more.",
      stat_modifiers={"detect_range": 0.6, "essence_mult": 0.2, "assist": 0.35},
      visual_mutation="antennae", synergy_tags=["sense", "psychic"], color=(0.6,0.85,1.0),
      flags={"reveal": 1.0},
      echo_note="You are hearing shapes. I can work with that."),
 dict(id="toxin_gland", display_name="Toxin Gland", core_cost=3, trait_type="hybrid",
      description="Toxic sacs. The primary strike becomes Venom Strike and everything you hit keeps taking damage.",
      stat_modifiers={},
      active_ability="venom_strike", ability_slot="primary", visual_mutation="sacs",
      synergy_tags=["toxin", "organic"], color=(0.6,0.95,0.4),
      flags={"on_hit_status": "poison", "on_hit_power": 3.0, "on_hit_time": 4.0},
      echo_note="A delivery system looking for something to deliver."),
 dict(id="electrical_organ", display_name="Electrical Organ", core_cost=3, trait_type="active",
      description="Stacked cells hold a charge. Grants Arc Bolt, which jumps between bodies.",
      stat_modifiers={"ability_power": 0.05},
      active_ability="arc_bolt", ability_slot="secondary", visual_mutation="arcs",
      synergy_tags=["shock", "energy"], color=(0.65,0.9,1.0),
      echo_note="Potential difference, biologically maintained. Do not hold it too long."),
 dict(id="shadow_membrane", display_name="Shadow Membrane", core_cost=2, trait_type="hybrid",
      description="You stop being entirely present. Burst becomes Phase Slip, longer invulnerability, and creatures notice you later.",
      stat_modifiers={"dodge_iframes": 0.12},
      active_ability="phase_slip", ability_slot="mobility", visual_mutation="smoke",
      synergy_tags=["shadow", "sense"], color=(0.55,0.42,0.78),
      flags={"aggro_reduce": 0.35},
      echo_note="Partial phase displacement. I cannot tell where the rest of you goes."),
 dict(id="pressurized_sac", display_name="Pressurized Sac", core_cost=2, trait_type="hybrid",
      description="A bladder that vents on impact. The primary strike gains a shockwave and heavy knockback.",
      stat_modifiers={"knockback": 0.5},
      active_ability="shock_slam", ability_slot="primary", visual_mutation="bladder",
      synergy_tags=["kinetic", "heat"], color=(0.7,0.95,0.95),
      echo_note="It is holding more than it should. That is the point."),
 dict(id="web_gland", display_name="Web Gland", core_cost=3, trait_type="active",
      description="Spinnerets. Grants Web Shot, which holds whatever it lands on in place.",
      stat_modifiers={},
      active_ability="web_shot", ability_slot="secondary", visual_mutation="spinnerets",
      synergy_tags=["silk", "shock"], color=(0.92,0.95,0.88),
      echo_note="Tensile protein. Conductive, incidentally."),
]

# --------------------------------------------------------------------------- #
# CREATURES
# --------------------------------------------------------------------------- #
CREATURES = [
 dict(id="moss_grazer", display_name="Moss Grazer", max_health=30, damage=5, move_speed=2.2,
      behavior="grazer", aggro_range=8.0, attack_range=1.8, attack_cooldown=2.2, attack_windup=0.5,
      essence_reward=8, trait_reward="regenerative_tissue", body_plan="grazer_quad", body_scale=1.0,
      color_primary=(0.42,0.55,0.36), color_secondary=(0.72,0.85,0.55), glow=(0.35,0.9,0.5,0.35),
      species_tags=["prey","grazer","organic"], fears=["predator"], voice="grazer",
      description="Wide, patient, and entirely uninterested in you until you touch it."),
 dict(id="ember_mite", display_name="Ember Mite", max_health=22, damage=7, move_speed=4.6,
      behavior="aggressor", aggro_range=13.0, attack_range=2.0, attack_cooldown=1.5, attack_windup=0.35,
      ranged_ability="mite_charge", essence_reward=10, trait_reward="heat_gland", body_plan="mite",
      body_scale=0.8, color_primary=(0.35,0.16,0.12), color_secondary=(1.0,0.5,0.2),
      glow=(1.0,0.45,0.15,0.9), species_tags=["predator","insect","heat"], diet=["prey"],
      voice="mite", description="It runs hot enough that the ground remembers where it stood."),
 dict(id="shellback", display_name="Shellback", max_health=75, damage=12, armor=4.0, move_speed=1.9,
      behavior="territorial", aggro_range=9.0, attack_range=2.4, attack_cooldown=2.6, attack_windup=0.65,
      essence_reward=16, trait_reward="chitin_armor", body_plan="beetle", body_scale=1.25,
      color_primary=(0.32,0.26,0.2), color_secondary=(0.85,0.7,0.4), glow=(0.9,0.6,0.2,0.25),
      species_tags=["armored","insect"], voice="shell",
      description="Armour first. It does not chase far, but it does not give ground either."),
 dict(id="sporeling", display_name="Sporeling", max_health=36, damage=8, move_speed=1.6,
      behavior="territorial", aggro_range=7.5, attack_range=3.6, attack_cooldown=3.2, attack_windup=0.55,
      ranged_ability="spore_burst", essence_reward=11, trait_reward="toxin_gland", body_plan="fungal",
      body_scale=1.05, color_primary=(0.36,0.3,0.42), color_secondary=(0.72,0.95,0.5),
      glow=(0.5,1.0,0.45,0.7), species_tags=["fungal","toxic"], voice="spore",
      description="It does not hunt. It waits, and then the air is the problem."),
 dict(id="rift_bat", display_name="Rift Bat", max_health=26, damage=8, move_speed=5.4,
      behavior="flyer", aggro_range=15.0, attack_range=2.2, attack_cooldown=2.4, attack_windup=0.3,
      essence_reward=12, trait_reward="echo_sense", body_plan="bat", body_scale=0.9,
      color_primary=(0.22,0.2,0.3), color_secondary=(0.6,0.55,0.9), glow=(0.55,0.6,1.0,0.6),
      flies=True, hover_height=3.4, species_tags=["predator","flyer"], diet=["prey","insect"],
      voice="bat", description="It sees in pulses, and it is very sure of where you are."),
 dict(id="thorn_hopper", display_name="Thorn Hopper", max_health=42, damage=11, move_speed=4.0,
      behavior="leaper", aggro_range=14.0, attack_range=2.2, attack_cooldown=2.0, attack_windup=0.4,
      essence_reward=14, trait_reward="power_legs", body_plan="hopper", body_scale=1.0,
      color_primary=(0.3,0.42,0.24), color_secondary=(0.85,0.95,0.5), glow=(0.7,1.0,0.4,0.4),
      species_tags=["predator","kinetic"], diet=["prey","insect"], voice="hopper",
      description="Three body lengths a jump. Closing distance is not your decision to make."),
 dict(id="spark_eel", display_name="Spark Eel", max_health=34, damage=9, move_speed=3.6,
      behavior="ranged", aggro_range=17.0, attack_range=13.0, attack_cooldown=2.6, attack_windup=0.5,
      ranged_ability="eel_arc", essence_reward=15, trait_reward="electrical_organ", body_plan="eel",
      body_scale=1.0, color_primary=(0.15,0.3,0.4), color_secondary=(0.6,0.95,1.0),
      glow=(0.5,0.9,1.0,1.0), flies=True, hover_height=1.7,
      species_tags=["shock","aquatic"], voice="eel",
      description="It swims through air the way it swims through water, and it is always charged."),
 dict(id="shadecrawler", display_name="Shadecrawler", max_health=50, damage=14, move_speed=4.2,
      behavior="ambusher", aggro_range=16.0, attack_range=2.3, attack_cooldown=2.2, attack_windup=0.32,
      essence_reward=19, trait_reward="shadow_membrane", body_plan="crawler", body_scale=1.1,
      color_primary=(0.14,0.12,0.2), color_secondary=(0.5,0.35,0.7), glow=(0.5,0.3,0.8,0.5),
      species_tags=["predator","shadow"], diet=["prey","insect","flyer"], voice="crawler",
      description="You will find it by being wrong about where it was."),
 dict(id="bellow_toad", display_name="Bellow Toad", max_health=58, damage=10, move_speed=2.4,
      behavior="ranged", aggro_range=15.0, attack_range=12.0, attack_cooldown=3.0, attack_windup=0.6,
      ranged_ability="toad_spit", essence_reward=17, trait_reward="pressurized_sac", body_plan="toad",
      body_scale=1.2, color_primary=(0.3,0.4,0.3), color_secondary=(0.8,0.9,0.55),
      glow=(0.6,0.95,0.5,0.3), species_tags=["prey","amphibian"], fears=["predator"], voice="toad",
      description="It inflates before it spits. That is the whole tell, and it is enough."),
 dict(id="silk_weaver", display_name="Silk Weaver", max_health=46, damage=11, move_speed=3.4,
      behavior="ambusher", aggro_range=14.0, attack_range=10.0, attack_cooldown=3.6, attack_windup=0.5,
      ranged_ability="silk_shot", essence_reward=17, trait_reward="web_gland", body_plan="spider",
      body_scale=1.0, color_primary=(0.26,0.22,0.26), color_secondary=(0.9,0.92,0.86),
      glow=(0.85,0.9,1.0,0.3), species_tags=["predator","silk"], diet=["prey","insect"],
      voice="weaver", description="It would rather you stopped moving first."),
 dict(id="grove_sentinel", display_name="Grove Sentinel", max_health=210, damage=20, armor=6.0,
      move_speed=2.6, behavior="territorial", aggro_range=13.0, attack_range=3.4,
      attack_cooldown=2.8, attack_windup=0.8, ranged_ability="root_slam",
      essence_reward=60, trait_reward="", body_plan="sentinel", body_scale=1.9,
      color_primary=(0.28,0.34,0.26), color_secondary=(0.9,0.85,0.5), glow=(0.8,0.95,0.4,0.55),
      species_tags=["elite","armored","flora"], voice="sentinel",
      flags={"elite": 1.0},
      description="Older than the basin's current inhabitants, and it has outlived all of them."),
]

# --------------------------------------------------------------------------- #
# writer
# --------------------------------------------------------------------------- #
def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int,)):
        return str(v)
    if isinstance(v, float):
        return repr(round(v, 4))
    if isinstance(v, str):
        return '"%s"' % v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    if isinstance(v, tuple):
        c = list(v) + [1.0] * (4 - len(v))
        return "Color(%s)" % ", ".join(repr(round(float(x), 4)) for x in c[:4])
    if isinstance(v, list):
        return "PackedStringArray(%s)" % ", ".join(fmt(x) for x in v)
    if isinstance(v, dict):
        if not v:
            return "{}"
        inner = ",\n".join('%s: %s' % (fmt(k), fmt(val)) for k, val in v.items())
        return "{\n%s\n}" % inner
    raise TypeError(repr(v))

def write(kind, script, rows, subdir):
    out_dir = os.path.join(ROOT, "data", subdir)
    os.makedirs(out_dir, exist_ok=True)
    for f in os.listdir(out_dir):
        if f.endswith(".tres"):
            os.remove(os.path.join(out_dir, f))
    for row in rows:
        lines = ['[gd_resource type="Resource" script_class="%s" load_steps=2 format=3]' % kind, "",
                 '[ext_resource type="Script" path="res://data/%s" id="1_s"]' % script, "",
                 "[resource]", 'script = ExtResource("1_s")']
        for k, v in row.items():
            lines.append("%s = %s" % (k, fmt(v)))
        path = os.path.join(out_dir, row["id"] + ".tres")
        with open(path, "w") as fh:
            fh.write("\n".join(lines) + "\n")
    print("  %-10s %d files -> data/%s/" % (kind, len(rows), subdir))

if __name__ == "__main__":
    print("EVOLVEBORN data generation")
    write("AbilityData", "ability_data.gd", ABILITIES, "abilities")
    write("TraitData", "trait_data.gd", TRAITS, "traits")
    write("CreatureData", "creature_data.gd", CREATURES, "creatures")
    ids = [a["id"] for a in ABILITIES]
    for t in TRAITS:
        if t.get("active_ability") and t["active_ability"] not in ids:
            sys.exit("trait %s references missing ability %s" % (t["id"], t["active_ability"]))
    for c in CREATURES:
        if c.get("ranged_ability") and c["ranged_ability"] not in ids:
            sys.exit("creature %s references missing ability %s" % (c["id"], c["ranged_ability"]))
    print("  cross-references ok")
