local this = {}

local Map = {
    T = {}
}
function Map:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end
function Map:Clear()
    self.T = {}
end
function Map:Set(id, key, val)
    if not self.T[id] then
        self.T[id] = {}
    end
    self.T[id][key] = val
end
function Map:Get(id, key)
    return self.T[id] and self.T[id][key]
end
this.Map = Map
this._maps = {}

-- 获取 Map
function this:GetMap(key)
    if not this._maps[key] then
        this._maps[key] = this.Map:new()
    end
    return this._maps[key]
end

-- 判断是否为环境操纵者小队
function this:IsSquad()
    local squad = GAME.squadTitles["TipTitle_" .. GameData.ach_info.squad]
    return squad == "环境操纵者" or squad == "EnvManipulators" -- 不要用 EnvMod_Texts.squad_name 来判断，否则换了语言就不对
end

-- 提取武器名称与升级
function this:ExtractWeapon(weapon)
    local upgrade = "Z"
    if modApi:stringEndsWith(weapon, "_A") then
        upgrade = "A"
    elseif modApi:stringEndsWith(weapon, "_B") then
        upgrade = "B"
    elseif modApi:stringEndsWith(weapon, "_AB") then
        upgrade = "AB"
    end
    local name = weapon
    if upgrade ~= "Z" then
        local s = string.find(weapon, "_" .. upgrade .. "$")
        if s > 1 then
            name = string.sub(weapon, 1, s - 1)
        else
            name = ""
        end
    end
    return name, upgrade
end

-- 判断机甲是否有装备
-- 自定义中有同名机甲时，判断会出错。
-- 且由于 GameData 数据具有延后性，更换装备到其他机甲上后，不能立即获得正确的最新位置，正常情况下还是可能出错。
function this:HasWeapon(pawn, weapon)
    if pawn then
        local pt = pawn:GetPawnTable()
        if pt.id then
            return pt and pt.primary == weapon or pt.secondary == weapon
        elseif GameData and GameData.current and GameData.current.mechs then
            -- 任何情况下都可使用，但有延时性
            local wpNo = self:GetWeaponNo(weapon)
            if wpNo then
                local mechNo = math.ceil(wpNo / 2)
                local mech = GameData.current.mechs[mechNo]
                return mech == pawn:GetType() -- 自定义中有同名机甲时，判断会出错
            end
        end
    end
    return false
end

-- 获得机甲序号
function this:GetMechNo(name)
    if GameData and GameData.current and GameData.current.mechs then
        for i, mech in ipairs(GameData.current.mechs) do
            if mech == name then
                return i
            end
        end
    end
    return nil
end

-- 获得装备序号
function this:GetWeaponNo(name)
    if GameData and GameData.current and GameData.current.weapons then
        for i, weapon in ipairs(GameData.current.weapons) do
            if modApi:stringStartsWith(weapon, name) then
                if #weapon - #name <= 3 then
                    return i
                end
            end
        end
    end
    return nil
end

-- 判断指定装备是否生效，也可活动装备的升级状态
-- 被动可用 IsPassiveSkill() 检测，同样可判断装备升级状态
function this:GetWeapon(name)
    if GameData and GameData.current and GameData.current.weapons then
        for _, weapon in ipairs(GameData.current.weapons) do
            local wp, u = this:ExtractWeapon(weapon)
            if wp == name then
                return u
            end
        end
    end
    return nil
end

-- 判断方格是否在集合内
function this:IsRepeatedTile(space, repeated)
    for _, location in ipairs(repeated) do
        if space == location then
            return true
        end
    end
    return false
end

-- 找出装备环境被动的机甲，添加环境锁定特效
function this:EnvArtificialGenerate(planned, overlay)
    overlay = overlay or false
    local mission = GetCurrentMission()
    -- 赶紧把状态存进 mission 里，防止保存游戏时没保存上
    if overlay then
        mission.EnvArtificial_Planned_Overlay = planned
    else
        mission.EnvArtificial_Planned = planned
    end
    local pawns = extract_table(Board:GetPawns(TEAM_MECH))
    local bounceAmount = 10
    for _, id in ipairs(pawns) do
        local pawn = Board:GetPawn(id)
        if self:HasWeapon(pawn, "Env_Weapon_4") then
            local point = pawn:GetSpace()
            if point and not pawn:IsDead() and not pawn:IsFrozen() and
                (pawn:IsFlying() or Board:GetTerrain(point) ~= TERRAIN_WATER) then
                if not mission.EnvArtificialGenerated then
                    mission.EnvArtificialGenerated = {}
                end
                for _, location in ipairs(planned) do
                    mission.EnvArtificialGenerated[#mission.EnvArtificialGenerated + 1] = location
                end
                local fx = SkillEffect()
                local damage = SpaceDamage(point, 0)
                damage.sSound = "/weapons/gravwell"
                fx:AddDamage(damage)
                fx:AddBounce(point, bounceAmount)
                for i, space in ipairs(planned) do
                    -- Board:BlockSpawn(space, BLOCKED_TEMP) -- 只在关卡开始时调用才生效，原版游戏的各种处理同样无效
                    Board:SetDangerous(space)
                    damage = SpaceDamage(space, 0)
                    local delay = i < #planned and NO_DELAY or FULL_DELAY
                    damage.sAnimation = "EnvExplo"
                    damage.sSound = "/impact/generic/explosion"
                    fx:AddArtillery(point, damage, "effects/env_shot_U.png", delay)
                end
                fx:AddScript(string.format([[
                    local overlay = %s
                    local mission = GetCurrentMission()
                    local env = overlay and mission.LiveEnvironment.OverlayEnv or mission.LiveEnvironment
                    local planned = overlay and mission.EnvArtificial_Planned_Overlay or mission.EnvArtificial_Planned
                    for _, epp in ipairs(planned) do
                        env.Locations[#env.Locations + 1] = epp
                    end
                    Game:TriggerSound("/props/square_lightup")
                    if overlay then
                        mission.EnvArtificial_Planned_Overlay = nil
                    else
                        mission.EnvArtificial_Planned = nil
                    end
                ]], tostring(overlay)))
                Board:AddEffect(fx)
                break -- 多个环境被动会被游戏禁止，不用考虑这种问题
            else
                Game:AddTip("EnvArtificialDisabled", point)
            end
        end
    end
end

-- 判断方格是否为被环境被动锁定
function this:IsEnvArtificialGenerated(point)
    local mission = GetCurrentMission()
    if mission and mission.EnvArtificialGenerated and #mission.EnvArtificialGenerated > 0 then
        for _, location in ipairs(mission.EnvArtificialGenerated) do
            if point == location then
                return true
            end
        end
    end
    return false
end

-- 判断是否存在环境被动锁定方格
function this:HasEnvArtificialGenerated()
    local mission = GetCurrentMission()
    return mission and mission.EnvArtificialGenerated and #mission.EnvArtificialGenerated > 0
end

-- 判断方格是否为有效的环境目标
function this:IsValidEnvTarget(space, repeated)
    if not space or not Board:IsValid(space) then
        return false
    end
    -- 已锁定的方格无效
    if repeated and self:IsRepeatedTile(space, repeated) then
        return false
    end

    local tile = Board:GetTerrain(space)
    local pawn = Board:GetPawn(space)
    local pawnTeam = (pawn and pawn:GetTeam()) or "NOT PAWN"
    local mission = GetCurrentMission()
    if mission then
        if not mission.Env_MountainValid and tile == TERRAIN_MOUNTAIN then
            return false
        elseif not mission.Env_FlyValid and (tile == TERRAIN_WATER or tile == TERRAIN_HOLE) then
            return false -- TERRAIN_WATER 包括岩浆在内的所有液面
        end
    end
    return
        Board:IsValid(space) and not Board:IsPod(space) and not Board:IsBuilding(space) and pawnTeam ~= TEAM_PLAYER and
            pawnTeam ~= TEAM_NONE and not Board:IsSmoke(space) and not Board:IsFire(space) and
            not Board:IsSpawning(space) and not Board:IsFrozen(space) and not Board:IsDangerous(space) and
            not Board:IsDangerousItem(space)
end

-- 标记环境免疫
local allySpaceIcon = "combat/tile_icon/tile_artificial.png"
local allySpaceColors = {GL_Color(50, 200, 50, 0.75), GL_Color(20, 200, 20, 0.75)}
function this:MarkAllySpace(location, active, env)
    local icon = (env and (env:GetEnvImageMark() or env.CombatIcon)) or allySpaceIcon
    Board:MarkSpaceImage(location, icon, active and allySpaceColors[2] or allySpaceColors[1])
    Board:MarkSpaceDesc(location, "passive0", false)
end

-- 在每个象限非边缘处取方格组成 4 个集合，按一、二、三、四象限顺序返回
function this:GetEnvQuarters(repeated)
    local quarters = {}
    local start = Point(1, 1)
    for count = 1, 4 do
        local choices = {}
        for x = start.x, (start.x + 2) do
            for y = start.y, (start.y + 2) do
                if self:IsValidEnvTarget(Point(x, y), repeated) then
                    choices[#choices + 1] = Point(x, y)
                end
            end
        end

        quarters[#quarters + 1] = choices
        if count == 1 then
            start = Point(1, 4)
        elseif count == 2 then
            start = Point(4, 4)
        elseif count == 3 then
            start = Point(4, 1)
        end
    end
    return quarters
end

-- 均匀地从四个象限中取 n 个点
function this:GetUniformDistributionPoints(n, quarters, ret)
    ret = ret or {}
    local qa = {}
    local qb = {}
    local qc = nil
    local nCnt = 0
    while nCnt < n and (#quarters[1] > 0 or #quarters[2] > 0 or #quarters[3] > 0 or #quarters[4] > 0) do
        if #qa == 0 then
            qa = {{1, 3}, {2, 4}} -- 优先从对角线两侧的象限中选择
        end
        if #qb == 0 then
            qb = random_removal(qa)
        end
        qc = table.remove(qb, #qb) -- 优先取战场下方两个象限
        if #quarters[qc] > 0 then
            ret[#ret + 1] = random_removal(quarters[qc])
            nCnt = nCnt + 1
        end
    end
    return ret
end

-- 将点均匀地插入四个象限中
function this:InsertUniformDistributionPoints(points, quarters)
    quarters = quarters or {}
    local qa = {}
    local qb = {}
    local qc = nil
    while #points > 0 do
        if #qa == 0 then
            qa = {{1, 3}, {2, 4}}
        end
        if #qb == 0 then
            qb = random_removal(qa)
        end
        qc = table.remove(qb, #qb)
        if not quarters[qc] then
            quarters[qc] = {}
        end
        local quarter = quarters[qc]
        quarter[#quarter + 1] = random_removal(points)
    end
    return quarters
end

-- 获取环境被动升级区域数值
function this:GetEnvArtificialUpgradeAreaValue()
    -- local sector = GetSector() or 0
    -- if sector < 0 then
    --     sector = 0
    -- elseif sector > 4 then
    --     sector = 4
    -- end
    -- local values = {0, 1, 1, 1}
    -- return values[sector]
    return 2
end

-- 获取环境被动升级伤害数值
function this:GetEnvArtificialUpgradeDamageValue()
    -- local sector = GetSector() or 0
    -- if sector < 0 then
    --     sector = 0
    -- elseif sector > 4 then
    --     sector = 4
    -- end
    -- local values = {0, 0, 1, 1}
    -- return values[sector]
    return 1
end

-- 获取环境被动伤害
function this:GetEnvArtificialDamage(env)
    env = env or EnvArtificial
    local damage = env.BaseDamage
    if IsPassiveSkill("Env_Weapon_4_B") or IsPassiveSkill("Env_Weapon_4_AB") then
        damage = damage + self:GetEnvArtificialUpgradeDamageValue()
    end
    -- if pawn and _G[pawn:GetType()].Health > 4 then
    --     damage = damage + 1
    -- end
    return damage
end

-- 判断是否为 EnvImmune 保护对象
function this:IsEnvImmuneProtected(point, attackFrozen)
    attackFrozen = attackFrozen or false
    if point then
        if attackFrozen and Board:IsFrozen(point) then
            return false
        end
        return Board:GetPawnTeam(point) == TEAM_PLAYER or Board:IsBuilding(point)
    end
    return false
end

-- 判断是否为空地
function this:IsEmptyTile(point)
    return Board:IsValid(point) and not Board:IsBlocked(point, PATH_PROJECTILE)
end

-- 判断是否可移动
function this:IsMovable(point)
    return Board:IsPawnSpace(point) and not Board:GetPawn(point):IsGuarding()
end

-- 判断是否可传导（就目前来看与 IsEmptyTile() 互逆）
function this:IsConductive(point)
    return Board:IsPawnSpace(point) or Board:IsBuilding(point) or Board:GetTerrain(point) == TERRAIN_MOUNTAIN
end

-- 判断方格离中心的距离 [0, 6]
function this:GetDistanceToCenter(point)
    local dist = point:Manhattan(Point(3, 3)) + point:Manhattan(Point(4, 4))
    dist = (dist - 2) / 2 -- 必然是整数（到两点距离和必然是 d1 + d2 = d1 + d1 + 2 为偶数）
    return dist
end

-- 判断方格离环境被动锁定的距离
function this:GetDistanceToEnvArtificialGenerated(point)
    local dist = 15
    local mission = GetCurrentMission()
    if mission and mission.EnvArtificialGenerated and #mission.EnvArtificialGenerated > 0 then
        for _, location in ipairs(mission.EnvArtificialGenerated) do
            local current = self:GetCustomDistance(point, location)
            if current < dist then
                dist = current
            end
        end
    end
    return dist
end

-- 判断是否为被摧毁的山岭
function this:IsDamagedMountain(point)
    if point then
        if Board:GetTerrain(point) == TERRAIN_MOUNTAIN then
            return env_modApiExt.board:getTileHealth(point) == 1
        end
    end
    return false
end

-- 自定义距离
function this:GetCustomDistance(p1, p2)
    local dx = math.abs(p1.x - p2.x)
    local dy = math.abs(p1.y - p2.y)
    local d = 10000
    if dx == 0 then
        d = dy
    elseif dy == 0 then
        d = dx
    elseif dx == 1 and dy == 1 then
        d = 3
    end
    return d
end

-- 无视抵抗彻底毁坏建筑
function this:DestroyBuilding(location)
    if Board:IsBuilding(location) then
        Board:AddEffect(SpaceDamage(location, DAMAGE_DEATH))
        local fx = SkillEffect()
        fx:AddScript(string.format("ENV_GLOBAL.tool:DestroyBuilding(%s)", location:GetString()))
        Board:AddEffect(fx)
    end
end
function this:GetDestroyBuildingEffect(location, fx, delay)
    fx = fx or SkillEffect()
    if Board:IsBuilding(location) then
        fx:AddScript(string.format("ENV_GLOBAL.tool:DestroyBuilding(%s)", location:GetString()))
        fx:AddDelay(delay or 0.6)
    end
    return fx
end

-- 获取过载伤害
function this:OverloadDamage(dmg, point, pawnPoint, forceAcid)
    forceAcid = forceAcid or false
    pawnPoint = pawnPoint or point
    if not forceAcid then
        local pawn = Board:GetPawn(pawnPoint)
        if pawn and pawn:IsArmor() and not pawn:IsAcid() then
            dmg = dmg + 1
        end
    end
    local damage = SpaceDamage(point, dmg)
    damage.iFire = EFFECT_CREATE
    damage.sAnimation = "EnvExplo"
    damage.sSound = "/impact/generic/explosion"
    return damage
end

-- 移除机甲上的负面状态
function this:RemoveDebuffDamage(point, iFire, iAcid)
    iFire = iFire or EFFECT_REMOVE
    iAcid = iAcid or EFFECT_REMOVE
    local damage = SpaceDamage(point, 0)
    damage.iFire = iFire
    damage.iAcid = iAcid
    return damage
end

-- 判断岛屿地面是否反光
function this:IsGroundReflective(space)
    if space and Board:GetTerrain(space) == TERRAIN_ICE then
        return true
    end
    return Game and Game:GetCorp() and Game:GetCorp().bark_name == "Corp_Snow_Bark"
end

-- 判断是否为冰雷
function this:IsFreezeMine(space)
    if space then
        local entry = env_modApiExt.board:getTileTable(space)
        return entry and entry.item == "Freeze_Mine"
    end
    return false
end

function this:Load()
    -- nothing to do
end

ENV_GLOBAL.tool = this
return this
