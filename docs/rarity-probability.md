# Rarity Probability System

How rarity is rolled when an item is generated, and how to tune the numbers.

See also: [Rings and Bands Stat Mechanisms](rings-bands-stat-mechanisms.md)

---

## 1. Base Drop Weights

Defined in `RingBandConstants` (`scripts/inventory/ring_band_constants.gd`):

| Rarity    | Constant                  | Default weight |
|-----------|---------------------------|----------------|
| Common    | `COMMON_DROP_WEIGHT`      | 65             |
| Rare      | `RARE_DROP_WEIGHT`        | 25             |
| Epic      | `EPIC_DROP_WEIGHT`        | 8              |
| Legendary | `LEGENDARY_DROP_WEIGHT`   | 2              |
| **Total** |                           | **100**        |

The roll is a weighted random draw: `rng.randi_range(1, total_weight)`. The result lands in the first tier whose cumulative weight it falls under.

---

## 2. Floor-Depth Scaling

`ItemAffixGenerator._roll_rarity()` adjusts weights per floor depth so higher floors drop better loot:

```
common_weight    = max(COMMON_DROP_WEIGHT - depth * 2,  35)   # floors down to a minimum of 35
rare_weight      = RARE_DROP_WEIGHT      + depth               # +1 per floor
epic_weight      = EPIC_DROP_WEIGHT      + floor(depth / 3)    # +1 every 3 floors
legendary_weight = LEGENDARY_DROP_WEIGHT + floor(depth / 6)   # +1 every 6 floors
```

### Example — floor 0 vs floor 9

| Rarity    | Floor 0  | Floor 9          | Approx % (floor 9) |
|-----------|----------|------------------|--------------------|
| Common    | 65       | 47 (65 - 18)     | ~60%               |
| Rare      | 25       | 34 (25 + 9)      | ~28%               |
| Epic      | 8        | 11 (8 + 3)       | ~9%                |
| Legendary | 2        | 3  (2 + 1)       | ~2.5%              |
| **Total** | **100**  | **~95**          |                    |

> **Note:** total weight is not fixed; it shrinks slightly as Common deflates and grows as the others inflate. The code uses `maxi(total_weight, 1)` to guard against a zero total.

---

## 3. How to Tune Drop Rates

### Change the base floor-0 odds
Edit the four weight constants in `ring_band_constants.gd`:

```gdscript
const COMMON_DROP_WEIGHT: int    = 65  # lower → rarer items at all depths
const RARE_DROP_WEIGHT: int      = 25
const EPIC_DROP_WEIGHT: int      = 8
const LEGENDARY_DROP_WEIGHT: int = 2   # raise → more legendary overall
```

### Change how fast rates improve with depth
Edit the scaling formula inside `_roll_rarity()` in `item_affix_generator.gd`:

```gdscript
var common_weight:    int = maxi(COMMON_DROP_WEIGHT - depth_step * 2, 35)
#                                                    ^^^^^^^^^^^^  ^^
#                              drain rate per floor   floor minimum

var rare_weight:      int = RARE_DROP_WEIGHT      + depth_step
var epic_weight:      int = EPIC_DROP_WEIGHT      + int(floor(depth_step / 3.0))
#                                                              ^^^  divisor → higher = slower scaling
var legendary_weight: int = LEGENDARY_DROP_WEIGHT + int(floor(depth_step / 6.0))
```

### Prevent Common from dropping entirely
The minimum clamp `maxi(..., 35)` keeps Common at ≥ 35 weight no matter how deep the player goes. Raise this value if you never want Common to feel rare, or lower it (even to 0) to allow deep floors to have near-zero Common drops.

---

## 4. Affix Budget Per Rarity

Once a rarity is chosen, the generator picks affixes from fixed budgets.

### Bands (defined in `_get_rarity_budget`)

| Rarity    | Benefits | Optional tradeoffs |
|-----------|----------|--------------------|
| Common    | 1        | 0                  |
| Rare      | 1        | 1                  |
| Epic      | 2        | 1                  |
| Legendary | 2        | 0 or 1 (35% chance)|

### Rings (override via `_get_ring_benefit_budget` + required tradeoffs)

| Rarity    | Benefits | Required tradeoffs (auto-derived) |
|-----------|----------|-----------------------------------|
| Common    | 1        | linked to each benefit key        |
| Rare      | 2        | linked to each benefit key        |
| Epic      | 3        | linked to each benefit key        |
| Legendary | 4        | linked to each benefit key        |

Rings never get **optional** tradeoffs — every negative is structurally tied to a specific benefit via `_get_required_ring_tradeoff_keys()`. The more tradeoffs stack, the more attenuated each one is (see §5).

---

## 5. Stat Scaling Per Rarity

After affix values are rolled from the pool ranges, they are multiplied by a rarity-specific scale factor sampled from a range:

| Rarity    | Scale range (`STAT_SCALE_MIN/MAX`) |
|-----------|------------------------------------|
| Common    | 1.00 – 1.00 (no scaling)           |
| Rare      | 1.10 – 1.30                        |
| Epic      | 1.30 – 1.65                        |
| Legendary | 1.65 – 2.10                        |

These are set in `ring_band_constants.gd` as `RARE_STAT_SCALE_MIN`, `EPIC_STAT_SCALE_MAX`, etc.

For **required ring tradeoffs**, the magnitude is further attenuated by `get_required_tradeoff_scale()`:

```
attenuation = 1 / (1 + REQUIRED_TRADEOFF_STACK_STEP * overflow_count)
```

Where `overflow_count = max(total_required_tradeoffs - 1, 0)` and `REQUIRED_TRADEOFF_STACK_STEP = 0.10`. This means the second+ tradeoff penalty is reduced so rings with many benefits aren't punished double.

---

## 6. Gold Value Per Rarity

Items are priced using a rarity multiplier applied to a base floor-depth formula:

| Rarity    | `VALUE_MULT` constant  | Default |
|-----------|------------------------|---------|
| Common    | `COMMON_VALUE_MULT`    | 1.0×    |
| Rare      | `RARE_VALUE_MULT`      | 1.5×    |
| Epic      | `EPIC_VALUE_MULT`      | 2.5×    |
| Legendary | `LEGENDARY_VALUE_MULT` | 5.0×    |

---

## 7. Quick Setup Checklist

1. **Adjust base odds** → edit the four `*_DROP_WEIGHT` constants in `ring_band_constants.gd`.
2. **Adjust scaling speed** → change the divisors in `_roll_rarity()` inside `item_affix_generator.gd`.
3. **Set a Common floor** → change the `35` clamp in `common_weight` calculation.
4. **Tune stat power per rarity** → edit the six `*_STAT_SCALE_*` constants in `ring_band_constants.gd`.
5. **Tune affix count per rarity** → edit `_get_rarity_budget()` (bands) or `_get_ring_benefit_budget()` (rings) in `item_affix_generator.gd`.
6. **Tune gold value** → edit the four `*_VALUE_MULT` constants in `ring_band_constants.gd`.
