# gen1recomp-modern-johto

Two switchable pieces for **Pokémon Gold**, on
[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp):

- The Gen 4 physical/special split — decided per move instead of per type,
  so Crunch comes off Attack and Shadow Ball off Special Attack.
- An AI toggle that gives a type opinion to trainer classes Gold never gave
  one to.

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
| `AI` | on / off | a trainer class with no TYPES bit reads type effectiveness anyway |

Both **off by default**, because both change the balance. The cart is not
*wrong* about which stat Crunch uses, or about which trainers weigh type —
it is only older than the answer, or was never told to look.

`SPLIT` takes effect on the next battle rather than the next launch: the
option is read per damage roll, so turning it back off restores the cart's
own numbers without a restart. `AI` is a registry write (see below), so it
takes effect on the next launch, the way Modern Kanto's own AI row does.

## AI — coverage, not a correction

Gold's trainer AI scores every move it knows and picks the lowest score
(`src/battle/gen2/Ai.lua`, `engine/battle/ai/scoring.asm`). Which of its ten
scoring passes run for a given trainer is a per-class bit field
(`TRNATTR_AI_MOVE_WEIGHTS`), and one of those ten, `TYPES`, is the pass that
reads type effectiveness — but only for a class whose bits include it. Every
other class, `BASIC`-only trainers included, never once asks whether a move
is resisted or super effective.

`TYPES` itself has no bug to fix: its score function calls
`Damage.typeMultiplier` (`src/battle/gen2/Damage.lua:115`), which floors one
matchup row into the next, so a dual-type defender's two rows are already
multiplied together correctly — unlike Gen 1's `LAYER_3`, which Modern
Kanto patches because `AIGetTypeEffectiveness` there only reads the first
matching row. Patching `TYPES` on Gold would replace a correct function with
an identical one: a registry write that validates, lints, packs and ships,
and changes nothing at all.

So this mod registers a second, independent layer, `JOHTO_TYPE_AWARE`, under
the `ai_classes` registry (`Ai.layersFor`, `src/battle/gen2/Ai.lua:1570`).
It runs for any class whose AI word has *any* bit set, and its first check is
whether the class already carries the `TYPES` bit — if it does, the layer
gets out of the way rather than scoring the same move twice. Where it does
run, its numbers are `TYPES`' own: dismiss what is immune, encourage what is
super effective, discourage what is resisted. Wrapped in `pcall`, because
`Ai.choose` carries no `pcall` of its own around a layer's score function,
and a throw inside the AI takes the enemy's whole turn down with it.

## Two candidates that did not ship

**Critical hits.** Gen 1 rolls a critical off the species' base Speed; Gen 3
onward uses a stage ladder instead, and that was the plan for a third
toggle. Gold already runs the ladder. `src/battle/gen2/Damage.lua:11-14`
says so directly — the base-Speed derivation is credited to Gen 1 only, and
Gen 2's own mechanic *is* the chance ladder (`1/15, 1/8, 1/4, 1/3, 1/2`,
raised a rung by Focus Energy, a high-crit move or Scope Lens —
`Damage.lua:26-27`, `:80-95`). That is the same shape as Ruby's own ladder
(`1/16, 1/8, 1/4, 1/3, 1/2`) off the same stages; the 15-versus-16 gap is an
8-bit roll against a 256 one, not a different mechanic. The `battle.crit`
hook does fire on Gold (`Battle.lua:1040`), but there is no base-Speed table
left under it to replace, so a toggle here would have shipped green and
changed nothing.

**EXP. SHARE, the Ruby/Sapphire way.** Considered, then dropped before any
code or test was written for it.

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

For AI, it loads the mod twice — once with `AI` forced on, once at the
shipped default — and both times calls `Ai.choose` itself against a
`BASIC`-only class choosing between a super effective move and a neutral
one, with a deterministic tie-break `random`. With `AI` on it picks the
super effective move; at the default it falls to the tie-break, exactly the
class Gold leaves type-blind today. Both runs also check the registry
directly: `JOHTO_TYPE_AWARE` is present in the merged `ai_classes` table
when the option is on, and absent at the default.

## Legal

Not affiliated with Nintendo, Game Freak or The Pokémon Company. This
repository contains **Lua source only** — no ROM, no ROM-derived data, no game
assets. Playing requires a legally obtained Gen 2 ROM, which is not provided
here.

The category table is a factual statement about how the games behave, not data
extracted from a cartridge.
