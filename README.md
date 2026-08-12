# gen1recomp-modern-johto

The Gen 4 physical/special split for **Pokémon Gold**, on
[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp) — decided per move
instead of per type, so Crunch comes off Attack and Shadow Ball off Special
Attack.

This is the Gen 2 counterpart of
[Modern Kanto](https://github.com/MadeinTaly/gen1recomp-modern-kanto), and a
separate mod on purpose. See **Why not just add Gold to Modern Kanto** below.

## Install

Download `modern_johto-<version>.zip` from
[Releases](../../releases), then in the game:

**Launcher → MODS → Import mod .zip**, or in a running game
**START → MODS → Import mod .zip**.

Requires Gen1Recomp with mod API 2 and a Gen 2 build (engine 0.1.79 or newer).
The manifest declares `"games": ["gen2"]`, so on Red, Blue or Yellow the
manager lists it as `ENABLED (NOT THIS GAME)` and nothing else happens — that
is the honest state, not a bug.

## Options

**START → MODS → Modern Johto → OPTIONS..**

| Row | Values | Meaning |
| --- | --- | --- |
| `SPLIT` | on / off | decide a move's physical/special category per move, the Gen 4 way |

**Off by default**, because it changes the balance. The cart is not *wrong*
about which stat Crunch uses — it is only older than the answer. It takes
effect on the next battle rather than the next launch: the option is read per
damage roll, so turning it back off restores the cart's own numbers without a
restart.

## Why this matters more on Gold than on Red

Gen 1 has **one** Special stat, so moving a move between the two columns still
lands on the same number for both attack and defence: the split there is half
a change.

Gold already splits Special into `specialAttack` and `specialDefense`. So
deciding the category per move is the whole Gen 4 change, working against two
stats that genuinely differ — which is why the Dark moves are the story here.
Dark is a *special* type by the type rule, and nearly every Dark move Gold has
is physical in Gen 4, so Umbreon and Tyranitar spend the entire generation
attacking off the wrong column.

## Why not just add Gold to Modern Kanto

Because five of that mod's six pieces have nothing to do on Gold:

| Modern Kanto's piece | on Gold |
| --- | --- |
| the four type-chart rows Gen 2 corrected | already corrected — that mod is describing Gold |
| the five battle quirks Gen 1 got wrong | already fixed, and `rulesets` is one of the six registries with no Gen 2 home at all |
| the badge stat boost | Gen 2 already dropped it |
| the AI type pass | Gold's AI is the ten passes of `scoring.asm`, a different id space from Gen 1's `LAYER_3` |
| the Atlas | an Atlas for Kanto is an Atlas for the wrong region |
| **the split** | **carries over, and means more** |

A mod that switches five of its six options off in the game it claims to
support is not the same mod wearing a second hat. It is a different mod with a
misleading name.

## How the split is done, and one thing it cannot reach

On Gen 1 the split is pure data: `Damage.categoryOf` reads *the move's own
category field first, then the type's*, so Modern Kanto patches `moves`
records and never touches the battle.

Gold has no such fallback. `Damage.isPhysical(moveType, types)` takes a **type
id**, not a move record, and every call site passes `def.type` — so patching a
move's `category` on Gold is a valid registry write that lands on a field
nothing reads. It would validate, lint, pack, ship, and change nothing at all.

So this mod works one level down, at the engine's own `battle.damage` hook:
the damage formula opens by asking `isPhysical(opts.moveType, opts.types)`, and
the hook hands the formula a `types` table that answers differently for *this
move's* type. A copy, never the shared table — writing the category onto the
real record would move every move of that type for the rest of the battle,
which is the coarse per-type change this mod exists not to be.

**The one edge it cannot reach:** Counter and Mirror Coat. Whether a hit
counts as physical or special *for them* is decided after the hook returns,
from the type rule, and there is no seam there. With `SPLIT` on, Counter still
answers a Crunch as though it were special. Everything else — the damage, the
stat stages, the critical rules, Reflect and Light Screen — follows the move's
own category.

## The table

Only the **differences** are listed: a move whose Gen 4 category already
matches what its type implies needs no entry. The suite fails the build on an
entry that agrees with the type rule, so the table cannot quietly fill up with
lines that do nothing.

The type boundary itself is read from the engine rather than restated here, so
it cannot drift from what the battle actually does.

## Testing

```sh
luajit mods/modern_johto/tests/modern_johto_test.lua
python3 tools/modkit.py gen2check mods/modern_johto
```

The suite drives the real `battle.damage` chain with an attacker whose Attack
and Special Attack are far apart, so a split that did not land would produce
the same number and could not pass by accident. It also asserts the shared
type record is unchanged afterwards.

## Legal

Not affiliated with Nintendo, Game Freak or The Pokémon Company. This
repository contains **Lua source only** — no ROM, no ROM-derived data, no game
assets. Playing requires a legally obtained Gen 2 ROM, which is not provided
here.

The category table is a factual statement about how the games behave, not data
extracted from a cartridge.
