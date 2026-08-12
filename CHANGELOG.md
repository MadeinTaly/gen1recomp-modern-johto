# Changelog

## 0.2.0 — AI, and two candidates that turned out to be nothing

- **AI** (off by default) — a second `ai_classes` layer, `JOHTO_TYPE_AWARE`,
  registered beside Gold's own ten scoring passes. It runs for any trainer
  class whose AI word has ANY bit set and steps aside the moment the class
  already carries the `TYPES` bit, so it only reaches the classes Gold left
  type-blind: dismissing what the target is immune to, encouraging what is
  super effective, discouraging what is resisted — the exact numbers Gold's
  own `TYPES` pass already uses (`src/battle/gen2/Ai.lua:1446-1454`), just
  extended to trainers whose class was never told to look.

  It is a *new* layer rather than a patch of `TYPES`, and that is not the
  same move Modern Kanto makes on Red. Gen 1's `LAYER_3` has a real bug —
  `AIGetTypeEffectiveness` only reads the first matching row, so a dual-type
  defender is scored on half its typing — and patching it in place fixes
  that bug for every class that already references it. Gold's `TYPES` pass
  has no such bug: its score function calls
  `Damage.typeMultiplier` (`src/battle/gen2/Damage.lua:115`), which floors
  one matchup row into the next, multiplying a dual-type defender's two
  rows together correctly already. Patching `TYPES` here would replace a
  correct function with an identical one — green, and inert. The gap on
  Gold is coverage, not correctness: plenty of trainer classes never carry
  the `TYPES` bit at all, so this mod adds a second, independent pass that
  reaches them instead, and gets out of the way of any class Gold already
  made type-aware so the effect is never double-counted.

  Wrapped in `pcall`: a throw inside a scoring layer takes the enemy's whole
  turn down with it, and `Ai.choose` carries no `pcall` of its own around a
  layer's score function.

- **Two candidates from the original brief did not ship, and are explained
  in `main.lua` rather than silently dropped:**

  **Critical hits.** The brief that started this release described Gold
  choosing a critical hit off the species' base Speed, Gen 1's own rule,
  with the fix being a Gen 3-style stage ladder instead. Gold already runs
  that ladder: `src/battle/gen2/Damage.lua:11-14` states plainly that the
  base-Speed derivation is Gen 1's, and Gen 2's own mechanic already is the
  chance ladder (`1/15, 1/8, 1/4, 1/3, 1/2`, raised a rung by Focus Energy,
  a high-crit move or Scope Lens — `Damage.lua:26-27`, `:80-95`). That is
  the same shape Ruby's own ladder uses (`1/16, 1/8, 1/4, 1/3, 1/2`), off
  the same stages; the 15-versus-16 gap is an 8-bit roll against a 256 one,
  not a different mechanic. The `battle.crit` hook does fire on Gold
  (`Battle.lua:1040`) and its `ctx` really does drop `ruleset`, exactly as
  documented — but there is no base-Speed table under it left to replace.
  A toggle that swapped the ladder for the ladder would validate, lint,
  pack and ship, and change nothing at all, which is the one failure this
  house style exists to catch.

  **EXP. SHARE, the Ruby/Sapphire way.** Dropped before any code or test
  was written for it; not investigated further this release.

## 0.1.0 — the split, on Gold

First release. One feature, and the reason it is its own mod.

- **SPLIT** (off by default) — a move's physical/special category decided per
  move, the Gen 4 way, instead of per type. Crunch, Bite, Pursuit, Thief,
  Faint Attack and Beat Up come off Attack; Shadow Ball, Sludge Bomb,
  Ancientpower, Mud-Slap, Aeroblast, Hidden Power and Snore come off Special
  Attack; and the Gen 1 exceptions Modern Kanto already knew about come along
  with them.

  It means more here than on Red. Gen 1 has one Special stat, so moving a move
  between the columns still lands on the same number twice. Gold splits
  Special into `specialAttack` and `specialDefense`, so this is the whole Gen 4
  change rather than half of it — and the Dark moves are the case in point,
  since Dark is a *special* type whose moves are nearly all physical in Gen 4.

- **It is a hook, not data, and that is not a style choice.** On Gen 1,
  `Damage.categoryOf` reads the move's own category before the type's, so the
  split is a registry patch. Gold's `Damage.isPhysical(moveType, types)` takes
  a **type id** and every call site passes `def.type`: a per-move `category`
  patch there is a valid write onto a field nothing in the damage pipeline
  reads. It would have validated, linted, packed and shipped, and changed
  nothing at all. The `battle.damage` hook is the seam that works, and the
  formula is handed a copied `types` table rather than the shared one.

- **Known, and stated rather than hidden:** Counter and Mirror Coat are
  decided after the hook returns, from the type rule, so with SPLIT on they
  still answer a Crunch as though it were special. Reaching that would take
  surgery on a Gen 2 internal, which is not a thing this mod will do.

- **Not `experimental`.** That flag inverts the enable default for the whole
  mod; a single well-understood feature behind an off-by-default toggle does
  not need it.
