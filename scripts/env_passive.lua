local mod = mod_loader.mods[modApi.currentMod]
local tool = mod.tool

-- 默认环境
Env_Passive = Env_Attack:new{
    Image = "env_airstrike",
    Name = EnvMod_Texts.env_passive_name, -- ?
    Text = EnvMod_Texts.env_passive_basic_description,
    StratText = EnvMod_Texts.env_passive_name, -- 警告名称
    CombatIcon = "combat/tile_icon/tile_airstrike.png",
    CombatName = EnvMod_Texts.env_passive_name, -- 关卡内显示的名称
    BaseArea = Env_Weapon_4.BaseArea, -- 基础锁定数
    IsOverlay = false -- 是否为叠加环境
}

-- 环境规划
-- 多次执行，返回 true 表示需继续执行，返回 false 表示执行完毕
function Env_Passive:Plan()
    if IsPassiveSkill("Env_Weapon_4") then
        self.Locations = {}
        self.Planned = self:SelectSpaces()
        if #self.Planned > 0 then
            tool:EnvPassiveGenerate(self.Planned, self.IsOverlay)
        end
    end
    return false
end

-- 标记目标方格，仅改变 UI
-- 回合内自动调用 N 次，具体原理不明，直接调用无效
function Env_Passive:MarkSpace(space, active)
    local allyImmue = IsPassiveSkill("Env_Weapon_4_A")
    local tooltip = nil
    local deadly = true
    local colors = {GL_Color(255, 226, 88, 0.75), GL_Color(255, 150, 150, 0.75)}
    if allyImmue and Board:GetPawnTeam(space) == TEAM_PLAYER then
        tooltip = "passive0"
        deadly = false
        colors[1] = GL_Color(50, 200, 50, 0.75)
        colors[2] = GL_Color(20, 200, 20, 0.75)
    else
        local pawn = Board:GetPawn(space)
        local damage = tool:GetEnvPassiveDamage(pawn)
        tooltip = "passive" .. damage
        if pawn then
            if pawn:IsFrozen() then
                deadly = false
            else
                local line = damage
                if pawn:IsAcid() then
                    line = line * 2
                elseif pawn:IsArmor() then -- 装甲会被酸液腐蚀
                    line = line - 1
                end
                -- 不要帮忙判定火焰了
                -- if pawn:IsFire() then -- 火焰免疫不会进入燃烧状态，不用判定
                --     line = line + 1
                -- end
                if pawn:GetHealth() > line then
                    deadly = false
                end
            end
        end
    end
    Board:MarkSpaceImage(space, self.CombatIcon, active and colors[2] or colors[1])
    Board:MarkSpaceDesc(space, tooltip, deadly)
end

-- 激活环境
function Env_Passive:ApplyEffect()
    if self:IsEffect() then
        local effect = SkillEffect()
        effect.iOwner = ENV_EFFECT
        effect:AddSound("/impact/generic/explosion_large")
        local allyImmue = IsPassiveSkill("Env_Weapon_4_A")
        for i, location in ipairs(self.Locations) do
            if not allyImmue or Board:GetPawnTeam(location) ~= TEAM_PLAYER then
                local pawn = Board:GetPawn(location)
                local envDamage = tool:GetEnvPassiveDamage(pawn)
                local damage = SpaceDamage(location, envDamage)
                damage.sAnimation = "Env_Passive_Animation" .. random_int(2)
                effect:AddDamage(damage)
                if IsPassiveSkill("Env_Weapon_4") then
                    effect:AddScript([[ -- 取消行动
                        local location = ]] .. location:GetString() .. [[
                        local pawn = Board:GetPawn(location)
                        if pawn and pawn:IsQueued() then -- 单位被击杀也不会进得来
                            pawn:ClearQueued()
                            Board:Ping(location, GL_Color(196, 182, 86, 0))
                            Board:AddAlert(location, Global_Texts["Action_Terminated"])
                        end
                    ]])
                end
            end
        end
        Board:AddEffect(effect)
    end
    self.Locations = {}
    return false
end

-- 选择目标方格
function Env_Passive:SelectSpaces()
    local quarters = tool:GetEnvQuarters() -- 先在每个象限取一格
    local area = self.BaseArea
    if IsPassiveSkill("Env_Weapon_4_B") or IsPassiveSkill("Env_Weapon_4_AB") then
        area = area + tool:GetEnvPassiveUpgradeAreaValue() -- 虽然 BaseArea 目前是 4，但还是假装不知道吧
    end
    return tool:GetUniformDistributionPoints(area, quarters)
end

-- 阻止爆卵虫将卵产在环境被动锁定的方格内，蜘蛛之上没有这么低不用做特殊处理
-- 这是游戏后期难度偏低的主要原因之一！
local _BlobberAtk1_GetTargetScore = BlobberAtk1.GetTargetScore
function BlobberAtk1:GetTargetScore(p1, p2, ...)
    return tool:IsEnvPassiveGenerated(p2) and -10 or _BlobberAtk1_GetTargetScore(self, p1, p2, ...)
end

-- 各种关卡生成敌人也要避开环境锁定的方格，以提高难度
local _Mission_FlyingSpawns = Mission.FlyingSpawns
function Mission:FlyingSpawns(origin, count, pawn, projectile_info, exclude, ...)
    exclude = exclude or {}
    if self.EnvPassiveGenerated and #self.EnvPassiveGenerated > 0 then
        for i, location in ipairs(self.EnvPassiveGenerated) do
            exclude[#exclude + 1] = location
        end
    end
    return _Mission_FlyingSpawns(self, origin, count, pawn, projectile_info, exclude, ...)
end

function Env_Passive:Load()
    Global_Texts.Action_Terminated = EnvMod_Texts.action_terminated
    TILE_TOOLTIPS.passive0 = {Weapon_Texts.Env_Weapon_4_Name .. " - " .. Weapon_Texts.Env_Weapon_4_Upgrade1,
                              Weapon_Texts.Env_Weapon_4_A_UpgradeDescription}
    for damage = 1, 6 do -- 为了方便日后修改，还是将伤害从 1 到 6 全弄出 tooltip 来
        TILE_TOOLTIPS["passive" .. damage] = {EnvMod_Texts.env_passive_name,
                                              string.format(EnvMod_Texts.env_passive_description, damage)}
    end

    modApi:addNextTurnHook(function(mission)
        if IsPassiveSkill("Env_Weapon_4") or tool:GetWeapon("Env_Weapon_2") then
            if Game:GetTeamTurn() == TEAM_ENEMY then -- 敌人回合开始时清信息
                mission.EnvPassiveGenerated = {}
            end
        end
    end)
end

return Env_Passive
