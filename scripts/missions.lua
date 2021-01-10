local mod = mod_loader.mods[modApi.currentMod]
local tool = mod.tool

local Missions = {
    Init = false
}

function Missions:InitEnvMissions()
    local isSquad = tool:IsSquad()
    local tBonusPools = {
        {BONUS_GRID, BONUS_MECHS},
        {BONUS_GRID, BONUS_MECHS, BONUS_BLOCK}
    }
    local tMissions = { -- 这种关卡不要出击杀任务，基本做不了的
        {Mission_Tides, Mission_Cataclysm, Mission_Crack},
        {Mission_SnowStorm}
    }
    if tool:IsSquad() then
        if not self.Init then
            for i, missions in ipairs(tMissions) do
                for j, mission in ipairs(missions) do
                    if not mission.EnvMission_Init then
                        mission.Original_BonusPool = mission.BonusPool
                        mission.BonusPool = tBonusPools[i]
                        mission.EnvMission_Init = true
                    end
                end
            end
            self.Init = true
        end
    else
        if self.Init then
            for i, missions in ipairs(tMissions) do
                for j, mission in ipairs(missions) do
                    if mission.EnvMission_Init and mission.Original_BonusPool then
                        mission.BonusPool = mission.Original_BonusPool
                        mission.EnvMission_Init = false
                    end
                end
            end
            self.Init = false
        end
    end
end

function Missions:Load()
    modApi:addPostStartGameHook(function()
        self:InitEnvMissions()
    end)
    modApi:addPostLoadGameHook(function()
        self:InitEnvMissions()
    end)
end

return Missions
