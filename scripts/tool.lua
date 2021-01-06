local Tool = {}

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
Tool.Map = Map

-- 判断是否为使用提示
function Tool:IsTipImage()
    return Board:GetSize() == Point(6, 6)
end

-- 判断机甲是否有装备
-- 自定义中有同名机甲时，判断会出错。
-- 且由于 GameData 数据具有延后性，更换装备到其他机甲上后，不能立即获得正确的最新位置，正常情况下还是可能出错。
function Tool:HasWeapon(pawn, weapon)
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
function Tool:GetMechNo(name)
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
function Tool:GetWeaponNo(name)
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
function Tool:GetWeapon(name)
    if GameData and GameData.current and GameData.current.weapons then
        for i, weapon in ipairs(GameData.current.weapons) do
            if modApi:stringStartsWith(weapon, name) then
                if #weapon - #name <= 3 then
                    if weapon == name then
                        return "Z" -- 未升级
                    elseif modApi:stringEndsWith(weapon, "_A") then
                        return "A" -- 升级 1
                    elseif modApi:stringEndsWith(weapon, "_B") then
                        return "B" -- 升级 2
                    elseif modApi:stringEndsWith(weapon, "_AB") then
                        return "AB" -- 升级 1+2
                    end
                end
            end
        end
    end
    return nil
end

-- 判断方格是否在集合内
function Tool:IsRepeatedTile(space, repeated)
    for i, location in ipairs(repeated) do
        if space == location then
            return true
        end
    end
    return false
end

-- 找出装备环境被动的机甲，添加环境锁定特效
function Tool:EnvPassiveGenerate(planned, overlay)
    overlay = overlay or false
    local mission = GetCurrentMission()
    mission.EnvPassive_Planned = planned -- 赶紧把状态存进 mission 里，防止保存游戏时没保存上
    mission.EnvPassive_Planned_Overlay = overlay
    local pawns = extract_table(Board:GetPawns(TEAM_MECH))
    local bounceAmount = 10
    for i, id in ipairs(pawns) do
        local pawn = Board:GetPawn(id)
        if self:HasWeapon(pawn, "Env_Weapon_4") then
            local point = pawn:GetSpace()
            if point and pawn:GetHealth() > 0 and not pawn:IsFrozen() and
                (pawn:IsFlying() or Board:GetTerrain(point) ~= TERRAIN_WATER) then
                local effect = SkillEffect()
                local damage = SpaceDamage(point, 0)
                damage.sSound = "/weapons/gravwell"
                effect:AddDamage(damage)
                effect:AddBounce(point, bounceAmount)
                for j, space in ipairs(planned) do
                    -- Board:BlockSpawn(space, BLOCKED_TEMP) -- 只在关卡开始时调用才生效，原版游戏的各种处理同样无效
                    Board:SetDangerous(space)
                    damage = SpaceDamage(space, 0)
                    local delay = j < #planned and NO_DELAY or FULL_DELAY
                    damage.sAnimation = "EnvExploRepulse"
                    damage.sSound = "/impact/generic/explosion"
                    effect:AddArtillery(point, damage, "effects/env_shot_U.png", delay)
                end
                local str = "local mission = GetCurrentMission(); local env = mission.LiveEnvironment"
                if overlay then
                    str = str .. ".OverlayEnv"
                end
                effect:AddScript(str .. [[
                    for i, epp in ipairs(mission.EnvPassive_Planned) do
                        env.Locations[#env.Locations + 1] = epp
                        mission.EnvPassiveGenerated[#mission.EnvPassiveGenerated + 1] = epp
                    end
                    Game:TriggerSound("/props/square_lightup")
                    mission.EnvPassive_Planned = nil
                    mission.EnvPassive_Planned_Overlay = nil
                ]])
                Board:AddEffect(effect)
                break -- 多个环境被动会被游戏禁止，不用考虑这种问题
            else
                Game:AddTip("EnvPassiveDisabled", point)
            end
        end
    end
end

-- 判断方格是否为被环境被动锁定
function Tool:IsEnvPassiveGenerated(point)
    local mission = GetCurrentMission()
    if mission and mission.EnvPassiveGenerated and #mission.EnvPassiveGenerated > 0 then
        for i, location in ipairs(mission.EnvPassiveGenerated) do
            if point == location then
                return true
            end
        end
    end
    return false
end

-- 判断方格是否为有效的环境目标
function Tool:IsValidEnvTarget(space, repeated)
    -- 已锁定的方格无效
    if repeated and self:IsRepeatedTile(space, repeated) then
        return false
    end

    local tile = Board:GetTerrain(space)
    local pawn = Board:GetPawn(space)
    local pawnTeam = (pawn and pawn:GetTeam()) or "NOT PAWN"
    return -- TERRAIN_WATER 包括岩浆在内的所有液面
    Board:IsValid(space) and not Board:IsPod(space) and not Board:IsBuilding(space) and pawnTeam ~= TEAM_PLAYER and
        pawnTeam ~= TEAM_NONE and tile ~= TERRAIN_MOUNTAIN and tile ~= TERRAIN_WATER and tile ~= TERRAIN_HOLE and
        not Board:IsSmoke(space) and not Board:IsFire(space) and not Board:IsSpawning(space) and
        not Board:IsFrozen(space) and not Board:IsDangerous(space) and not Board:IsDangerousItem(space)
end

-- 在每个象限非边缘处取方格组成 4 个集合，按一、二、三、四象限顺序返回
function Tool:GetEnvQuarters(repeated)
    local quarters = {}
    local start = Point(1, 1)
    for count = 1, 4 do
        local choices = {}
        for i = start.x, (start.x + 2) do
            for j = start.y, (start.y + 2) do
                if self:IsValidEnvTarget(Point(i, j), repeated) then
                    choices[#choices + 1] = Point(i, j)
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
function Tool:GetUniformDistributionPoints(n, quarters, ret)
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

-- 获取环境被动升级区域数值
function Tool:GetEnvPassiveUpgradeAreaValue()
    local values = {0, 0, 1, 1}
    return values[GetSector()]
end

-- 获取环境被动升级伤害数值
function Tool:GetEnvPassiveUpgradeDamageValue()
    local values = {0, 1, 2, 2}
    return values[GetSector()]
end

-- 获取环境被动伤害
function Tool:GetEnvPassiveDamage()
    local damage = Env_Weapon_4.BaseDamage
    if IsPassiveSkill("Env_Weapon_4_B") or IsPassiveSkill("Env_Weapon_4_AB") then
        damage = damage + self:GetEnvPassiveUpgradeDamageValue()
    end
    return damage
end

-- 判断是否为灵虫
function Tool:IsPsion(pawn)
    if pawn then
        local type = pawn:GetType()
        return
            type == "Jelly_Health1" or type == "Jelly_Armor1" or type == "Jelly_Regen1" or type == "Jelly_Explode1" or
                type == "Jelly_Lava1" or type == "Jelly_Boss"
    end
    return false
end

-- 判断是否为空地
function Tool:IsEmptyTile(point)
    return Board:IsValid(point) and not Board:IsBlocked(point, PATH_PROJECTILE)
end

-- 判断是否可移动
function Tool:IsMovable(point)
    return Board:IsPawnSpace(point) and not Board:GetPawn(point):IsGuarding()
end

-- 判断是否可传导（就目前来看与 IsEmptyTile() 互逆）
function Tool:IsConductive(point)
    return Board:IsPawnSpace(point) or Board:IsBuilding(point) or Board:GetTerrain(point) == TERRAIN_MOUNTAIN
end

return Tool
