local mod = mod_loader.mods[modApi.currentMod]
local tool = mod.tool

function BoardPawn:IsEnvHeavy()
    return _G[self:GetType()].EnvHeavy
end

function BoardPawn:GetBasicMoveSpeed()
    return _G[self:GetType()].MoveSpeed
end

function BoardPawn:IsEnvJumpMove()
    return tool:HasWeapon(self, "EnvWeapon1_B", true) or tool:HasWeapon(self, "EnvWeapon1_AB", true)
end

function BoardPawn:IsEnvOverloadActive()
    local mission = GetCurrentMission()
    if mission and mission.Overload then
        local pawnId = self:GetId()
        local turn = Game:GetTurnCount()
        if mission.Overload[pawnId] == turn then
            return true
        end
    end
    return false
end

-- BoardPawn 会覆盖 PawnType 上的方法，无法靠重载来实现
Jelly_Health1._psion = true -- 其他灵虫均继承自 Jelly_Health1
Jelly_Boss._psion = true
function BoardPawn:IsPsion()
    return _G[self:GetType()]._psion or false
end

-- 阻止爆卵虫将卵产在环境被动锁定的方格内，蜘蛛智商没有这么低不用做特殊处理
local _BlobberAtk1_GetTargetScore = BlobberAtk1.GetTargetScore
function BlobberAtk1:GetTargetScore(p1, p2, ...)
    return tool:IsEnvArtificialGenerated(p2) and -10 or _BlobberAtk1_GetTargetScore(self, p1, p2, ...)
end

-- 这个分数可以解释为，环境加载器能释放引诱特化 Vek 的激素
local function EnvScorePositioning(point, pawn, score, factor, center)
    if tool:HasEnvArtificialGenerated() then
        center = center or false
        factor = factor or math.random()
        local depg = tool:GetDistanceToEnvArtificialGenerated(point)
        if depg == 0 then
            score = -10 -- 绝对不能移动上去
        else
            score = score + math.max(4 - depg, 0) * factor
        end
        if center then
            local dc = tool:GetDistanceToCenter(point)
            if dc > 2 then
                score = score - 1
            elseif dc > 1 then
                score = score - 0.3
            end
        end
    end
    return score
end

local _ScorePositioning = ScorePositioning
function ScorePositioning(point, pawn, ...)
    local pawnClass = _G[pawn:GetType()]
    if pawnClass.ScorePositioning then
        return pawnClass:ScorePositioning(point, pawn, ...)
    elseif pawnClass.Tier == TIER_BOSS then
        local score = _ScorePositioning(point, pawn, ...)
        return EnvScorePositioning(point, pawn, score, math.random() * 0.4)
    else
    end
    return _ScorePositioning(point, pawn, ...)
end

local _Jelly_Health1_ScorePositioning = Jelly_Health1.ScorePositioning -- 防止其他 MOD 也重写了
-- 其他灵虫均继承自 Jelly_Health1
function Jelly_Health1:ScorePositioning(point, pawn, ...)
    local score = _Jelly_Health1_ScorePositioning and _Jelly_Health1_ScorePositioning(point, pawn, ...)
    if not score or type(score) ~= "number" then
        score = _ScorePositioning(point, pawn, ...)
    end
    return EnvScorePositioning(point, pawn, score, nil, true)
end

local _Jelly_Boss_ScorePositioning = Jelly_Boss.ScorePositioning
function Jelly_Boss:ScorePositioning(point, pawn, ...)
    local score = _Jelly_Boss_ScorePositioning and _Jelly_Boss_ScorePositioning(point, pawn, ...)
    if not score or type(score) ~= "number" then
        score = _ScorePositioning(point, pawn, ...)
    end
    return EnvScorePositioning(point, pawn, score, 1, true) -- 普通灵虫都已经被吸引了，灵虫 Boss 当然更容易被吸引
end
local _BlobBoss_ScorePositioning = BlobBoss.ScorePositioning
-- 分裂体继承自 BlobBoss
function BlobBoss:ScorePositioning(point, pawn, ...)
    local score = _BlobBoss_ScorePositioning and _BlobBoss_ScorePositioning(point, pawn, ...)
    if not score or type(score) ~= "number" then
        score = _ScorePositioning(point, pawn, ...)
    end
    return EnvScorePositioning(point, pawn, score, 1, true)
end
local _SpiderBoss_ScorePositioning = SpiderBoss.ScorePositioning
function SpiderBoss:ScorePositioning(point, pawn, ...)
    local score = _SpiderBoss_ScorePositioning and _SpiderBoss_ScorePositioning(point, pawn, ...)
    if not score or type(score) ~= "number" then
        score = _ScorePositioning(point, pawn, ...)
    end
    return EnvScorePositioning(point, pawn, score, 1, true)
end

local this = {}
function this:Load()
    -- nothing to do
end
return this
