-- Modern Johto
--
-- The Gen 2 counterpart of Modern Kanto, and deliberately a different mod
-- rather than the same one with a second game bolted on.
--
-- Of Modern Kanto's six pieces, five have no object on Gold. Gold already
-- ships the corrected type chart. Gold already fixed the five battle quirks
-- Gen 1 got wrong by accident -- and `rulesets`, the registry that expresses
-- them, is one of the six with no Gen 2 home at all, so the write would be
-- taken, dropped and reported. Gold already dropped the badge stat boost.
-- Gold's AI is the ten scoring passes of scoring.asm, a different id space
-- from Gen 1's LAYER_3. And an Atlas for Kanto is an Atlas for the wrong
-- region.
--
-- What carries over from 0.1.0 is the split -- and it means MORE here than
-- it does on Red, not less. Gen 1 has ONE Special stat, so its split is half
-- a change: moving a move between the two columns still lands on the same
-- number for both attack and defence. Gold already splits Special into
-- specialAttack and specialDefense, so deciding the category per move is the
-- whole Gen 4 change, working against stats that actually differ.
--
-- 0.2.0 adds one more piece, and drops two candidates that turned out to be
-- nothing on Gold -- see "the two that did not ship" near the AI section
-- below for the file:line case against each, because a toggle that changes
-- nothing is exactly the failure this house style exists to avoid.
--
--   SPLIT   physical/special per move, not per type   (Gen 4)
--   AI      opponents that read type effectiveness even when their own
--           class was never told to
--
-- Off by default: both change the balance, and a player should meet the
-- game the cart shipped unless they asked otherwise.
--
-- ------- why this is a hook and not data, which on Red it was
--
-- On Gen 1 the split is pure data. src/battle/Damage.lua:categoryOf reads
-- "the move's own category field wins, then the merged type record's", so
-- Modern Kanto patches `moves` records and never touches the battle.
--
-- Gold does not have that fallback chain. src/battle/gen2/Damage.lua:67
-- is:
--
--   function Damage.isPhysical(moveType, types)
--     local record = types and types[moveType]
--     if record and record.category then return record.category == "physical" end
--
-- -- it takes a TYPE id, not a move record, and every call site in
-- src/battle/gen2/Battle.lua (521, 539, 652, 1096, 1145) passes `def.type`.
-- So `mod.content.moves:patch(id, { category = ... })` is a valid registry
-- write that lands on a field nothing in the Gen 2 damage pipeline reads:
-- it would validate, lint, pack and ship, and change nothing at all. That
-- is the exact "green and inert" failure the engine's own mod docs warn
-- about, and it is why this mod took the next level down instead.
--
-- The seam that does work: src/battle/gen2/Battle.lua:1111 calls the
-- `battle.damage` hook with the `opts` table the formula is actually run
-- on, and src/battle/gen2/Damage.lua:176 opens Damage.calc with
--
--   local physical = Damage.isPhysical(opts.moveType, opts.types)
--
-- from which the raw attack/defence pick (:182-185), the stage pick
-- (:186-189) and the screen doubling (:203) all follow. So handing the
-- inner call an `opts` whose `types` table answers differently for THIS
-- move's type is a per-move split, expressed exactly once, at the only
-- place that reads it.
--
-- The copy is not an optimisation, it is the whole safety of the thing:
-- mutating the shared `type_chart.types` table would move every move of
-- that type for the rest of the battle, which is the coarse per-type change
-- this mod exists not to be.

return function(mod)

  -- ------- the exceptions
  --
  -- Both generations decide a move's category from its TYPE, and the
  -- boundary is the same one: src/battle/gen2/Damage.lua:71-76 spells the
  -- physical half out as NORMAL, FIGHTING, FLYING, POISON, GROUND, ROCK,
  -- BUG, GHOST and STEEL, with everything else special. That list is read
  -- from the engine below rather than restated here, so it cannot drift.
  --
  -- Only the DIFFERENCES are listed. A move whose Gen 4 category already
  -- matches what its type implies needs no entry, and listing it would be
  -- a bigger table to get wrong for no effect. The suite enforces that:
  -- an entry that agrees with the type rule fails the build.
  --
  -- Ids are the disassembly's own move constants. An id this cart does not
  -- carry is skipped in silence rather than warned about, because the same
  -- table is meant to survive a species-or-move-adding mod underneath it.
  local SPLIT = {
    -- Special types whose move is PHYSICAL in Gen 4.
    physical = {
      -- Gen 1 moves, the same entries Modern Kanto carries
      "FIRE_PUNCH",     -- Fire
      "ICE_PUNCH",      -- Ice
      "THUNDERPUNCH",   -- Electric
      "CRABHAMMER",     -- Water
      "WATERFALL",      -- Water
      "CLAMP",          -- Water
      "RAZOR_LEAF",     -- Grass
      "VINE_WHIP",      -- Grass
      -- Gold's own. The Dark moves are the story here: Dark is a special
      -- type by the boundary above, and almost every Dark move Gold has is
      -- physical in Gen 4 -- which is why Umbreon and Tyranitar spend Gen 2
      -- attacking off the wrong column.
      "CRUNCH",         -- Dark
      "BITE",           -- Dark in Gen 2 (it was Normal in Gen 1)
      "PURSUIT",        -- Dark
      "THIEF",          -- Dark
      "FAINT_ATTACK",   -- Dark
      "BEAT_UP",        -- Dark
      "FLAME_WHEEL",    -- Fire
      "SACRED_FIRE",    -- Fire
      "SPARK",          -- Electric
      "OUTRAGE",        -- Dragon
    },

    -- Physical types whose move is SPECIAL in Gen 4.
    special = {
      -- Gen 1 moves
      "GUST",           -- Flying from Gen 2 on (Normal in Gen 1)
      "SWIFT",          -- Normal
      "TRI_ATTACK",     -- Normal
      "HYPER_BEAM",     -- Normal
      "RAZOR_WIND",     -- Normal
      "SONICBOOM",      -- Normal; fixed damage, categorised for consistency
      "ACID",           -- Poison
      "SLUDGE",         -- Poison
      "SMOG",           -- Poison
      "NIGHT_SHADE",    -- Ghost; fixed damage, categorised for consistency
      -- Gold's own
      "SHADOW_BALL",    -- Ghost
      "SLUDGE_BOMB",    -- Poison
      "ANCIENTPOWER",   -- Rock
      "MUD_SLAP",       -- Ground
      "AEROBLAST",      -- Flying
      "HIDDEN_POWER",   -- Normal
      "SNORE",          -- Normal
    },
  }

  -- ------- options

  mod.options:define({
    -- Off by default. It is a balance change, not a fix: the cart is not
    -- wrong about which stat Crunch uses, it is only older than the answer.
    -- Takes effect on the next battle, not the next launch -- the hook
    -- reads the option per damage roll, so turning it off puts the cart's
    -- own numbers back without a restart.
    { key = "split", label = "SPLIT", type = "toggle", default = false },
    -- Off by default, same reasoning as SPLIT: a trainer that currently
    -- ignores type effectiveness is playing the game the cart shipped, not
    -- a broken one. This is a registry write (see below), so it takes
    -- effect on the next launch rather than the next battle.
    { key = "ai", label = "AI", type = "toggle", default = false },
  })

  local function opt(key)
    local ok, value = pcall(function() return mod.options:get(key) end)
    if not ok then return nil end
    return value
  end

  -- ------- the type boundary, read from the engine
  --
  -- Damage.isPhysical is the authority on what a type means, so it is
  -- asked rather than imitated: a dataset whose type_chart carries its own
  -- `category` records (a mod's, or a future cart's) answers through the
  -- same call the battle uses.
  local Damage = require("src.battle.gen2.Damage")

  local function typeIsPhysical(moveType, types)
    local ok, physical = pcall(Damage.isPhysical, moveType, types)
    if not ok then return nil end
    return physical
  end

  -- The move id -> wanted category lookup, built once.
  local WANT = {}
  for _, id in ipairs(SPLIT.physical) do WANT[id] = "physical" end
  for _, id in ipairs(SPLIT.special) do WANT[id] = "special" end

  -- ------- the split
  --
  -- One wrap, and it does nothing at all for a move that is not an
  -- exception: no copy, no allocation, straight through to the next link.

  local function shallow(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
  end

  mod.hooks:wrap("battle.damage", function(next, c)
    if not opt("split") then return next(c) end

    local ok, corrected = pcall(function()
      local opts = c and c.opts
      if type(opts) ~= "table" then return nil end

      -- The move: `moveId` is what Battle passes when it has one, and the
      -- move record's own id is the fallback.
      local id = c.moveId or (type(c.move) == "table" and c.move.id) or nil
      local want = id and WANT[id]
      if not want then return nil end

      local moveType = opts.moveType
      if moveType == nil then return nil end

      -- An entry that agrees with the boundary is a no-op, and a no-op that
      -- allocates a table per damage roll is worse than no entry at all.
      local isPhysical = typeIsPhysical(moveType, opts.types)
      if isPhysical == nil then return nil end
      if isPhysical == (want == "physical") then return nil end

      -- The copies. `types` first, then the one type record inside it, so
      -- the shared table the rest of the battle reads is never touched.
      local types = shallow(opts.types)
      local record = shallow(opts.types and opts.types[moveType])
      record.category = want
      types[moveType] = record

      local newOpts = shallow(opts)
      newOpts.types = types

      -- Reflect and Light Screen. src/battle/gen2/Battle.lua:1095 computes
      -- `screen` from the TYPE rule before the hook runs, so for a move
      -- this mod moves across the line it is the wrong screen -- Reflect
      -- would go on halving a Crunch that is now physical anyway, and Light
      -- Screen would not. `battle` is in the ctx, so the real answer is
      -- reachable; if it is not, the vanilla value stands rather than a
      -- guess.
      if type(c.battle) == "table" and c.battle.screenActive and c.target then
        local okScreen, screen = pcall(c.battle.screenActive, c.battle,
          c.target, want == "physical")
        if okScreen then newOpts.screen = screen end
      end

      -- The ctx handed on is a copy too: another mod in the chain, or the
      -- engine's own link, must see a consistent table rather than one
      -- whose opts were swapped underneath it.
      local newCtx = shallow(c)
      newCtx.opts = newOpts
      return newCtx
    end)

    -- Anything unexpected and the vanilla answer stands: a throw inside a
    -- damage hook takes the turn down with it.
    if not ok or corrected == nil then return next(c) end
    return next(corrected)
  end)

  -- ------- AI: type effectiveness for every trainer, not just the ones told
  -- ------- to look at it
  --
  -- src/mods/Schemas.lua routes `ai_classes` to a Gen 2 target
  -- (`gen2AiClasses`), and src/battle/gen2/Ai.lua:1570 (Ai.layersFor) is the
  -- one place that reads it: for a trainer class whose AI word has ANY bit
  -- set, it runs the ten vanilla scoring passes the class's flags select
  -- (Ai.LAYER_ORDER, Ai.lua:1543) and then any further registry record whose
  -- own `kind` is "layer" -- a mod layer with no `flag` field runs for every
  -- such class, gated on nothing narrower than "this class runs AI at all"
  -- (Ai.lua:1585). That is the seam this feature writes to. It is Gen 2's
  -- OWN id space: Ai.LAYER_ORDER's ten names (BASIC, TYPES, OFFENSIVE,
  -- AGGRESSIVE, STATUS, RISKY, SETUP, OPPORTUNIST, CAUTIOUS, SMART) have
  -- nothing to do with Gen 1's LAYER_1..LAYER_3, which is a different
  -- registry population entirely -- and the id this mod registers,
  -- `JOHTO_TYPE_AWARE`, is not one of either list.
  --
  -- ------- why this is a NEW layer and not a patch of Gold's own TYPES pass
  --
  -- Modern Kanto patches Gen 1's LAYER_3 in place, because LAYER_3 has a bug
  -- to fix: AIGetTypeEffectiveness only reads the FIRST matching row, so a
  -- dual-type defender is scored on half its typing. Gold's TYPES pass
  -- (Ai.lua:1446) has no such bug -- its score function calls
  -- src/battle/gen2/Damage.lua:115 (Damage.typeMultiplier), which floors one
  -- matchup row into the next and so already multiplies BOTH of a dual-type
  -- defender's rows together, the same way the real damage formula does.
  -- Patching TYPES here would therefore replace a correct function with an
  -- identical one -- a write that validates, lints, packs and changes
  -- nothing, which is the one failure this house style exists to catch.
  --
  -- What IS true of Gold: TYPES only runs for a class whose AI word has the
  -- TYPES bit set (TRNATTR_AI_MOVE_WEIGHTS bit 2), and plenty of trainer
  -- classes carry other bits -- BASIC, OFFENSIVE, AGGRESSIVE and the rest --
  -- without it, so their AI never once asks whether a move is resisted or
  -- super effective. That is the real gap, and it is Gen 2's own shape of
  -- the same complaint Modern Kanto's AI row answers on Red: an opponent
  -- that fights blind to type as long as its class was never told to look.
  --
  -- The new layer is a second, independent copy of the TYPES arithmetic
  -- (dismiss what is immune, encourage what is super effective, discourage
  -- what is resisted -- the same three answers Ai.lua:1446-1454 gives), but
  -- it SKIPS a class that already carries the TYPES bit: Ai.has(view.flags,
  -- "TYPES") is checked first, so a trainer Gold already made type-aware is
  -- scored by the vanilla pass alone and never double-counted by this one.
  local Ai = require("src.battle.gen2.Ai")

  -- Golf: LOWER is more encouraged, the same convention every vanilla layer
  -- in Ai.lua uses (`dec [hl]` encourages, `inc [hl]` discourages). The
  -- three deltas below are Gold's own TYPES numbers, not invented ones.
  local function aiScore(view, def, score)
    if not def then return score end
    if (def.power or 0) <= 0 then return score end
    if Ai.has(view.flags, "TYPES") then return score end

    local chart = (view.context and view.context.typeChart) or {}
    local defenderTypes = (view.defender and view.defender.types) or {}
    local matchup = Damage.typeMultiplier(def.type, defenderTypes,
      chart.matchups)

    if matchup == 0 then return score + 10 end   -- immune: dismiss it
    if matchup > 10 then return score - 1 end     -- super effective
    if matchup < 10 then return score + 1 end     -- resisted
    return score
  end

  -- A throw inside the AI takes the enemy's whole turn down with it
  -- (Ai.choose has no pcall of its own around a layer's score function), so
  -- an unexpected shape here just leaves the running score untouched.
  local function aiScoreGuarded(view, def, score)
    local ok, result = pcall(aiScore, view, def, score)
    if ok then return result end
    return score
  end

  local AI_LAYER_ID = "JOHTO_TYPE_AWARE"

  if opt("ai") then
    pcall(function()
      mod.content.ai_classes:register(AI_LAYER_ID,
        { kind = "layer", score = aiScoreGuarded })
    end)
  end

  -- ------- the two candidates that did not ship
  --
  -- CRITICAL HITS. The brief this mod started from describes Gold picking a
  -- critical from a table keyed on the species' base Speed, the way Gen 1
  -- does, with the Gen 3+ answer being a stage ladder instead. Gold does not
  -- work that way already: src/battle/gen2/Damage.lua:11-14 states outright
  -- that "Gen 1 instead derived the chance from base Speed" and that Gen 2's
  -- own mechanic IS the chance ladder (data/battle/critical_hit_chances.asm,
  -- Damage.lua:26-27's 1/15, 1/8, 1/4, 1/3, 1/2, raised a rung by Focus
  -- Energy, a high-crit move or Scope Lens -- Damage.lua:80-95). That is the
  -- Gen 3 mechanic already: Ruby's own ladder is 1/16, 1/8, 1/4, 1/3, 1/2,
  -- the same shape off the same stages, the 15-versus-16 gap being nothing
  -- more than an 8-bit roll against a 256 one. The `battle.crit` hook does
  -- fire on Gold (src/battle/gen2/Battle.lua:1040), and its ctx really does
  -- drop `ruleset` the way the compat doc says -- but there is no base-Speed
  -- table under it to replace. A toggle that swapped the ladder for the
  -- ladder would validate, lint, pack and ship, and change nothing at all.
  --
  -- EXP. SHARE. Not attempted this release; dropped before any code or test
  -- was written for it.
end
