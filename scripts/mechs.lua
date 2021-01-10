local mod = mod_loader.mods[modApi.currentMod]
local path = mod.resourcePath
local trait = require(path .. "scripts/libs/trait")

-- 在单位状态上显示“重型”
trait:Add{
    PawnTypes = "EnvMechPrime",
    Icon = {"img/combat/icons/icon_envheavy.png", Point(0, 0)},
    Description = {EnvMod_Texts.heavy_title, EnvMod_Texts.heavy_description}
}

EnvMechPrime = Pawn:new{
    Name = EnvMod_Texts.mech_prime_name,
    Class = "Prime",
    Health = 5,
    MoveSpeed = 4,
    Image = "mech_env_prime",
    ImageOffset = FURL_COLORS.EnvManipulatorsColors,
    SkillList = {"Env_Weapon_1"},
    SoundLocation = "/mech/prime/rock_mech/",
    DefaultTeam = TEAM_PLAYER,
    ImpactMaterial = IMPACT_METAL,
    Massive = true,
    EnvHeavy = true -- 移动力设为 3 前期会非常难打，但不加限制的 4 移动力开局又会让后期异常轻松
}

EnvMechRanged = Pawn:new{
    Name = EnvMod_Texts.mech_ranged_name,
    Class = "Ranged",
    Health = 2,
    MoveSpeed = 3,
    Image = "mech_env_ranged",
    ImageOffset = FURL_COLORS.EnvManipulatorsColors,
    SkillList = {"Env_Weapon_2", "Env_Weapon_4"},
    SoundLocation = "/mech/distance/dstrike_mech/",
    DefaultTeam = TEAM_PLAYER,
    ImpactMaterial = IMPACT_METAL,
    Massive = true
}

EnvMechScience = Pawn:new{
    Name = EnvMod_Texts.mech_science_name,
    Class = "Science",
    Health = 2,
    MoveSpeed = 4,
    Image = "mech_env_science",
    ImageOffset = FURL_COLORS.EnvManipulatorsColors,
    SkillList = {"Env_Weapon_3"},
    SoundLocation = "/mech/science/science_mech/",
    DefaultTeam = TEAM_PLAYER,
    ImpactMaterial = IMPACT_METAL,
    Massive = true,
    Flying = true
}

function BoardPawn:IsEnvHeavy()
    return _G[self:GetType()].EnvHeavy
end

function BoardPawn:GetBasicMoveSpeed()
    return _G[self:GetType()].MoveSpeed
end

local _Move_GetTargetArea = Move.GetTargetArea
function Move:GetTargetArea(point, ...)
    if Pawn:IsEnvHeavy() then
        if not (Pawn:IsAbility("Shifty") and Pawn:GetMoveSpeed() == 1) then
            local speed = Pawn:GetBasicMoveSpeed()
            return Board:GetReachable(point, speed, Pawn:GetPathProf())
        end
    end
    return _Move_GetTargetArea(self, point, ...)
end

local _Move_GetSkillEffect = Move.GetSkillEffect
function Move:GetSkillEffect(p1, p2, ...)
    local ret = _Move_GetSkillEffect(self, p1, p2, ...)
    if Pawn:IsEnvHeavy() then
        local path = Board:GetPath(p1, p2, Pawn:GetPathProf())
        local pathLength = path:size() - 1 -- 路径长度为途经的点数减 1
        local speed = Pawn:GetBasicMoveSpeed()
        if pathLength == speed or (Pawn:IsAbility("Shifty") and Pawn:GetMoveSpeed() == 1) then
            ret:AddDamage(SpaceDamage(p2, 1))
            ret:AddScript(string.format([[
                local pawn = Board:GetPawn(%d)
                local hp = pawn:GetHealth()
                if hp > 1 then
                    Game:TriggerSound("/ui/battle/critical_damage")
                end
            ]], Pawn:GetId()))
        end
    end
    return ret
end

local Mechs = {}

function Mechs:InitHeavy(mission, alert)
    alert = alert or false
    mission.EnvMechs_Heavy = 0
    local pawns = extract_table(Board:GetPawns(TEAM_MECH))
    for i, id in ipairs(pawns) do
        local pawn = Board:GetPawn(id)
        if pawn and pawn:IsEnvHeavy() then
            local speed1 = pawn:GetBasicMoveSpeed()
            local speed2 = pawn:GetMoveSpeed()
            if speed1 ~= speed2 then
                local space = pawn:GetSpace()
                local bonusSpeed = speed2 - speed1
                local speed3 = math.max(speed1 - bonusSpeed, 0)
                pawn:SetMoveSpeed(speed3)
                mission.EnvMechs_Heavy = mission.EnvMechs_Heavy + 1
                if alert then
                    Board:Ping(space, GL_Color(255, 255, 255, 0))
                    Board:AddAlert(space, EnvMod_Texts.heavy_alert)
                end
            end
        end
    end
end

function Mechs:DestoryHeavy(mission)
    if mission and mission.EnvMechs_Heavy > 0 then
        local pawns = extract_table(Board:GetPawns(TEAM_MECH))
        local cnt = 0
        for i, id in ipairs(pawns) do
            local pawn = Board:GetPawn(id)
            if pawn and pawn:IsEnvHeavy() then
                pawn:SetMoveSpeed(pawn:GetBasicMoveSpeed())
                cnt = cnt + 1
                if cnt >= mission.EnvMechs_Heavy then
                    break
                end
            end
        end
    end
end

function Mechs:Load()
    modApi:addNextTurnHook(function(mission)
        if not mission.EnvMechs_Init then
            self:InitHeavy(mission, true)
            mission.EnvMechs_Init = true
        end
    end)
    modApi:addPostLoadGameHook(function() -- 虽然关卡结束不会还原，但退出游戏却会还原……
        modApi:runLater(function(mission)
            if mission.EnvMechs_Init then
                self:InitHeavy(mission)
            end
        end)
    end)
    modApi:addMissionEndHook(function(mission) -- 关卡结束不会自动还原
        self:DestoryHeavy(mission)
    end)
end

return Mechs
