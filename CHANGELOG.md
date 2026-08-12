# Changelog

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
