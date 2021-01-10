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
        local psions = {} -- 原版游戏中不可能出现多只水母，但鬼知道其他 MOD 会不会改
        local others = {} -- 其他 pawn
        effect.iOwner = ENV_EFFECT
        effect:AddSound("/impact/generic/explosion_large")
        local allyImmue = IsPassiveSkill("Env_Weapon_4_A")
        for i, location in ipairs(self.Locations) do
            if not allyImmue or Board:GetPawnTeam(location) ~= TEAM_PLAYER then
                local pawn = Board:GetPawn(location)
                if tool:IsPsion(pawn) then
                    psions[#psions + 1] = location
                else
                    others[#others + 1] = location
                end
            end
        end
        if #psions > 0 then
            self:ApplyEffect_Inner(psions, effect)
            effect:AddDelay(0.5)
            self.Locations = others
            Board:AddEffect(effect)
            return true
        else
            -- 不能在击杀灵虫后接一个延时立即在 effect 上添加其他效果
            -- 这样由于没有结算完毕，灵虫的效果依然还在
            self:ApplyEffect_Inner(others, effect)
            self.Locations = {}
            Board:AddEffect(effect)
            return false
        end
    end
end

function Env_Passive:ApplyEffect_Inner(locations, effect)
    for i, location in ipairs(locations) do
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
                    Board:AddAlert(location, EnvMod_Texts.action_terminated)
                end
            ]])
        end
    end
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

local _ScorePositioning = ScorePositioning
function ScorePositioning(point, pawn, ...)
    local pawnClass = _G[pawn:GetType()]
    if pawnClass.ScorePositioning then
        return pawnClass:ScorePositioning(point, pawn, ...)
    end
    return _ScorePositioning(point, pawn, ...)
end

local function EnvScorePositioning(point, pawn, score, factor)
    if tool:HasEnvPassiveGenerated() then
        factor = factor or math.random()
        local depg = tool:GetDistanceToEnvPassiveGenerated(point)
        if depg == 0 then
            score = 0
        else
            score = score + math.max(4 - depg, 0) * factor
        end
        local dc = tool:GetDistanceToCenter(point)
        if dc > 2 then
            score = score - 1
        elseif dc > 1 then
            score = score - 0.3
        end
    end
    return score
end

local _Jelly_Health1_ScorePositioning = Jelly_Health1.ScorePositioning -- 防止其他 MOD 也重写了
-- 其他灵虫均继承自 Jelly_Health
function Jelly_Health1:ScorePositioning(point, pawn, ...)
    local score = _Jelly_Health1_ScorePositioning and _Jelly_Health1_ScorePositioning(point, pawn, ...)
    if not score or type(score) ~= "number" then
        score = _ScorePositioning(point, pawn, ...)
    end
    return EnvScorePositioning(point, pawn, score)
end
local _Jelly_Boss_ScorePositioning = Jelly_Boss.ScorePositioning
function Jelly_Boss:ScorePositioning(point, pawn, ...)
    local score = _Jelly_Boss_ScorePositioning and _Jelly_Boss_ScorePositioning(point, pawn, ...)
    if not score or type(score) ~= "number" then
        score = _ScorePositioning(point, pawn, ...)
    end
    return EnvScorePositioning(point, pawn, score)
end
local _BlobBoss_ScorePositioning = BlobBoss.ScorePositioning
-- 分裂体继承自 BlobBoss
function BlobBoss:ScorePositioning(point, pawn, ...)
    local score = _BlobBoss_ScorePositioning and _BlobBoss_ScorePositioning(point, pawn, ...)
    if not score or type(score) ~= "number" then
        score = _ScorePositioning(point, pawn, ...)
    end
    return EnvScorePositioning(point, pawn, score, 1)
end

local function BurrowerScorePositioning(point, pawn)
    if Board:IsPod(point) then
        return -10
    end
    if Board:GetTerrain(point) == TERRAIN_HOLE and not pawn:IsFlying() then
        return -10
    end
    if Board:IsTargeted(point) then
        return pawn:GetDangerScore()
    end
    if Board:IsSmoke(point) then
        return -2
    end
    if Board:IsFire(point) and not pawn:IsFire() then
        return -10
    end
    if Board:IsSpawning(point) then
        return -10
    end
    if Board:IsDangerous(point) then
        local p = 0.1 * (Board:GetPawnCount(TEAM_ENEMY) - 3)
        local dangerPawnCnt = 0
        local enemies = extract_table(Board:GetPawns(TEAM_ENEMY))
        for i, id in ipairs(enemies) do
            local type = Board:GetPawn(id):GetType()
            if type == "Burrower1" or type == "Burrower2" or type == "Jelly_Explode1" or type == "Jelly_Boss" then
                dangerPawnCnt = dangerPawnCnt + 1
            end
        end
        -- 由于在地底，有一定概率无法发现环境，概率与危险敌人的平方成正比
        if math.random() > p * dangerPawnCnt ^ 2 then
            return -10
        end
    end
    if Board:IsDangerousItem(point) and pawn:IsAvoidingMines() then
        return -10
    end
    if Board:GetTerrain(point) == TERRAIN_WATER and not pawn:IsFlying() then
        return -5
    end
    local custom = pawn:GetCustomPositionScore(point)
    if custom ~= 0 then
        return custom
    end
    local edge1 = point.x == 0 or point.x == 7
    local edge2 = point.y == 0 or point.y == 7
    if edge1 and edge2 then
        return -2 -- really avoid corners
    elseif edge1 or edge2 then
        return 0 -- edges are discouraged
    end
    local enemy = (pawn:GetTeam() == TEAM_PLAYER) and TEAM_ENEMY or
                      TEAM_PLAYER
    if not pawn:IsRanged() then
        for i = DIR_START, DIR_END do
            if Board:IsPawnTeam(point + DIR_VECTORS[i], enemy) then
                return 5
            end
            if Board:IsBuilding(point + DIR_VECTORS[i]) then
                return 5
            end
        end
        local closest_pawn = Board:GetDistanceToPawn(point, enemy)
        local closest_building = Board:GetDistanceToBuilding(point)
        local closest = math.min(closest_pawn, closest_building) -- should some pawns emphasize one over the other?
        return math.max(0, (10 - closest) / 2)
    end
    return 5
end

-- 掘地虫在地底下，并不一定能察觉到危险
local _Burrower1_ScorePositioning = Burrower1.ScorePositioning
function Burrower1:ScorePositioning(point, pawn, ...)
    if tool:IsEnvPassiveGenerated(point) then
        return BurrowerScorePositioning(point, pawn)
    else
        local score = _Burrower1_ScorePositioning and _Burrower1_ScorePositioning(point, pawn, ...)
        if not score or type(score) ~= "number" then
            score = _ScorePositioning(point, pawn, ...)
        end
        return score
    end
end
-- 这两种敌人并不是继承关系……
local _Burrower2_ScorePositioning = Burrower2.ScorePositioning
function Burrower2:ScorePositioning(point, pawn, ...)
    if tool:IsEnvPassiveGenerated(point) then
        return BurrowerScorePositioning(point, pawn)
    else
        local score = _Burrower2_ScorePositioning and _Burrower2_ScorePositioning(point, pawn, ...)
        if not score or type(score) ~= "number" then
            score = _ScorePositioning(point, pawn, ...)
        end
        return score
    end
end

function Env_Passive:Load()
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
