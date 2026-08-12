-- Standalone: luajit mods/modern_johto/tests/modern_johto_test.lua
--
-- The mod's whole claim is one sentence -- "an exception move is computed
-- off the other stat, and nothing else moves" -- so that is what is driven
-- here, through the same Runtime the battle calls, rather than by reading
-- the mod's table back to itself.

package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local Damage = require("src.battle.gen2.Damage")
local Data = require("src.core.Data"); Data:load()

local DIR = os.getenv("MODERN_JOHTO_DIR") or "mods/modern_johto"

-- ------- the dataset
--
-- Built rather than borrowed. T.fixtures.fresh() inherits from the Data
-- singleton through __index, and Data:load() has already run above, so the
-- namespaces the fixture does not carry would leak through and the loader
-- would re-register them. Methods only.
local function freshData()
  local D = T.fixtures.fresh()
  setmetatable(D, { __index = function(_, k)
    local v = Data[k]
    if type(v) == "function" then return v end
    return nil
  end })
  return D
end

-- ------- the mod, loaded on GEN 2 and asserted to have RUN
--
-- A gate skip is deliberately not an error, so #errors == 0 passes for a
-- mod that never executed a line. The state is the assertion that matters;
-- the option is forced on the same way, because a toggle left at its
-- shipped default of `false` would make every check below vacuous.
local SaveData = require("src.core.SaveData")
local realLoadOptions = SaveData.loadOptions
SaveData.loadOptions = function(fs)
  local opts = realLoadOptions(fs)
  opts.mods = opts.mods or {}
  opts.mods.modern_johto = true
  opts.modOptions = { modern_johto = { split = true } }
  return opts
end
local run = T.sdk.loadMod(DIR, { data = freshData(), generation = 2 })
SaveData.loadOptions = realLoadOptions

T.eq(run.mod and run.mod.state, "loaded",
  "runs on gen 2 (" .. tostring(run.mod and run.mod.skipReason) .. ")")
T.check(run.mod ~= nil and run.mod.enabled,
  "the mod is ENABLED -- otherwise every assertion below is vacuous")
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

-- ------- the type boundary, read from the engine rather than restated
--
-- src/battle/gen2/Damage.lua:71-76. The suite asks the same function the
-- battle asks, so a dataset carrying its own type categories moves both
-- together.
local TYPES = (Data.type_chart and Data.type_chart.types) or nil
local function typePhysical(t) return Damage.isPhysical(t, TYPES) end

T.check(typePhysical("NORMAL") == true, "the boundary: NORMAL is physical")
T.check(typePhysical("WATER") == false, "the boundary: WATER is special")

-- ------- driving battle.damage
--
-- The attacker's two offensive stats are far apart on purpose: if the split
-- did not land, the two answers would be the same number and the assertion
-- would pass for the wrong reason.
local function ctxFor(moveId, moveType)
  return {
    battle = nil,
    user = {}, target = {},
    move = { id = moveId, type = moveType },
    moveId = moveId,
    opts = {
      moveType = moveType,
      types = TYPES,
      level = 50,
      power = 80,
      attacker = { attack = 200, specialAttack = 20, special = 20,
                   stages = {} },
      defender = { defense = 100, specialDefense = 100, stages = {} },
      -- The damage roll is 85..100 and Damage.calc rolls it when `variation`
      -- is absent (src/battle/gen2/Damage.lua:284-290), so two calls of the
      -- same move would differ by chance alone and "untouched" could never
      -- be asserted. Pinned, not seeded: the number under test is the stat
      -- the formula picked, not the roll on top of it.
      variation = 100,
    },
  }
end

local function damageFor(moveId, moveType)
  return Runtime.call("battle.damage", function(c)
    return Damage.calc(c.opts)
  end, ctxFor(moveId, moveType))
end

-- CRUNCH is Dark, Dark is special by the boundary, and Gen 4 makes it
-- physical. With attack at 200 and specialAttack at 20, the physical answer
-- has to be the bigger number -- and it has to differ from what the same
-- move gets with the mod's hook not applying.
local crunch = damageFor("CRUNCH", "DARK")
local vanillaDark = Damage.calc(ctxFor("CRUNCH", "DARK").opts)
T.check(crunch > vanillaDark,
  "CRUNCH is computed off Attack, not Special Attack (" ..
  tostring(crunch) .. " vs vanilla " .. tostring(vanillaDark) .. ")")

-- SHADOW_BALL is Ghost, Ghost is physical by the boundary, and Gen 4 makes
-- it special -- the opposite direction, so a hook that simply always
-- answered "physical" would fail here.
local shadow = damageFor("SHADOW_BALL", "GHOST")
local vanillaGhost = Damage.calc(ctxFor("SHADOW_BALL", "GHOST").opts)
T.check(shadow < vanillaGhost,
  "SHADOW_BALL is computed off Special Attack, not Attack (" ..
  tostring(shadow) .. " vs vanilla " .. tostring(vanillaGhost) .. ")")

-- A move the table does not name passes through bit for bit.
local tackle = damageFor("TACKLE", "NORMAL")
T.eq(tackle, Damage.calc(ctxFor("TACKLE", "NORMAL").opts),
  "a move outside the table is untouched")

-- ------- the shared type table is never mutated
--
-- The copy is the safety of the whole approach: writing the category onto
-- the real record would move every move of that type for the rest of the
-- battle, which is the coarse per-type change this mod exists not to be.
local darkRecord = TYPES and TYPES.DARK
local categoryBefore = darkRecord and darkRecord.category
damageFor("CRUNCH", "DARK")
T.eq(darkRecord and darkRecord.category, categoryBefore,
  "the shared DARK type record still says what it said")
T.check(typePhysical("DARK") == false,
  "and every other Dark move is still special")

run.release()

T.finish("modern_johto")
