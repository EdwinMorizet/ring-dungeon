---
description: "Use when implementing merchant room interaction, merchant offers, merchant UI behavior, or buy/sell transaction flow."
applyTo: "scripts/merchant/*.gd, scenes/merchant/*.tscn, scripts/ui/merchant_panel.gd, scenes/ui/merchant_panel.tscn, scripts/dungeon/dungeon_floor_controller.gd, scripts/inventory/inventory_manager.gd, project.godot"
---

# Merchant System Guidelines

Use this file as the source of truth for merchant-room interaction and shop behavior.

## Merchant Room Interaction

- Keep merchant interaction aligned with chest-style rules:
  - player must be within interaction radius.
  - player must be looking at merchant (camera dot threshold check).
  - player presses `interact` (`E`).
- Merchant NPC should remain a simple capsule placeholder unless a dedicated character asset is introduced.
- Keep in-world prompt visible only when interaction conditions are met.
- Merchant room remains a safe hub (no enemy/combat pressure while shopping).

## Shop Session Lifecycle

- Start a new merchant shop session each merchant-room entry.
- Regenerate exactly 3 offers per session.
- Keep offer purchase state session-scoped (buy-once during the current merchant room).
- Close shop on merchant-room exit and when merchant room is hidden.

## Offer Rules

- Offer pool currently supports:
  - Ring/Band offers generated from existing item generation pipeline.
  - Special modifier offers (placeholder unlock flags).
- Required special modifier offers:
  - Arcane Compass: points to floor exit direction after sufficient floor exploration.
  - Reforging Seal: one-time affix reroll token for one selected ring/band item.
  - Ring Slot Expansion: grants +1 right-hand ring slot (one-time unlock).
  - Band Slot Expansion: grants +1 left-hand band slot (one-time unlock).
- Existing placeholder modifiers may still remain in the pool (for example Bag/Map unlock flags).
- Arcane Compass and Reforging Seal are gameplay-relevant offers, not cosmetic labels.

## Buy Rules

- Validate offer index and purchase state before transaction.
- Validate player gold before purchase.
- Item-offer purchases:
  - auto-equip into first free compatible slot.
  - if no free compatible slot exists, block purchase and surface a clear reason.
- Special-modifier purchases:
  - set unlock flag true.
  - mark offer purchased.
- Ring/Band slot expansion purchases must increase runtime slot capacity immediately and refresh UI.
- Reforging Seal purchases should grant a consumable reroll token/state the player can spend on one item.
- Deduct gold only after transaction eligibility is confirmed.

## Sell Rules

- Support selling both:
  - equipped rings/bands.
  - nearby world rings/bands.
- Sale value is derived from item `gold_value` (minimum 1).
- Selling equipped items must clear slot state and refresh derived stats.
- Selling world items must remove the world item instance safely.

## UI Rules

- Merchant UI must show:
  - player gold.
  - player gems.
  - all 3 current offers.
  - player ring/band sell lists (equipped + nearby items).
  - current special unlock states.
- Keep unavailable offer reasons explicit and readable.
- Keep rarity-aware coloring for item names/rows.
- Keep detailed item tooltip access for offer and sell rows.

## Input And Control Locks

- While merchant UI is open:
  - lock player movement/input through PlayerManager lock API.
  - keep mouse visible.
- On close:
  - release merchant lock.
  - restore mouse mode based on inventory-open state.

## Integration Rules

- Merchant state should be managed by a dedicated autoload (`MerchantManager`).
- Keep PlayerManager as currency authority.
- Use InventoryManager helper APIs for equip/sell operations.
- Keep dungeon progression flow stable: `floor -> merchant -> next floor`.

## Regression Checklist

- Merchant prompt appears only when close + looking at merchant.
- Pressing `E` opens merchant UI only under valid interaction conditions.
- Exactly 3 offers appear per merchant-room entry.
- Bought offer cannot be bought again in the same session.
- Item purchase with no free slot is blocked with clear reason.
- Selling equipped and nearby items both increase gold correctly.
- Merchant offers regenerate on next merchant-room entry.
- Arcane Compass purchase updates run state and compass behavior activates on following dungeon floors.
- Reforging Seal purchase grants exactly one reroll use and consumes on use.
- Ring Slot Expansion increases max ring slots by +1 only once.
- Band Slot Expansion increases max band slots by +1 only once.