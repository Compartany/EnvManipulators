local mod = mod_loader.mods[modApi.currentMod]
local tool = mod.tool

-- 默认环境
EnvArtificial = Env_Attack:new{
    Image = "env_airstrike",
    Name = EnvMod_Texts.envArtificial_name, -- ?
    Text = EnvMod_Texts.envArtificial_basic_description,
    StratText = EnvMod_Texts.envArtificial_name, -- 警告名称
    CombatIcon = "combat/tile_icon/tile_airstrike.png",
    CombatName = EnvMod_Texts.envArtificial_name, -- 关卡内显示的名称
    BaseArea = Env_Weapon_4.BaseArea, -- 基础锁定数
    IsOverlay = false -- 是否为叠加环境
}
local this = EnvArtificial

-- 环境规划
-- 多次执行，返回 true 表示需继续执行，返回 false 表示执行完毕
function this:Plan()
    if IsPassiveSkill("Env_Weapon_4") then
        self.Locations = {}
        self.Planned = self:SelectSpaces()
        if #self.Planned > 0 then
            tool:EnvArtificialGenerate(self.Planned, self.IsOverlay)
        end
    end
    return false
end

-- 标记目标方格，仅改变 UI
-- 回合内在需要更新方格状态时自动调用，手动调用无用
function this:MarkSpace(space, active)
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
        local damage = tool:GetEnvArtificialDamage(pawn)
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
function this:ApplyEffect()
    if self:IsEffect() then
        local effect = SkillEffect()
        local psions = {} -- 原版游戏中不可能出现多只水母，但鬼知道其他 MOD 会不会改
        local others = {} -- 其他 pawn
        effect.iOwner = ENV_EFFECT
        local allyImmue = IsPassiveSkill("Env_Weapon_4_A")
        if self.Locations.NoPsion then
            others = self.Locations
        else
            for i, location in ipairs(self.Locations) do
                if not allyImmue or Board:GetPawnTeam(location) ~= TEAM_PLAYER then
                    local pawn = Board:GetPawn(location)
                    if pawn and pawn:IsPsion() then
                        psions[#psions + 1] = location
                    else
                        others[#others + 1] = location
                    end
                end
            end
        end
        if #psions > 0 then
            self:ApplyEffect_Inner(psions, effect)
            effect:AddDelay(0.6)
            Board:AddEffect(effect)
            self.Locations = others
            self.Locations.NoPsion = true
        else
            -- 不能在击杀灵虫后接一个延时立即在 effect 上添加其他效果
            -- 这样由于没有结算完毕，灵虫的效果依然还在
            self:ApplyEffect_Inner(others, effect)
            Board:AddEffect(effect)
            self.Locations = {}
        end
    end
    return self:IsEffect()
end

function this:ApplyEffect_Inner(locations, effect)
    self.CurrentAttack = locations
    if #locations > 0 then
        effect:AddSound("/impact/generic/explosion_large")
        while #locations > 0 do
            local location = random_removal(locations)
            local pawn = Board:GetPawn(location)
            local envDamage = tool:GetEnvArtificialDamage(pawn)
            local damage = SpaceDamage(location, envDamage)
            damage.sAnimation = "EnvArtificial_Animation" .. random_int(2)
            effect:AddDamage(damage)
            if IsPassiveSkill("Env_Weapon_4") then
                effect:AddScript([[ -- 取消行动
                    local location = ]] .. location:GetString() .. [[
                    local pawn = Board:GetPawn(location)
                    if pawn and pawn:IsQueued() then -- 单位被击杀也不会进得来
                        pawn:ClearQueued()
                        Board:Ping(location, GL_Color(196, 182, 86, 0))
                        Board:AddAlert(location, EnvMod_Texts.action_terminated)
                    end
                ]])
            end
            if #locations > 1 then
                effect:AddDelay(math.random() * 0.006 + 0.025) -- 稍微错开时间，使动画不至于不自然
            end
        end
    end
end

-- 选择目标方格
function this:SelectSpaces()
    local quarters = tool:GetEnvQuarters()
    local area = self.BaseArea
    if IsPassiveSkill("Env_Weapon_4_B") or IsPassiveSkill("Env_Weapon_4_AB") then
        area = area + tool:GetEnvArtificialUpgradeAreaValue()
    end
    return tool:GetUniformDistributionPoints(area, quarters)
end

function this:Load()
    TILE_TOOLTIPS.passive0 = {Weapon_Texts.Env_Weapon_4_Name .. " - " .. Weapon_Texts.Env_Weapon_4_Upgrade1,
                              Weapon_Texts.Env_Weapon_4_A_UpgradeDescription}
    for damage = 1, 6 do -- 为了方便日后修改，还是将伤害从 1 到 6 全弄出 tooltip 来
        TILE_TOOLTIPS["passive" .. damage] = {EnvMod_Texts.envArtificial_name,
                                              string.format(EnvMod_Texts.envArtificial_description, damage)}
    end

    modApi:addNextTurnHook(function(mission)
        if IsPassiveSkill("Env_Weapon_4") or tool:GetWeapon("Env_Weapon_2") then
            if Game:GetTeamTurn() == TEAM_ENEMY then -- 敌人回合开始时清信息
                mission.EnvArtificialGenerated = {}
            end
        end
    end)
end

return this
