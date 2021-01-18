local mod = mod_loader.mods[modApi.currentMod]
local tool = mod.tool
local pawnMap = tool:GetMap("pawnMap")

-- 这种判断方式具有延时性，Hook 进入时无法判断是否获取到最新数据，故无法靠 TMS Hook 来解决
-- 当然可以在 UpdateSaveData Hook 中处理，但 UpdateSaveData 非常频繁，属实没有必要，每次都算一遍反而更优
local function IsEnvWeapon1_B_TMS(pawn)
    local wp1 = tool:GetWeapon("Env_Weapon_1")
    return (wp1 == "B" or wp1 == "AB") and tool:HasWeapon(pawn, "Env_Weapon_1")
end

function BoardPawn:IsEnvHeavy()
    return _G[self:GetType()].EnvHeavy
end

function BoardPawn:GetBasicMoveSpeed()
    return _G[self:GetType()].MoveSpeed
end

function BoardPawn:IsEnvIgnoreWeb()
    if self:IsIgnoreWeb() then
        return false
    elseif IsTestMechScenario() then
        return IsEnvWeapon1_B_TMS(self)
    else
        return pawnMap:Get(self:GetId(), "IgnoreWeb")
    end
end

function BoardPawn:IsEnvJumpMove()
    -- jumper 也得处理
    if IsTestMechScenario() then
        return IsEnvWeapon1_B_TMS(self)
    else
        return pawnMap:Get(self:GetId(), "JumpMove")
    end
end

-- BoardPawn 会覆盖 PawnType 上的方法，无法靠重载来实现
Jelly_Health1._psion = true -- 其他灵虫均继承自 Jelly_Health1
Jelly_Boss._psion = true
function BoardPawn:IsPsion()
    return _G[self:GetType()]._psion or false
end

-- 阻止爆卵虫将卵产在环境被动锁定的方格内，蜘蛛智商没有这么低不用做特殊处理
-- 这是游戏后期难度偏低的主要原因之一！这个处理偶尔会失效，不知道是什么原因导致的
local _BlobberAtk1_GetTargetScore = BlobberAtk1.GetTargetScore
function BlobberAtk1:GetTargetScore(p1, p2, ...)
    return tool:IsEnvArtificialGenerated(p2) and -10 or _BlobberAtk1_GetTargetScore(self, p1, p2, ...)
end

-- 各种关卡生成敌人也要避开环境锁定的方格，以提高难度
local _Mission_FlyingSpawns = Mission.FlyingSpawns
function Mission:FlyingSpawns(origin, count, pawn, projectile_info, exclude, ...)
    exclude = exclude or {}
    if self.EnvArtificialGenerated and #self.EnvArtificialGenerated > 0 then
        for i, location in ipairs(self.EnvArtificialGenerated) do
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
    if tool:HasEnvArtificialGenerated() then
        factor = factor or math.random()
        local depg = tool:GetDistanceToEnvArtificialGenerated(point)
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
-- 其他灵虫均继承自 Jelly_Health1
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
        local p = 0.1 * math.max(Board:GetPawnCount(TEAM_ENEMY) - 2, 0) ^ 2
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
    local enemy = (pawn:GetTeam() == TEAM_PLAYER) and TEAM_ENEMY or TEAM_PLAYER
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
    if tool:IsEnvArtificialGenerated(point) then
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
    if tool:IsEnvArtificialGenerated(point) then
        return BurrowerScorePositioning(point, pawn)
    else
        local score = _Burrower2_ScorePositioning and _Burrower2_ScorePositioning(point, pawn, ...)
        if not score or type(score) ~= "number" then
            score = _ScorePositioning(point, pawn, ...)
        end
        return score
    end
end

local this = {}
function this:Load()
    -- nothing to do
end
return this
