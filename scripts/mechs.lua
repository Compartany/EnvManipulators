local mod = mod_loader.mods[modApi.currentMod]
local path = mod.resourcePath
local trait = mod.lib.trait
local palettes = mod.lib.palettes
local colorOffset = palettes.getOffset("envManipulators_palette")

-- 在单位状态上显示“重型”
trait:Add{
    PawnTypes = {"EnvMechPrime", "EnvMechRanged"},
    Icon = {"img/combat/icons/icon_envheavy.png", Point(0, 0)},
    Description = {EnvMod_Texts.heavy_title, EnvMod_Texts.heavy_description}
}

EnvMechPrime = Pawn:new{
    Class = "Prime",
    Health = 5,
    MoveSpeed = 4,
    Image = "EnvMechPrime",
    ImageOffset = colorOffset,
    SkillList = {"EnvWeapon1"},
    SoundLocation = "/mech/prime/rock_mech/",
    DefaultTeam = TEAM_PLAYER,
    ImpactMaterial = IMPACT_METAL,
    Massive = true,
    EnvHeavy = true -- 移动力设为 3 前期会非常难打，但不加限制的 4 移动力开局又会让后期异常轻松
}

EnvMechRanged = Pawn:new{
    Class = "Ranged",
    Health = 2,
    MoveSpeed = 4,
    Image = "EnvMechRanged",
    ImageOffset = colorOffset,
    SkillList = {"EnvWeapon2", "EnvWeapon4"},
    SoundLocation = "/mech/distance/dstrike_mech/",
    DefaultTeam = TEAM_PLAYER,
    ImpactMaterial = IMPACT_METAL,
    Massive = true,
    EnvHeavy = true
}

EnvMechScience = Pawn:new{
    Class = "Science",
    Health = 2,
    MoveSpeed = 4,
    Image = "EnvMechScience",
    ImageOffset = colorOffset,
    SkillList = {"EnvWeapon3"},
    SoundLocation = "/mech/science/science_mech/",
    DefaultTeam = TEAM_PLAYER,
    ImpactMaterial = IMPACT_METAL,
    Massive = true,
    Flying = true
}

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
    if Pawn:IsEnvHeavy() and not ENV_GLOBAL.tool:IsMine(p2) then -- p2 有地雷不作任何处理
        local path = Board:GetPath(p1, p2, Pawn:GetPathProf())
        local pathLength = path:size() - 1 -- 路径长度为途经的点数减 1
        local speed = Pawn:GetBasicMoveSpeed()
        if pathLength == speed or (Pawn:IsAbility("Shifty") and Pawn:GetMoveSpeed() == 1) then
            local damage = SpaceDamage(p2, 0)
            damage.sImageMark = "combat/icons/icon_envheavy.png"
            ret:AddDamage(damage)
            local id = Pawn:GetId()
            local dmg = 1
            if Pawn:IsArmor() then
                local acid = Pawn:IsAcid()
                if not acid then
                    if Board:IsAcid(p2) then
                        if not Pawn:IsFlying() or Board:GetTerrain(p2) ~= TERRAIN_WATER then
                            acid = true
                        end
                    end
                end
                if not acid then
                    dmg = 2
                end
            end
            local trueDmg = (Pawn:IsAcid() or Board:IsAcid(p2)) and 2 or 1
            ret:AddScript(string.format([[
                local pawn = Board:GetPawn(%d)
                if pawn then
                    local shield = pawn:IsShield()
                    local dmg = %d
                    local p2 = %s
                    if shield then
                        local fx = SkillEffect()
                        local damage = SpaceDamage(p2, dmg)
                        fx:AddSafeDamage(damage)
                        fx:AddSafeDamage(damage)
                        -- 移除机甲及地形效果
                        damage = SpaceDamage(p2, 0)
                        damage.iShield = EFFECT_CREATE
                        damage.iFire = pawn:IsFire() and EFFECT_NONE or EFFECT_REMOVE
                        damage.iAcid = pawn:IsAcid() and EFFECT_NONE or EFFECT_REMOVE
                        fx:AddDamage(damage)
                        -- 恢复地形效果
                        damage = SpaceDamage(p2, 0)
                        damage.iFire = Board:IsFire(p2) and EFFECT_CREATE or EFFECT_NONE
                        damage.iAcid = Board:IsAcid(p2) and EFFECT_CREATE or EFFECT_NONE
                        fx:AddDamage(damage)
                        Board:AddEffect(fx)
                    else
                        local freezeMine = ENV_GLOBAL.tool:IsFreezeMine(p2)
                        if freezeMine then
                            local fx = SkillEffect()
                            local damage = SpaceDamage(p2, dmg)
                            damage.iFrozen = EFFECT_CREATE
                            fx:AddSafeDamage(damage)
                            Board:AddEffect(fx)
                        else
                            pawn:ApplyDamage(SpaceDamage(p2, dmg))
                        end
                    end
                end
            ]], id, dmg, p2:GetString()))
            -- 由于伤害在 script 中完成，下一个 script 中获取到 pawn 的生命值来不及更新，只能手动算血线
            if Pawn:GetHealth() - trueDmg > 1 then
                ret:AddScript([[Game:TriggerSound("/ui/battle/critical_damage")]])
            end
        end
    end
    return ret
end

local this = {}

-- 修改移动力后，在退出关卡时需要还原回来；某些情况无法做到还原（如机甲测试），则设置 unchange 为 true
function this:InitHeavy(mission, unchange)
    unchange = unchange or false
    mission.EnvHeavySpeed = {}
    local pawns = extract_table(Board:GetPawns(TEAM_MECH))
    for _, id in ipairs(pawns) do
        local pawn = Board:GetPawn(id)
        if pawn and pawn:IsEnvHeavy() then
            local speed1 = pawn:GetBasicMoveSpeed()
            local speed2 = pawn:GetMoveSpeed() -- 此时没有缠绕等状态影响，获取到的是加成后的移动力
            if speed1 < speed2 then
                local space = pawn:GetSpace()
                if not unchange then
                    local bonusSpeed = speed2 - speed1
                    local speed3 = math.max(speed1 - bonusSpeed, 1)
                    pawn:SetMoveSpeed(speed3)
                    mission.EnvHeavySpeed[id] = speed3
                end
                pawn:SetShield(true)
                Board:Ping(space, GL_Color(255, 255, 255, 0))
                Board:AddAlert(space, EnvMod_Texts.heavy_alert)
            end
        end
    end
end

-- 重新初始化重型，此时 pawn 可能被缠绕，无法获取到正确的移动力，按之前的办法重新算会出错
function this:ReinitHeavy(mission)
    if mission and mission.EnvHeavySpeed then
        for id, speed in pairs(mission.EnvHeavySpeed) do
            local pawn = Board:GetPawn(id)
            if pawn then
                pawn:SetMoveSpeed(speed)
            end
        end
    end
end

function this:DestoryHeavy(mission)
    if mission and mission.EnvHeavySpeed then
        for id, speed in pairs(mission.EnvHeavySpeed) do
            local pawn = Board:GetPawn(id)
            if pawn then
                pawn:SetMoveSpeed(pawn:GetBasicMoveSpeed())
            end
        end
    end
end

function this:Load()
    modApi:addNextTurnHook(function(mission)
        if not mission.EnvMechs_Init then
            self:InitHeavy(mission)
            mission.EnvMechs_Init = true
        end
    end)
    modApi:addPostLoadGameHook(function() -- 虽然关卡结束不会还原，但退出游戏却会还原……
        modApi:runLater(function(mission)
            if mission.EnvMechs_Init then
                self:ReinitHeavy(mission)
            end
        end)
    end)
    modApi:addMissionEndHook(function(mission) -- 关卡结束不会自动还原
        self:DestoryHeavy(mission)
    end)
    modApi:addTestMechEnteredHook(function(mission)
        modApi:runLater(function(mission)
            self:InitHeavy(mission, true) -- 机甲测试退出 Hook 时无法还原移动力，这里做做样子即可
        end)
    end)
end

return this
