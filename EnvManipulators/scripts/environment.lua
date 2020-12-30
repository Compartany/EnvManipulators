local mod = mod_loader.mods[modApi.currentMod]
local tool = mod.tool

-- 选择额外区域
function Env_Attack:SelectAdditionalSpace()
    local ret = tool:GetEnvQuarters(self.Locations)
    ret.quarters = true
    return ret
end
-- 地震活动额外区域
function Env_Seismic:SelectAdditionalSpace()
    local ret = {
        quarters = true
    }
    local quarters = Env_Attack.SelectAdditionalSpace(self)
    for i, quarter in ipairs(quarters) do
        ret[i] = {}
        for j, space in ipairs(quarter) do
            if Board:GetTerrain(space) ~= TERRAIN_HOLE and not tool:IsRepeatedTile(space, self.Path) then
                ret[i][#ret[i] + 1] = space
            end
        end
    end
    return ret
end
-- 空中支援额外区域
function Env_Airstrike:SelectAdditionalSpace()
    local ret = {}
    local start = Point(3, 1)
    local choices = {}
    for i = start.x, (start.x + 2) do
        for j = start.y, (start.y + 5) do
            local point = Point(i, j)
            local spaces = self:GetAttackArea(point)
            local valid = true
            if not tool:IsValidEnvTarget(point, self.Locations) then
                valid = false
            else
                for k = 2, #spaces do
                    if not self:IsValidTarget(spaces[k]) then
                        valid = false
                        break
                    end
                end
            end
            if valid then
                choices[#choices + 1] = point
            end
        end
    end
    if #choices > 0 then
        ret[#ret + 1] = random_removal(choices) -- 增加一次算了，否则太 IMBA
    end
    return ret
end

local Env_Volcano_SelectSpaces = Env_Volcano.SelectSpaces
function Env_Volcano:SelectSpaces()
    -- 补充缺失的局部变量
    local ENV_ROCKS = 1
    local ENV_LAVA = 2

    self.Phase = self.Phase + 1
    if self.Phase > 4 then
        self.Phase = 1
    end
    if self.Mode == ENV_ROCKS then
        self.Mode = ENV_LAVA
    else
        self.Mode = ENV_ROCKS
    end

    local ret = {}
    if self.Phase == 1 or self.Phase == 3 then
        local curr = random_removal(self.LavaStart)
        ret[1] = curr
        for i = 1, 3 do
            local dirs = {DIR_RIGHT, DIR_DOWN}
            local choices = {}
            for j, v in ipairs(dirs) do
                local choice = curr + DIR_VECTORS[v]
                if not Board:IsTerrain(choice, TERRAIN_LAVA) and not Board:IsTerrain(choice, TERRAIN_MOUNTAIN) and
                    not Board:IsTerrain(choice, TERRAIN_BUILDING) then
                    choices[#choices + 1] = choice
                end
            end
            if #choices == 0 then
                break
            end
            curr = random_removal(choices)
            ret[#ret + 1] = curr
        end
    elseif self.Phase == 2 or self.Phase == 4 then
        local quarters = self:GetQuarters()
        for i, v in ipairs(quarters) do
            local choice = Point(1, 1)
            while choice == Point(1, 1) and #v > 0 do -- 原来这个地方 v 中只有 Point(1, 1) 会死循环
                choice = random_removal(v)
            end
            if choice ~= Point(1, 1) then -- Point(1, 1) 就别加了，影响关卡自洽感；当然环境被动会补上，但这是外部因素
                ret[#ret + 1] = choice
            end
        end
    end
    return ret
end

-- 覆盖环境计划，后续额外新增锁定方格
-- 多次执行，返回 true 表示需继续执行，返回 false 表示执行完毕
local _Env_Attack_Plan = Env_Attack.Plan
function Env_Attack:Plan(...)
    local ret = _Env_Attack_Plan(self, ...)
    local mission = GetCurrentMission()
    if not ret and (IsPassiveSkill("Env_Weapon_4_B") or IsPassiveSkill("Env_Weapon_4_AB")) then -- 原规划完成后再加
        if mission.MasteredEnv or (self.Locations and #self.Locations > 0) then
            local additionalArea = tool:GetEnvPassiveUpgradeAreaValue()
            local spaces = self:SelectAdditionalSpace()
            local env_planned = {}
            if spaces.quarters then
                local quarters = spaces
                local qa = {}
                local qb = {}
                local qc = nil
                for i = 1, additionalArea do
                    -- 总是从对角线两侧的象限中选择
                    if #qa == 0 then
                        qa = {{1, 3}, {2, 4}}
                    end
                    if #qb == 0 then
                        qb = random_removal(qa)
                    end
                    qc = random_removal(qb)
                    if #quarters[qc] > 0 then
                        env_planned[#env_planned + 1] = random_removal(quarters[qc])
                    end
                end
            else
                for i = 1, additionalArea do
                    if #spaces == 0 then
                        break
                    end
                    env_planned[#env_planned + 1] = random_removal(spaces)
                end
            end
            if #env_planned > 0 then
                tool:Env_Passive_Generate(env_planned)
            end
            -- 部分环境在后面会停止（如地震活动），如果之前检测到有活动就标记一下，不要发动空袭
            if not mission.MasteredEnv then
                mission.MasteredEnv = true
            end
        end
    end
    return ret
end

-- 覆盖环境激活，优先击杀灵虫
-- 多次执行，返回 true 表示需继续执行，返回 false 表示执行完毕
local _Env_Attack_ApplyEffect = Env_Attack.ApplyEffect
function Env_Attack:ApplyEffect(...)
    if IsPassiveSkill("Env_Weapon_4") then
        local psions = {}
        for i, location in ipairs(self.Locations) do
            local pawn = Board:GetPawn(location)
            if tool:IsPsion(pawn) then
                psions[#psions + 1] = i
            end
        end
        if #psions > 0 then
            local ordered = self.Ordered
            local points = {}
            for i = 1, #psions do
                psions[i] = table.remove(self.Locations, psions[i])
            end
            if ordered then
                points = self.Locations
                self.Locations = {}
            else
                while #self.Locations > 0 do
                    points[#points + 1] = random_removal(self.Locations)
                end
            end
            for i, psion in ipairs(psions) do
                self.Locations[#self.Locations + 1] = psion
            end
            for i, point in ipairs(points) do
                self.Locations[#self.Locations + 1] = point
            end

            -- 经过调整后，灵虫所在的方格总是在最开始执行
            self.Ordered = true
            local ret = _Env_Attack_ApplyEffect(self, ...)
            self.Ordered = ordered
            return ret
        end
    end
    return _Env_Attack_ApplyEffect(self, ...)
end

local Environment = {}
function Environment:Load()
    -- MissionStartHook 对应的是关卡生成，此时添加会导致人造环境显示在警告中
    -- 没有对应真正意义上的“关卡开始”钩子，只能用 NextTurnHook 来顶替
    modApi:addNextTurnHook(function(mission)
        -- 添加人造环境，不需要添加到继续游戏的 Hook 中，设置了 Environment 后会自动加载
        if not mission.Env_Init then
            if IsPassiveSkill("Env_Weapon_4") or tool:GetWeapon("Env_Weapon_2") then
                tool:Env_Passive_Init(mission)
            end
            mission.Env_Init = true
        end
    end)
    modApi:addTestMechEnteredHook(function(mission)
        -- 机甲测试无需检查，直接给环境
        if not mission.Env_Init then
            tool:Env_Passive_Init(mission)
            mission.Env_Init = true
        end
    end)
    modApi:addPreEnvironmentHook(function(mission)
        -- 存在环境却无 Locations，说明无法操纵，请求空援
        -- 这种环境一般都重写了 Plan()，故只能用 Hook 来做
        if Game:GetTurnCount() > 0 then -- 首回合 Locations 必然为空，跳过
            -- 没有 Enhanced 也空袭吧，否则太难打了
            local env = mission.LiveEnvironment
            if not mission.MasteredEnv and (not env.Locations or #env.Locations == 0) then
                local point = nil
                local points = {}
                local enemies = extract_table(Board:GetPawns(TEAM_ENEMY))
                for i, id in ipairs(enemies) do
                    local pawn = Board:GetPawn(id)
                    local space = pawn:GetSpace()
                    if Board:IsValid(space) then -- 例外如大岩蛇钻到地底
                        if tool:IsPsion(pawn) then
                            point = space
                            break
                        end
                        points[#points + 1] = space
                    end
                end
                if not point and #points > 0 then
                    point = random_element(points)
                end
                if point then
                    ENV_GLOBAL.Env_Target = point
                    local e = SkillEffect()
                    e:AddScript(tool:GetAirSupportScript())
                    Board:AddEffect(e)
                end
            end
        end
    end)
end
return Environment
