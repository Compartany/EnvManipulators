local mod = mod_loader.mods[modApi.currentMod]
local tool = mod.tool

Mission_Force.Env_MountainValid = true -- 破坏两座山关卡
Mission_Holes.Env_FlyValid = true -- 深坑马蜂关卡

local this = {}

function this:Load()
    -- nothing to do
end

return this
