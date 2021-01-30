local mod = mod_loader.mods[modApi.currentMod]
local tool = mod.tool

-- 默认环境
EnvArtificial = Env_Attack:new{
    Image = "env_airstrike",
    CombatIcon = "combat/tile_icon/tile_artificial.png",
    BaseArea = EnvWeapon4.BaseArea, -- 基础锁定数
    BaseDamage = EnvWeapon4.BaseDamage, -- 基础伤害
    IsOverlay = false -- 是否为叠加环境
}
local this = EnvArtificial

-- 环境规划
-- 多次执行，返回 true 表示需继续执行，返回 false 表示执行完毕
function this:Plan()
    if IsPassiveSkill("EnvWeapon4") then
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
    local envImmune = IsPassiveSkill("EnvWeapon4_A")
    local tooltip = nil
    local deadly = true
    local colors = nil
    if tool:IsGroundReflective(space) then
        colors = {GL_Color(255, 180, 0 ,0.75), GL_Color(255, 180, 0 ,0.75)}
    else
        colors = {GL_Color(255, 226, 88, 0.75), GL_Color(255, 150, 150, 0.75)}
    end
    if envImmune and tool:IsEnvImmuneProtected(space, true) then
        tooltip = "artificial0"
        deadly = false
        colors[1] = GL_Color(50, 200, 50, 0.75)
        colors[2] = GL_Color(20, 200, 20, 0.75)
    else
        local pawn = Board:GetPawn(space)
        local damage = tool:GetEnvArtificialDamage(self, pawn)
        tooltip = "artificial" .. damage
        if pawn then
            if pawn:IsShield() or pawn:IsFrozen() then
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
        local fx = SkillEffect()
        local psions = {} -- 原版游戏中不可能出现多只水母，但鬼知道其他 MOD 会不会改
        local others = {} -- 其他 pawn
        fx.iOwner = ENV_EFFECT
        local envImmune = IsPassiveSkill("EnvWeapon4_A")
        if self.Locations.NoPsion then
            others = self.Locations
        else
            for _, location in ipairs(self.Locations) do
                if not envImmune or not tool:IsEnvImmuneProtected(location, true) then
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
            self:ApplyEffect_Inner(psions, fx)
            fx:AddDelay(0.6)
            Board:AddEffect(fx)
            self.Locations = others
            self.Locations.NoPsion = true
        else
            -- 不能在击杀灵虫后接一个延时立即在 effect 上添加其他效果
            -- 这样由于没有结算完毕，灵虫的效果依然还在
            self:ApplyEffect_Inner(others, fx)
            Board:AddEffect(fx)
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
            local envDamage = tool:GetEnvArtificialDamage(self, Board:GetPawn(location))
            local damage = SpaceDamage(location, envDamage)
            damage.sAnimation = "EnvArtificial_Animation" .. random_int(2)
            effect:AddDamage(damage)
            if IsPassiveSkill("EnvWeapon4") then
                effect:AddScript([[ -- 取消行动
                    local location = ]] .. location:GetString() .. [[
                    local pawn = Board:GetPawn(location)
                    if pawn and pawn:IsQueued() then -- 单位被击杀也不会进得来
                        pawn:ClearQueued()
                        Board:Ping(location, ENV_GLOBAL.themeColor)
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
    local mission = GetCurrentMission()
    local liveEnv = nil
    local liveLocations = nil
    local repeated = nil
    if self.IsOverlay then
        liveEnv = mission and mission.LiveEnvironment
        liveLocations = liveEnv and liveEnv:GetTrueLocations()
        repeated = liveLocations
    end
    local quarters = tool:GetEnvQuarters(repeated)
    if mission and mission.GetEnvForceZone then
        local zone = mission:GetEnvForceZone()
        quarters = tool:InsertUniformDistributionPoints(zone, quarters)
    end
    return tool:GetUniformDistributionPoints(self.BaseArea, quarters)
end

function this:Load()
    modApi:addNextTurnHook(function(mission)
        if tool:NeedInitEnvironment() then
            if Game:GetTeamTurn() == TEAM_ENEMY then -- 敌人回合开始时清信息
                mission.EnvArtificialGenerated = {}
            end
        end
    end)
end

return this
