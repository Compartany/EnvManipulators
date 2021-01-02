local mod = mod_loader.mods[modApi.currentMod]
local tool = mod.tool

-- 选择额外区域
function Environment:SelectAdditionalSpace()
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
-- 巨浪额外区域
function Env_Tides:SelectAdditionalSpace()
    local repeated = {}
    for x = 0, 7 do
        repeated[#repeated + 1] = Point(x, self.Index)
    end
    return tool:GetEnvQuarters(repeated)
end
-- 灾变额外区域
function Env_Cataclysm:SelectAdditionalSpace()
    local repeated = {}
    for y = 0, 7 do
        repeated[#repeated + 1] = Point(7 - self.Index, y)
    end
    return tool:GetEnvQuarters(repeated)
end

-- 防止火山环境死循环
local _Env_Volcano_SelectSpaces = Env_Volcano.SelectSpaces
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
            if choice ~= Point(1, 1) then -- Point(1, 1) 就别加了，影响关卡自洽感
                ret[#ret + 1] = choice
            end
        end
    end
    return ret
end
-- 优化一下岩浆环境
local _Env_Volcano_GetAttackEffect = Env_Volcano.GetAttackEffect
function Env_Volcano:GetAttackEffect(location, effect, ...)
    effect = effect or SkillEffect()
    if self.Mode == 2 then -- ENV_LAVA == 2
        local damage = SpaceDamage(location, 0)
        effect:AddSound("/props/lava_tile") -- 声音还是给一下吧
        if location ~= Point(1, 1) then
            -- 火山关卡如果 Point(1, 1) 变成岩浆会很奇怪，稍微处理一下
            -- Point(0, 0), Point(0, 1), Point(1, 0) 都被做了特殊处理，只要 Point(1, 1) 没变都进不去，不用额外处理
            damage.iTerrain = TERRAIN_LAVA
            if Board:GetTerrain(location) == TERRAIN_MOUNTAIN or Board:IsBuilding(location) then
                damage.iDamage = DAMAGE_DEATH
            end
        end
        effect:AddDamage(damage)
    else
        effect = _Env_Volcano_GetAttackEffect(self, location, effect, ...)
    end
    return effect
end

-- 支持巨浪环境
local _Env_Tides_Start = Env_Tides.Start
function Env_Tides:Start(...)
    self.Locations = {}
    return _Env_Tides_Start(self, ...)
end
local _Env_Tides_MarkBoard = Env_Tides.MarkBoard
function Env_Tides:MarkBoard(...)
    if self.Planned then
        for i, location in ipairs(self.Locations) do
            Board:MarkSpaceImage(location, self.CombatIcon, GL_Color(255, 226, 88, 0.75))
            Board:MarkSpaceDesc(location, "high_tide")
        end
        return _Env_Tides_MarkBoard(self, ...)
    end
end
local _Env_Tides_ApplyEffect = Env_Tides.ApplyEffect
function Env_Tides:ApplyEffect(...)
    local ret = _Env_Tides_ApplyEffect(self, ...)
    local effect = SkillEffect()
    for i, location in ipairs(self.Locations) do
        local floodAnim = SpaceDamage(location)
        effect:AddSound("/props/tide_flood_last")
        floodAnim.iTerrain = TERRAIN_WATER
        if Board:GetTerrain(location) == TERRAIN_MOUNTAIN or Board:IsBuilding(location) then
            floodAnim.iDamage = DAMAGE_DEATH
        end
        effect:AddDamage(floodAnim)
        effect:AddBounce(floodAnim.loc, -6)
    end
    effect:AddDelay(0.2)
    effect.iOwner = ENV_EFFECT
    Board:AddEffect(effect)
    self.Locations = {}
    self.Planned = false
    return ret
end
local _Env_Tides_Plan = Env_Tides.Plan
function Env_Tides:Plan(...)
    local ret = _Env_Tides_Plan(self, ...)
    local additionalArea = tool:GetEnvPassiveUpgradeAreaValue()
    local spaces = self:SelectAdditionalSpace()
    local env_planned = tool:GetUniformDistributionPoints(additionalArea, spaces)
    if #env_planned > 0 then
        tool:Env_Passive_Generate(env_planned)
    end
    return ret
end

-- 支持灾变环境
local _Env_Cataclysm_Start = Env_Cataclysm.Start
function Env_Cataclysm:Start(...)
    self.Locations = {}
    return _Env_Cataclysm_Start(self, ...)
end
local _Env_Cataclysm_MarkBoard = Env_Cataclysm.MarkBoard
function Env_Cataclysm:MarkBoard(...)
    for i, location in ipairs(self.Locations) do
        Board:MarkSpaceImage(location, self.CombatIcon, GL_Color(255, 226, 88, 0.75))
        Board:MarkSpaceDesc(location, "seismic")
    end
    return _Env_Cataclysm_MarkBoard(self, ...)
end
local _Env_Cataclysm_ApplyEffect = Env_Cataclysm.ApplyEffect
function Env_Cataclysm:ApplyEffect(...)
    local ret = _Env_Cataclysm_ApplyEffect(self, ...)
    local effect = SkillEffect()
    for i, location in ipairs(self.Locations) do
        local damage = SpaceDamage(location)
        damage.iTerrain = TERRAIN_HOLE
        damage.fDelay = 0.2
        if Board:IsBuilding(location) then
            damage.iDamage = DAMAGE_DEATH
        end
        effect:AddDamage(damage)
    end
    effect.iOwner = ENV_EFFECT
    Board:AddEffect(effect)
    self.Locations = {}
    return ret
end
local _Env_Cataclysm_Plan = Env_Cataclysm.Plan
function Env_Cataclysm:Plan(...)
    local ret = _Env_Cataclysm_Plan(self, ...)
    local additionalArea = tool:GetEnvPassiveUpgradeAreaValue()
    local spaces = self:SelectAdditionalSpace()
    local env_planned = tool:GetUniformDistributionPoints(additionalArea, spaces)
    if #env_planned > 0 then
        tool:Env_Passive_Generate(env_planned)
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
                env_planned = tool:GetUniformDistributionPoints(additionalArea, spaces, env_planned)
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
            if IsPassiveSkill("Env_Weapon_4") and not mission.MasteredEnv and (not env.Locations or #env.Locations == 0) then
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
