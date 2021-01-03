local mod = mod_loader.mods[modApi.currentMod]
local tool = mod.tool

-- 获取真正意义上的 Locations
function Environment:GetTrueLocations()
    return self.Locations and self.Locations or {}
end
function Env_Tides:GetTrueLocations()
    local locations = {}
    for x = 0, 7 do
        locations[#locations + 1] = Point(x, self.Index)
    end
    for i, location in ipairs(self.Locations) do
        locations[#locations + 1] = location
    end
    return locations
end
function Env_Cataclysm:GetTrueLocations()
    local locations = {}
    for y = 0, 7 do
        locations[#locations + 1] = Point(7 - self.Index, y)
    end
    for i, location in ipairs(self.Locations) do
        locations[#locations + 1] = location
    end
    return locations
end

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
    local quarters = tool:GetEnvQuarters(repeated)
    quarters.quarters = true
    return quarters
end
-- 灾变额外区域
function Env_Cataclysm:SelectAdditionalSpace()
    local repeated = {}
    for y = 0, 7 do
        repeated[#repeated + 1] = Point(7 - self.Index, y)
    end
    local quarters = tool:GetEnvQuarters(repeated)
    quarters.quarters = true
    return quarters
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
local _Env_Tides_ApplyEffect = Env_Tides.ApplyEffect -- 真原版
-- 原版修改
function Env_Tides:_ApplyEffect()
    local allyImmue = IsPassiveSkill("Env_Weapon_4_A")
    local effect = SkillEffect()
    local building = {}
    for y = 0, self.Index do
        if y == self.Index then
            effect:AddSound("/props/tide_flood_last")
        else
            effect:AddSound("/props/tide_flood")
        end
        for x = 0, 7 do
            if Board:IsBuilding(Point(x, y)) then
                building[x] = y
            elseif building[x] ~= nil and building[x] < y then
                -- do nothing
            elseif not allyImmue or Board:GetPawnTeam(Point(x, y)) ~= TEAM_PLAYER then -- 友军免疫
                local floodAnim = SpaceDamage(Point(x, y))
                if y == self.Index then
                    floodAnim.iTerrain = TERRAIN_WATER
                    if Board:GetTerrain(Point(x, y)) == TERRAIN_MOUNTAIN then
                        floodAnim.iDamage = DAMAGE_DEATH
                    end
                end
                effect:AddDamage(floodAnim)
                effect:AddBounce(floodAnim.loc, -6)
            end
        end
        effect:AddDelay(0.2)
    end
    effect.iOwner = ENV_EFFECT
    Board:AddEffect(effect)
    self.Planned = false
    return false
end
function Env_Tides:ApplyEffect(...)
    local ret = self:_ApplyEffect(...)
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
local _Env_Cataclysm_ApplyEffect = Env_Cataclysm.ApplyEffect -- 真原版
-- 原版修改
function Env_Cataclysm:_ApplyEffect()
    local allyImmue = IsPassiveSkill("Env_Weapon_4_A")
    local effect = SkillEffect()
    local damage = SpaceDamage()
    damage.iTerrain = TERRAIN_HOLE
    damage.fDelay = 0.2
    effect:AddBoardShake(1.5)
    effect:AddSound("/props/ground_break_line")
    local x = 7 - self.Index
    for y = 0, 7 do
        if not allyImmue or Board:GetPawnTeam(Point(x, y)) ~= TEAM_PLAYER then
            damage.loc = Point(x, y)
            if not Board:IsBuilding(damage.loc) then
                effect:AddDamage(damage)
            end
        end
        Board:BlockSpawn(Point(x - 1, y), BLOCKED_PERM) -- can't have units spawn on the next set of doomed tiles
    end
    effect.iOwner = ENV_EFFECT
    Board:AddEffect(effect)
    return false
end
function Env_Cataclysm:ApplyEffect(...)
    local ret = self:_ApplyEffect(...)
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

-- 覆盖环境的 ApplyEffect 不一定有用，因为 IsEffect() 可能返回 false
local _Mission_ApplyEnvironmentEffect = Mission.ApplyEnvironmentEffect
function Mission:ApplyEnvironmentEffect(...)
    local env = self.LiveEnvironment
    if env and env.OverlayEnv then
        env.OverlayEnv:ApplyEffect()
    end
    return _Mission_ApplyEnvironmentEffect(self, ...)
end

-- 初始化关卡环境被动
local function EnvPassiveInit(mission)
    local envName = mission.Environment
    if envName == "Env_Null" or not envName or not mission.LiveEnvironment then
        mission.Environment = "Env_Passive"
        mission.LiveEnvironment = Env_Passive:new()
        mission.LiveEnvironment:Start()
        mission.MasteredEnv = true
        mission.NoOverlayEnv = true
    elseif envName == "Env_Tides" or envName == "Env_Cataclysm" then -- 纯手动处理
        mission.MasteredEnv = true
    elseif envName == "tosx_env_warps" or envName == "Env_lmn_Sequoia" then -- 有 Locations 但无法正常工作的神奇环境，由其他 MOD 引进，稍微兼容一下
        mission.SpecialEnv = true
    end
    mission.LiveEnvironment._env_init = true
end

-- 动态地修改环境
local function AdjustEnv(mission)
    if IsPassiveSkill("Env_Weapon_4") or tool:GetWeapon("Env_Weapon_2") then
        local env = mission.LiveEnvironment
        if env then
            env.OverlayEnv = Env_Passive:new{
                IsOverlay = true
            }
            env.OverlayEnv:Start()
            if env.OverlayEnv_Locations then -- 虽然看 SaveData 可知 env.OverlayEnv.Locations 有数据，但不知道为什么读不出来
                env.OverlayEnv.Locations = env.OverlayEnv_Locations
            end

            local _MarkBoard = env.MarkBoard
            function env:MarkBoard(...)
                local ret = _MarkBoard(self, ...)
                local mission = GetCurrentMission()
                local trueLocations = self:GetTrueLocations()
                self.OverlayEnv:MarkBoard()
                if IsPassiveSkill("Env_Weapon_4_A") and
                    (mission.MasteredEnv or (trueLocations and #trueLocations > 0 and not mission.SpecialEnv)) then
                    if not self:IsEffect() and not Board:IsBusy() then
                        self.CurrentAttack = nil
                    end
                    local icon = "combat/tile_icon/tile_airstrike.png"
                    local colors = {GL_Color(50, 200, 50, 0.75), GL_Color(20, 200, 20, 0.75)}
                    for i, location in ipairs(trueLocations) do
                        if Board:GetPawnTeam(location) == TEAM_PLAYER then
                            local focused = self.CurrentAttack == location or
                                                (self.Instant and self.CurrentAttack ~= nil)
                            Board:MarkSpaceImage(location, icon, focused and colors[2] or colors[1])
                            Board:MarkSpaceDesc(location, "passive0", false)
                        end
                    end
                end
                return ret
            end

            -- 覆盖环境计划，后续额外新增锁定方格
            -- 多次执行，返回 true 表示需继续执行，返回 false 表示执行完毕
            local _Plan = env.Plan
            function env:Plan(...)
                local ret = _Plan(self, ...)
                if not ret then -- 原规划完成后再加
                    if mission.MasteredEnv or (self.Locations and #self.Locations > 0 and not mission.SpecialEnv) then
                        if IsPassiveSkill("Env_Weapon_4_B") or IsPassiveSkill("Env_Weapon_4_AB") then
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
                                tool:EnvPassiveGenerate(env_planned)
                            end
                        end
                        -- 部分环境在后面会停止（如地震活动），如果之前检测到有活动就标记一下，不要发动空袭
                        if not mission.MasteredEnv then
                            mission.MasteredEnv = true
                        end
                    else
                        self.OverlayEnv:Plan()
                    end
                end
                return ret
            end

            -- 覆盖环境激活，优先击杀灵虫，并处理友军免疫
            -- 多次执行，返回 true 表示需继续执行，返回 false 表示执行完毕
            local _ApplyEffect = env.ApplyEffect
            function env:ApplyEffect(...)
                if IsPassiveSkill("Env_Weapon_4") then
                    local terminateEffect = SkillEffect()
                    local trueLocations = self:GetTrueLocations()
                    if #trueLocations > 0 then
                        terminateEffect:AddDelay(0.8) -- 加点延时，否则可能在环境击杀敌人前就执行
                        for i, location in ipairs(trueLocations) do -- 沉默敌人
                            terminateEffect:AddScript([[ -- 取消行动
                                local location = ]] .. location:GetString() .. [[
                                local pawn = Board:GetPawn(location)
                                if pawn and pawn:GetQueued() then -- 单位被击杀也不会进得来
                                    pawn:ClearQueued()
                                    Board:Ping(location, GL_Color(196, 182, 86, 0))
                                    Board:AddAlert(location, Global_Texts["Action_Terminated"])
                                end
                            ]])
                        end
                    end

                    if mission.MasteredEnv or (self.Locations and #self.Locations > 0 and not mission.SpecialEnv) then
                        local allyImmue = IsPassiveSkill("Env_Weapon_4_A")
                        local psions = {} -- 原版游戏中不可能出现多只水母，但鬼知道其他 MOD 会不会改
                        for i, location in ipairs(self.Locations) do
                            local pawn = Board:GetPawn(location)
                            if tool:IsPsion(pawn) then
                                psions[#psions + 1] = i
                            end
                        end
                        local ordered = self.Ordered
                        local points = {}
                        for i = #psions, 1, -1 do
                            psions[i] = table.remove(self.Locations, psions[i])
                        end
                        if ordered then
                            for i, location in ipairs(self.Locations) do
                                if not allyImmue or Board:GetPawnTeam(location) ~= TEAM_PLAYER then -- 友军免疫
                                    points[#points + 1] = location
                                end
                            end
                            self.Locations = {}
                        else
                            while #self.Locations > 0 do
                                local p = random_removal(self.Locations)
                                if not allyImmue or Board:GetPawnTeam(p) ~= TEAM_PLAYER then -- 友军免疫
                                    points[#points + 1] = p
                                end
                            end
                        end
                        for i, psion in ipairs(psions) do
                            self.Locations[#self.Locations + 1] = psion
                        end
                        for i, point in ipairs(points) do
                            self.Locations[#self.Locations + 1] = point
                        end

                        -- 经过调整后，灵虫所在的方格总是在最开始执行
                        if #self.Locations > 0 then
                            self.Ordered = true
                            local ret = _ApplyEffect(self, ...)
                            self.Ordered = ordered
                            if not ret then
                                Board:AddEffect(terminateEffect)
                            end
                            return ret
                        else
                            -- 可能会因为 Locations 为空运行出错
                            local success, ret = pcall(_ApplyEffect, self, ...)
                            if not success or not ret then
                                Board:AddEffect(terminateEffect)
                            end
                            if success then
                                return ret
                            else
                                return false
                            end
                        end
                    end
                    -- 只要在环境被动范围内，就添加行动终止
                    local ret = _ApplyEffect(self, ...)
                    if not ret then
                        Board:AddEffect(terminateEffect)
                    end
                    return ret
                end
                return _ApplyEffect(self, ...)
            end

            -- 序列化之前要将对象上的方法移除，否则存到 SaveData 上时会坑爹
            function env:OnSerializationStart(temp)
                temp.MarkBoard = self.MarkBoard
                temp.Plan = self.Plan
                temp.ApplyEffect = self.ApplyEffect
                self.MarkBoard = nil
                self.Plan = nil
                self.ApplyEffect = nil
                -- 手动存一下 OverlayEnv.Locations
                self.OverlayEnv_Locations = self.OverlayEnv.Locations
            end
            function env:OnSerializationEnd(temp)
                self.MarkBoard = temp.MarkBoard
                self.Plan = temp.Plan
                self.ApplyEffect = temp.ApplyEffect
            end
        else
            mission.Environment = "Env_Passive"
            mission.LiveEnvironment = Env_Passive:new()
            mission.LiveEnvironment:Start()
            mission.MasteredEnv = true
            mission.NoOverlayEnv = true
        end
    end
end

local Environment = {}
function Environment:Load()
    -- MissionStartHook 对应的是关卡生成，此时添加会导致人造环境显示在警告中
    -- 没有对应真正意义上的“关卡开始”钩子，只能用 NextTurnHook 来顶替
    modApi:addNextTurnHook(function(mission)
        -- 添加人造环境，不需要添加到继续游戏的 Hook 中，设置了 Environment 后会自动加载
        if not mission.Env_Init then
            if IsPassiveSkill("Env_Weapon_4") or tool:GetWeapon("Env_Weapon_2") then
                EnvPassiveInit(mission)
                if not mission.NoOverlayEnv then
                    AdjustEnv(mission)
                end
            end
            mission.Env_Init = true
        elseif not mission.LiveEnvironment or not mission.LiveEnvironment._env_init then -- 部分 MOD 环境可能会自删
            mission.LiveEnvironment = nil
            AdjustEnv(mission)
            mission.LiveEnvironment._env_init = true
        end
    end)
    modApi:addPostLoadGameHook(function() -- 继续游戏
        modApi:runLater(function(mission)
            if mission.Env_Init and not mission.NoOverlayEnv then
                AdjustEnv(mission)
            end
            if mission.EnvPassive_Planned then
                -- 如果有没有执行完的 plan，继续执行
                tool:EnvPassiveGenerate(mission.EnvPassive_Planned, mission.EnvPassive_Planned_Overlay)
            end
        end)
    end)
    modApi:addTestMechEnteredHook(function(mission)
        -- 机甲测试无需检查，直接给环境
        if not mission.Env_Init then
            EnvPassiveInit(mission)
            mission.Env_Init = true
        end
    end)
end
return Environment
