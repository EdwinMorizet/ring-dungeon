# Rings/Bands Smoke Checklist

Use this checklist for a fast in-editor validation pass.

## Preconditions

1. Open the project in Godot 4.6.
2. Run the main scene.
3. Ensure the debug floor HUD is visible in the top-left.

## A. Debug Hook Validation

1. Press F6 once.
2. Expected:
- 8 world items spawn around the player.
- Items have ring/band visuals with rarity-tinted glow.

3. Press F7 once.
4. Expected:
- Console prints a summary block beginning with `[RingsBands] Equipped Summary`.
- Aggregate keys are present: `damage_mult`, `mana_cost_mult`, `proj_speed_mult`, `cast_delay_mult`, `accuracy_deviation_flat`, `bounce_chance`, `split_flat`, `pierce_chance`, `aoe_radius_flat`, `max_hp_flat`, `max_mp_flat`, `max_ap_slots`, `speed_mult`, and active trait keys.

## B. Inventory Tooltip Validation

1. Open inventory.
2. Hover a nearby item entry.
3. Expected tooltip order:
- Header: name, rarity, type.
- Benefits section.
- Trade-Offs section.
- Optional Special Trait.
- Footer: gold value and slot compatibility hint.

4. Equip an item in a valid slot and hover its slot button.
5. Expected:
- Slot tooltip uses the same formatting as nearby item tooltip.
- Slot label shows item name and rarity in text.

## C. Slot Rule Validation

1. Try dragging a ring to a left-hand slot.
2. Expected: drop rejected.

3. Try dragging a band to a right-hand slot.
4. Expected: drop rejected.

5. Equip item into an occupied valid slot.
6. Expected:
- Existing item is dropped back into the world.
- New item is equipped.

## D. Seeded Drop Determinism (Manual Spot Check)

1. Press F6 to spawn debug items.
2. Record first 2-3 item names/rarities.
3. Restart scene and repeat F6 at similar start state.
4. Expected:
- Spawn pattern and generated item profile are consistent for same seed/depth path.

## E. Fireball Runtime Behavior Validation

1. Equip ring(s) that alter mana cost, cast delay, spread, bounce/split/pierce, and AoE when available.
2. Fire repeatedly at enemy and wall targets.
3. Expected:
- Mana consumption reflects modifier changes.
- Fireball triggers on left mouse single click.
- Fire cadence changes with cast-delay modifiers but never reaches zero-delay spam.
- Spread tightens for negative accuracy deviation and widens for positive deviation.
- Bounce/pierce/split effects visibly apply.

## F. AP Slot And Active Trait Validation

1. Start a run with no AP-slot bands equipped.
2. Expected:
- AP gauge is hidden.
- Enemy hit damages HP directly.

3. Equip a band with AP slot bonus and receive enemy hits.
4. Expected:
- AP gauge becomes visible.
- Each enemy hit consumes one filled AP slot and ignores that hit.
- AP slots do not regenerate passively.

5. Equip speed/heal/shield active bands.
6. Expected:
- Right mouse single click triggers speed burst.
- Right mouse long press channels heal/shield effects while held.
- Long/single active effects respect mana and cooldowns.

## G. Explosion Interaction Validation

1. Create a setup with bounce/pierce available.
2. Hit non-terminal collisions first.
3. Expected:
- Lesser explosion occurs while continuation resources remain.

4. Force terminal collision with no continuation resources.
5. Expected:
- Greater explosion occurs and projectile is freed.

6. Trigger explosion near player.
7. Expected:
- Lesser explosions do not self-damage.
- Greater explosions apply reduced self-damage only.

## H. Transition Hygiene Validation

1. Leave floor to merchant and return to next floor.
2. Expected:
- Old world items are cleared.
- No stale nearby-item references remain in inventory UI.

## Pass Criteria

1. No script/runtime errors in console.
2. All expected behaviors in sections A-H are observed.
3. No hard-locks, projectile runaway loops, or broken inventory interactions.
