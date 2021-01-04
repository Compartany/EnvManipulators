local mod = mod_loader.mods[modApi.currentMod]
local tool = mod.tool
local path = mod.resourcePath
local iconPath = path .. "img/weapons/"
local pawnMap = tool.Map:new()

local files = {"env_weapon_1.png", "env_weapon_2.png", "env_weapon_3.png", "env_weapon_4.png"}
for _, file in ipairs(files) do
    modApi:appendAsset("img/weapons/" .. file, iconPath .. file)
end

------------------
-- Env_Weapon_1 --
------------------
Env_Weapon_1 = Skill:new{
    Name = Weapon_Texts.Env_Weapon_1_Name,
    Description = Weapon_Texts.Env_Weapon_1_Description,
    Class = "Prime",
    Icon = "weapons/env_weapon_1.png",
    Range = 8,
    Damage = 0,
    Push = false,
    Pull = false,
    Overload = false,
    PowerCost = 2,
    Upgrades = 2,
    UpgradeCost = {1, 3},
    TipImage = {
        Unit = Point(2, 2),
        Enemy = Point(2, 1),
        Enemy2 = Point(2, 3),
        Enemy3 = Point(3, 2),
        Target = Point(1, 1)
    }
}

Env_Weapon_1_A = Env_Weapon_1:new{
    UpgradeDescription = Weapon_Texts.Env_Weapon_1_A_UpgradeDescription,
    Push = true,
    Pull = true,
    TipImage = {
        Unit = Point(2, 2),
        Enemy = Point(2, 0),
        Enemy2 = Point(3, 2),
        Enemy3 = Point(2, 3),
        Target = Point(2, 1)
    }
}

Env_Weapon_1_B = Env_Weapon_1:new{
    UpgradeDescription = Weapon_Texts.Env_Weapon_1_B_UpgradeDescription,
    Overload = true,
    TipImage = {
        Unit = Point(2, 4),
        Enemy = Point(2, 3),
        Enemy2 = Point(3, 2),
        Enemy3 = Point(2, 1),
        Target = Point(3, 3)
    }
}

Env_Weapon_1_AB = Env_Weapon_1:new{
    Push = true,
    Pull = true,
    Overload = true,
    TipImage = {
        Unit = Point(2, 4),
        Enemy = Point(2, 0),
        Enemy2 = Point(3, 2),
        Enemy3 = Point(2, 3),
        Target = Point(3, 3)
    }
}

function Env_Weapon_1:GetTargetArea(point)
    local ret = PointList()
    for dir = DIR_START, DIR_END do
        local curr = point + DIR_VECTORS[dir]
        if Board:IsPawnSpace(curr) then
            local dirLeft = (dir + 3) % 4
            local dirRight = (dir + 1) % 4
            local dirs = {dirLeft, dirRight}
            if self.Push then
                dirs[#dirs + 1] = dir
            end
            for i, v in ipairs(dirs) do
                local target = curr + DIR_VECTORS[v]
                if Board:IsValid(target) then
                    ret:push_back(target)
                end
            end
        end
        if self.Pull then
            curr = point + DIR_VECTORS[dir] * 2
            if tool:IsMovable(curr) then
                local target = curr - DIR_VECTORS[dir]
                if tool:IsEmptyTile(target) then
                    local valid = true
                    local terrain = Board:GetTerrain(target)
                    if not Pawn:IsFlying() and (terrain == TERRAIN_WATER or terrain == TERRAIN_HOLE) then
                        -- 不会飞且移动到液面或深坑上
                        valid = false
                    elseif Pawn:IsGrappled() then
                        -- 被缠绕
                        valid = false
                    elseif not Pawn:IsIgnoreSmoke() and Board:IsSmoke(target) then
                        -- 无烟雾免疫且移动到烟雾中
                        valid = false
                    elseif Board:IsDangerousItem(target) then
                        -- 地雷等危险物体
                        valid = false
                    end
                    if valid then
                        -- 判断移动力是否足够
                        if not tool:IsTipImage() then
                            local mission = GetCurrentMission()
                            local kMml = "MechMovementLeft_" .. Pawn:GetId()
                            if not Pawn:GetPawnTable().bMoved then
                                -- 行动前再次更新必要的移动力信息
                                mission[kMml] = Pawn:GetMoveSpeed()
                            end
                            valid = mission[kMml] > 0 or Pawn:IsEnvJumpMove()
                        end

                        if valid then
                            ret:push_back(target)
                        end
                    end
                end
            end
        end
    end
    return ret
end

function Env_Weapon_1:GetSkillEffect(p1, p2)
    return tool:IsTipImage() and self:GetSkillEffect_TipImage() or self:GetSkillEffect_Inner(p1, p2)
end

-- 不能直接在 GetSkillEffect() 上追加参数，因为其他 MOD 引进的 modApiExt 也可能在上面追加参数导致冲突
function Env_Weapon_1:GetSkillEffect_Inner(p1, p2, tipImageCall, skillEffect)
    tipImageCall = tipImageCall or false
    local iFire = ((tipImageCall and self.Overload) or Pawn:IsFire()) and EFFECT_CREATE or EFFECT_NONE
    local iAcid = Pawn:IsAcid() and EFFECT_CREATE or EFFECT_NONE
    local bHide = tipImageCall and self.Overload

    local ret = skillEffect or SkillEffect()
    local dist = p1:Manhattan(p2)
    local damage = nil

    if dist == 1 and self.Pull then
        local dir = GetDirection(p2 - p1)
        local dir2 = GetDirection(p1 - p2)
        local obj = p2 + DIR_VECTORS[dir]
        if iFire == EFFECT_NONE then
            iFire = (Board:IsFire(p2) and not Pawn:IsIgnoreFire()) and EFFECT_CREATE or EFFECT_NONE
        end
        if iAcid == EFFECT_NONE then
            iAcid = Board:IsAcid(p2) and EFFECT_CREATE or EFFECT_NONE
        end
        ret:AddMove(Board:GetSimplePath(p1, p2), FULL_DELAY)
        if not tipImageCall then
            local kMml = "MechMovementLeft_" .. Pawn:GetId()
            local mml = GetCurrentMission()[kMml]
            -- 考虑到西里卡机师等多次攻击的情况，还是更新一下剩余移动力信息
            ret:AddScript(string.format("GetCurrentMission().%s = %d - 1", kMml, mml))
            if Pawn:IsEnvJumpMove() then
                if not mml or mml <= 1 then -- 移动力耗尽
                    damage = SpaceDamage(p2, 1)
                    if not Pawn:IsFire() then
                        damage.iFire = EFFECT_CREATE
                    end
                    damage.sAnimation = "EnvExploRepulse"
                    damage.sSound = "/impact/generic/explosion"
                    ret:AddDamage(damage)
                end
            end
        end
        ret:AddDelay(0.3)
        ret:AddMove(Board:GetSimplePath(p2, p1), FULL_DELAY)
        damage = SpaceDamage(obj, 0, dir2)
        damage.iFire = iFire
        damage.iAcid = iAcid
        damage.bHide = bHide
        ret:AddDamage(damage)
        if tipImageCall and self.Overload then
            ret:AddDelay(0.8)
        end
    else
        local objs = {}
        for dir = DIR_START, DIR_END do
            local curr = p1 + DIR_VECTORS[dir]
            if Board:IsPawnSpace(curr) then
                objs[#objs + 1] = curr
            end
        end
        if self.Push then
            for i, obj in ipairs(objs) do
                local dir = GetDirection(obj - p1)
                local dir2 = GetDirection(p2 - obj)
                if dir2 == dir then
                    damage = SpaceDamage(obj, 0, dir2)
                    damage.iFire = iFire
                    damage.iAcid = iAcid
                    damage.bHide = bHide
                    damage.sAnimation = "explopunch1_" .. dir2
                    damage.sSound = "/weapons/titan_fist"
                    ret:AddMelee(p1, damage)
                    if tipImageCall and self.Overload then
                        ret:AddDelay(0.5)
                    end
                    return ret -- 后面不可能会有其他处理
                end
            end
        end

        -- 优先处理向左位移，再处理向右位移，而不是按物体顺序来判定
        local pushDelay = false
        for i, obj in ipairs(objs) do
            local dir = GetDirection(obj - p1)
            local dir2 = GetDirection(p2 - obj)
            local dirLeft = (dir + 3) % 4
            if dir2 == dirLeft then
                damage = SpaceDamage(obj, 0, dir2)
                damage.iFire = iFire
                damage.iAcid = iAcid
                damage.bHide = bHide
                damage.sAnimation = "explopunch1_" .. dir2
                damage.sSound = "/weapons/titan_fist"
                ret:AddMelee(p1, damage)

                -- 判断是否应该添加延时以避免无法同时位移两个地面敌人至水中
                -- 非常奇怪的是，像破损的山、一血建筑、一血单位等都不会在这种情况出现问题，只有掉进水的动画太长才导致这一问题
                local pawn = Board:GetPawn(obj)
                if Board:IsTerrain(p2, TERRAIN_WATER) and not pawn:IsGuarding() then
                    if (not pawn:IsFlying() or pawn:IsFrozen()) and not _G[pawn:GetType()].Massive then
                        pushDelay = true
                    end
                end
                break
            end
        end
        for i, obj in ipairs(objs) do
            local dir = GetDirection(obj - p1)
            local dir2 = GetDirection(p2 - obj)
            local dirRight = (dir + 1) % 4
            if dir2 == dirRight then
                if pushDelay and not Board:GetPawn(obj):IsGuarding() then
                    ret:AddDelay(0.52) -- 0.5 就够，给多一点保险一些
                end
                damage = SpaceDamage(obj, 0, dir2)
                damage.iFire = iFire
                damage.iAcid = iAcid
                damage.bHide = bHide
                damage.sAnimation = "explopunch1_" .. dir2
                damage.sSound = "/weapons/titan_fist"
                ret:AddMelee(p1, damage)
                break
            end
        end
    end
    return ret
end

-- 注意：TipImage 必须要设置 Unit、Enemy、Target，且它们必须得满足正常攻击发起的逻辑，否则 TipImage 无效
function Env_Weapon_1:GetSkillEffect_TipImage()
    local ret = nil
    local s = "Z"
    if self.Push and not self.Overload then
        s = "A"
        if not self.TI_A then
            self.TI_A = 0
        end
    elseif not self.Push and self.Overload then
        s = "B"
        if not self.TI_B then
            self.TI_B = 0
        end
    elseif self.Push and self.Overload then
        s = "AB"
        if not self.TI_AB then
            self.TI_AB = 0
        end
    else
        if not self.TI_Z then
            self.TI_Z = 0
        end
    end

    if s == "A" then
        if self.TI_A == 0 then
            ret = self:GetSkillEffect_Inner(Point(2, 2), Point(4, 2), true)
        elseif self.TI_A == 1 then
            ret = self:GetSkillEffect_Inner(Point(2, 2), Point(2, 1), true)
        else
            ret = self:GetSkillEffect_Inner(Point(2, 2), Point(3, 3), true)
        end
        self.TI_A = (self.TI_A + 1) % 3
    elseif s == "B" or s == "AB" then
        local effect = SkillEffect()
        local p1 = Point(2, 4)
        local p2 = Point(2, 2)
        ENV_GLOBAL.EnvIgnoreWeb_Pawn_TipImage = Board:GetPawn(p1)
        effect:AddGrapple(Point(2, 3), p1, "hold")
        effect:AddScript([[ENV_GLOBAL.EnvIgnoreWeb_Pawn_TipImage:SetSpace(Point(-1, -1))]])
        effect:AddDelay(0.01) -- 必须要有延时才行
        effect:AddScript([[ENV_GLOBAL.EnvIgnoreWeb_Pawn_TipImage:SetSpace(Point(2, 4))]])
        effect:AddDelay(0.25)
        local damage = SpaceDamage(p1, 1)
        damage.iFire = EFFECT_CREATE
        damage.bHide = true
        damage.sAnimation = "EnvExploRepulse"
        damage.sSound = "/impact/generic/explosion"
        effect:AddDamage(damage)
        effect:AddDelay(1.3)
        local move = PointList()
        effect:AddSound("/weapons/leap")
        move:push_back(p1)
        move:push_back(p2)
        effect:AddBurst(p1, "Emitter_Burst_$tile", DIR_NONE)
        effect:AddLeap(move, FULL_DELAY)
        effect:AddBurst(p2, "Emitter_Burst_$tile", DIR_NONE)
        for i = DIR_START, DIR_END do
            local damage = SpaceDamage(p2 + DIR_VECTORS[i], 0)
            damage.sAnimation = PUSH_ANIMS[i]
            effect:AddDamage(damage)
        end
        damage = SpaceDamage(p2, 1)
        damage.bHide = true
        damage.sAnimation = "EnvExploRepulse"
        damage.sSound = "/impact/generic/explosion"
        effect:AddDamage(damage)
        effect:AddSound("/impact/generic/mech")
        effect:AddBounce(p2, 3)
        effect:AddDelay(0.5)

        if s == "B" then
            if self.TI_B == 0 then
                ret = self:GetSkillEffect_Inner(Point(2, 2), Point(1, 1), true, effect)
            else
                ret = self:GetSkillEffect_Inner(Point(2, 2), Point(3, 3), true, effect)
                ret:AddDelay(0.5)
            end
            self.TI_B = (self.TI_B + 1) % 2
        else
            if self.TI_AB == 0 then
                ret = self:GetSkillEffect_Inner(Point(2, 2), Point(4, 2), true, effect)
            elseif self.TI_AB == 1 then
                ret = self:GetSkillEffect_Inner(Point(2, 2), Point(2, 1), true, effect)
            else
                ret = self:GetSkillEffect_Inner(Point(2, 2), Point(3, 3), true, effect)
                ret:AddDelay(0.5)
            end
            self.TI_AB = (self.TI_AB + 1) % 3
        end
    else
        if self.TI_Z == 0 then
            ret = self:GetSkillEffect_Inner(Point(2, 2), Point(1, 1), true)
        else
            ret = self:GetSkillEffect_Inner(Point(2, 2), Point(3, 3), true)
        end
        self.TI_Z = (self.TI_Z + 1) % 2
    end
    return ret
end

-- 这种判断方式具有延时性，Hook 进入时无法判断是否获取到最新数据，故无法靠 TMS Hook 来解决
-- 当然可以在 UpdateSaveData Hook 中处理，但 UpdateSaveData 非常频繁，属实没有必要，每次都算一遍反而更优
local function IsEnvWeapon1_B_TMS(pawn)
    local wp1 = tool:GetWeapon("Env_Weapon_1")
    return (wp1 == "B" or wp1 == "AB") and tool:HasWeapon(pawn, "Env_Weapon_1")
end

------------
-- 反缠绕 --
------------
function BoardPawn:IsEnvIgnoreWeb()
    if IsTestMechScenario() then
        return IsEnvWeapon1_B_TMS(self)
    else
        return not self:IsIgnoreWeb() and pawnMap:Get(self:GetId(), "IgnoreWeb")
    end
end
local _SkillEffect_AddGrapple = SkillEffect.AddGrapple
function SkillEffect:AddGrapple(source, target, ...)
    local ret = _SkillEffect_AddGrapple(self, source, target, ...)
    local pawn = Board:GetPawn(target)

    if pawn and pawn:IsEnvIgnoreWeb() then
        if pawn:GetHealth() > 0 and not pawn:IsFrozen() and
            (pawn:IsFlying() or Board:GetTerrain(target) ~= TERRAIN_WATER) then
            ENV_GLOBAL.EnvIgnoreWeb_Pawn = pawn
            self:AddScript([[ENV_GLOBAL.EnvIgnoreWeb_Pawn:SetSpace(Point(-1, -1))]])
            self:AddDelay(0.01) -- 必须要有延时才行
            self:AddScript([[ENV_GLOBAL.EnvIgnoreWeb_Pawn:SetSpace(]] .. target:GetString() .. [[)]])
            self:AddDelay(0.25)
            local damage = SpaceDamage(target, 1)
            if not pawn:IsFire() then
                damage.iFire = EFFECT_CREATE
            end
            damage.sAnimation = "EnvExploRepulse"
            damage.sSound = "/impact/generic/explosion"
            self:AddDamage(damage)
        else
            self:AddScript([[Board:AddAlert(]] .. target:GetString() .. [[, Global_Texts.EnvOverloadDisabled)]])
        end
    end
    return ret
end

--------------
-- 跳跃移动 --
--------------
function BoardPawn:IsEnvJumpMove()
    if IsTestMechScenario() then
        return IsEnvWeapon1_B_TMS(self)
    else
        return not self:IsJumper() and pawnMap:Get(self:GetId(), "JumpMove")
    end
end

local _Move_GetTargetArea = Move.GetTargetArea
function Move:GetTargetArea(point)
    if Pawn:IsEnvJumpMove() and (Pawn:IsFlying() or Board:GetTerrain(point) ~= TERRAIN_WATER) then
        return Board:GetReachable(point, 14, PATH_FLYER)
    end
    return _Move_GetTargetArea(self, point)
end
local _Move_GetSkillEffect = Move.GetSkillEffect
function Move:GetSkillEffect(p1, p2)
    if tool:HasWeapon(Pawn, "Env_Weapon_1") then
        local dist = p1:Manhattan(p2)
        GetCurrentMission()["MechMovementLeft_" .. Pawn:GetId()] = Pawn:GetMoveSpeed() - dist

        if Pawn:IsEnvJumpMove() and (Pawn:IsFlying() or Board:GetTerrain(p1) ~= TERRAIN_WATER) then
            local needJump = true
            local groundReachable = Board:GetReachable(p1, Pawn:GetMoveSpeed(), Pawn:GetPathProf())
            for i, point in ipairs(extract_table(groundReachable)) do
                if p2 == point then
                    needJump = false
                    break
                end
            end
            if needJump then -- 会飞的时候也进不来
                -- 默认的跳跃处理无特效
                local ret = SkillEffect()
                local move = PointList()
                ret:AddSound("/weapons/leap")
                move:push_back(p1)
                move:push_back(p2)
                ret:AddBurst(p1, "Emitter_Burst_$tile", DIR_NONE)
                ret:AddLeap(move, FULL_DELAY)
                ret:AddBurst(p2, "Emitter_Burst_$tile", DIR_NONE)

                for i = DIR_START, DIR_END do
                    local damage = SpaceDamage(p2 + DIR_VECTORS[i], 0)
                    damage.sAnimation = PUSH_ANIMS[i]
                    ret:AddDamage(damage)
                end
                local damage = SpaceDamage(p2, 1)
                if not Pawn:IsFire() then
                    damage.iFire = EFFECT_CREATE
                end
                damage.sAnimation = "EnvExploRepulse"
                damage.sSound = "/impact/generic/explosion"
                ret:AddDamage(damage)
                ret:AddSound("/impact/generic/mech")
                ret:AddBounce(p2, 3)
                return ret
            else
                local ret = SkillEffect()
                ret:AddMove(Board:GetPath(p1, p2, Pawn:GetPathProf()), FULL_DELAY)
                if dist == Pawn:GetMoveSpeed() then
                    local damage = SpaceDamage(p2, 1)
                    if not Pawn:IsFire() then
                        damage.iFire = EFFECT_CREATE
                    end
                    damage.sAnimation = "EnvExploRepulse"
                    damage.sSound = "/impact/generic/explosion"
                    ret:AddDamage(damage)
                end
                return ret
            end
        end
    end
    return _Move_GetSkillEffect(self, p1, p2)
end

------------------
-- Env_Weapon_2 --
------------------
Env_Weapon_2 = LineArtillery:new{
    Name = Weapon_Texts.Env_Weapon_2_Name,
    Description = Weapon_Texts.Env_Weapon_2_Description,
    Class = "Ranged",
    Icon = "weapons/env_weapon_2.png",
    InwardPush = false,
    ChainPush = false,
    PowerCost = 1,
    Damage = 0,
    Upgrades = 2,
    UpgradeCost = {1, 2},
    LaunchSound = "/weapons/gravwell",
    ImpactSound = "/impact/generic/explosion",
    TipImage = {
        Unit = Point(2, 3),
        Enemy = Point(2, 1),
        Friendly = Point(3, 1),
        Target = Point(2, 1)
    }
}

Env_Weapon_2_A = Env_Weapon_2:new{
    UpgradeDescription = Weapon_Texts.Env_Weapon_2_A_UpgradeDescription,
    ChainPush = true,
    TipImage = {
        Unit = Point(2, 3),
        Enemy = Point(2, 1),
        Enemy2 = Point(1, 0),
        Friendly = Point(3, 1),
        Target = Point(2, 1)
    }
}

Env_Weapon_2_B = Env_Weapon_2:new{
    UpgradeDescription = Weapon_Texts.Env_Weapon_2_B_UpgradeDescription,
    InwardPush = true,
    TipImage = {
        Unit = Point(2, 4),
        Enemy = Point(2, 1),
        Enemy2 = Point(2, 2),
        Friendly = Point(3, 1),
        Target = Point(2, 1)
    }
}

Env_Weapon_2_AB = Env_Weapon_2:new{
    ChainPush = true,
    InwardPush = true,
    TipImage = {
        Unit = Point(2, 4),
        Enemy = Point(2, 1),
        Enemy2 = Point(2, 2),
        Enemy3 = Point(1, 0),
        Friendly = Point(3, 1),
        Target = Point(2, 1)
    }
}

function Env_Weapon_2:GetTargetArea(point)
    local ret = PointList()
    for dir = DIR_START, DIR_END do
        for i = 2, 8 do
            local curr = point + DIR_VECTORS[dir] * i
            if Board:IsValid(curr) then
                ret:push_back(curr)
            end
        end
    end
    return ret
end

function Env_Weapon_2:GetSkillEffect(p1, p2)
    local ret = SkillEffect()
    local direction = GetDirection(p2 - p1)

    local mission = GetCurrentMission()
    local envName = mission and mission.Environment or "Env_Null"
    envName = envName and envName or "Env_Null"

    ret:AddBounce(p1, 10)
    local damage = SpaceDamage(p2, self.Damage, direction)
    damage.sAnimation = "EnvExploRepulse"
    damage.sImageMark = "combat/icons/env_lock.png"
    ret:AddArtillery(damage, "effects/env_shot_U.png")

    if envName ~= "Env_Null" and not tool:IsTipImage() then -- TipImage 会引起 Script 执行
        local env = mission.LiveEnvironment
        local strEnv = "local env = GetCurrentMission().LiveEnvironment"
        if not mission.MasteredEnv and (not env.Locations or #env.Locations == 0 or mission.SpecialEnv) then
            strEnv = strEnv .. ".OverlayEnv"
        end
        ret:AddScript(strEnv .. "; env.Locations[#env.Locations + 1] = " .. p2:GetString())
    end

    local dirLeft = (direction + 3) % 4
    local dirRight = (direction + 1) % 4
    local pushDirs = {dirLeft, dirRight}
    if self.InwardPush then
        pushDirs[#pushDirs + 1] = (direction + 2) % 4
    end
    for i, dir in ipairs(pushDirs) do
        damage = SpaceDamage(p2 + DIR_VECTORS[dir], 0, dir)
        damage.sAnimation = PUSH_ANIMS[dir]
        ret:AddDamage(damage)
    end
    if self.ChainPush then
        local p3 = p2 + DIR_VECTORS[direction]
        if tool:IsMovable(p2) then
            if tool:IsEmptyTile(p3) then
                ret:AddDelay(0.35)
                for i, dir in ipairs({dirLeft, dirRight}) do
                    damage = SpaceDamage(p3 + DIR_VECTORS[dir], 0, dir)
                    damage.sAnimation = PUSH_ANIMS[dir]
                    ret:AddDamage(damage)
                end
            else
                ret:AddDelay(0.25)
                damage = SpaceDamage(p3, 0, direction)
                damage.sAnimation = PUSH_ANIMS[direction]
                ret:AddDamage(damage)
            end
        end
    end

    -- 如果是使用提示，则用假方格模仿环境锁定
    if tool:IsTipImage() then
        ret:AddScript([[Board:SetCustomTile(Point(2, 1), "tile_lock.png")]])
        ret:AddDelay(1.5)
        ret:AddScript([[Board:SetCustomTile(Point(2, 1), "ground_0.png")]])
    end

    return ret
end

------------------
-- Env_Weapon_3 --
------------------
-- 两项升级，一项 +1 范围（1 核心），一项 +2 范围（3 核心）。其实升级 1 很大程度上已经够用，但多花 2 核心将升级 1 换成升级 2 也确实有一定提升。一方面是限制后期强度，另一方面也是为了让玩家多一个抉择。
Env_Weapon_3 = Skill:new{
    Name = Weapon_Texts.Env_Weapon_3_Name,
    Description = Weapon_Texts.Env_Weapon_3_Description,
    Class = "Science",
    Icon = "weapons/env_weapon_3.png",
    Range = 3,
    Damage = 0,
    PowerCost = 1,
    Upgrades = 2,
    UpgradeCost = {1, 2},
    LaunchSound = "/weapons/enhanced_tractor",
    ImpactSound = "/impact/generic/tractor_beam",
    TipImage = {
        Unit = Point(2, 3),
        Enemy = Point(2, 1),
        Building = Point(2, 2),
        Target = Point(2, 0)
    }
}

Env_Weapon_3_A = Env_Weapon_3:new{
    UpgradeDescription = Weapon_Texts.Env_Weapon_3_A_UpgradeDescription,
    Range = 4,
    TipImage = {
        Unit = Point(2, 4),
        Enemy = Point(2, 1),
        Mountain = Point(2, 2),
        Target = Point(2, 0)
    }
}

Env_Weapon_3_B = Env_Weapon_3:new{
    UpgradeDescription = Weapon_Texts.Env_Weapon_3_B_UpgradeDescription,
    Range = 4,
    TipImage = {
        Unit = Point(2, 4),
        Enemy = Point(2, 1),
        Enemy2 = Point(2, 3),
        Target = Point(2, 0)
    }
}

Env_Weapon_3_AB = Env_Weapon_3:new{
    Range = 5,
    TipImage = {
        Unit = Point(2, 4),
        Enemy = Point(2, 1),
        Enemy2 = Point(2, 3),
        Mountain = Point(2, 2),
        Target = Point(2, 0)
    }
}

function Env_Weapon_3:GetTargetArea(point)
    local ret = PointList()
    for dir = DIR_START, DIR_END do
        local chainStart = false -- 为 true 表示之前已经找到传导物
        local chainMaintain = false -- 为 true 表示前一件传导物可动
        for i = 1, self.Range do
            local curr = point + DIR_VECTORS[dir] * i
            if chainStart then
                if tool:IsEmptyTile(curr) then
                    if chainMaintain then
                        ret:push_back(curr)
                    else
                        break
                    end
                else
                    chainMaintain = tool:IsMovable(curr)
                end
            elseif tool:IsConductive(curr) then
                chainStart = true
                chainMaintain = tool:IsMovable(curr)
            end
        end
    end
    return ret
end

function Env_Weapon_3:GetSkillEffect(p1, p2)
    local ret = SkillEffect()
    local direction = GetDirection(p2 - p1)
    local dist = p1:Manhattan(p2)
    local objs = {} -- 所有被传导的物体
    local dests = {} -- 被传导物体的最终位置
    for i = 1, dist - 1 do
        local curr = p1 + DIR_VECTORS[direction] * i
        if tool:IsConductive(curr) then
            objs[#objs + 1] = curr
        end
    end
    if #objs > 0 then
        if #objs == 1 then
            dests[1] = p2
        else
            for i = 2, #objs do
                dests[i - 1] = objs[i] - DIR_VECTORS[direction]
            end
            dests[#objs] = p2
        end

        ret:AddProjectile(SpaceDamage(objs[1], 0), "effects/env_shot", FULL_DELAY) -- 对应 U、R 两张图
        for i, obj in ipairs(objs) do
            ret:AddCharge(Board:GetSimplePath(obj, dests[i]), FULL_DELAY)
            if i ~= #objs then
                local damage = SpaceDamage(dests[i], self.Damage)
                damage.sAnimation = "EnvExploRepulse"
                damage.sSound = "/impact/generic/explosion"
                ret:AddDamage(damage)
                ret:AddBounce(dests[i], -2)
            end
        end
    end
    return ret
end

------------------
-- Env_Weapon_4 --
------------------
Env_Weapon_4 = PassiveSkill:new{
    Name = Weapon_Texts.Env_Weapon_4_Name,
    Description = Weapon_Texts.Env_Weapon_4_Description,
    Passive = "Env_Weapon_4",
    Icon = "weapons/env_weapon_4.png",
    PowerCost = 3,
    Upgrades = 2,
    UpgradeCost = {1, 2},
    AllyImmune = false,
    BaseArea = 4,
    BaseDamage = 3,
    Enhanced = false,
    TipDmg = 3, -- 起名 Damage 或 TipDamage 都会导致预览上显示伤害数值
    TipImage = {
        Unit = Point(2, 3),
        Enemy = Point(2, 1),
        Enemy2 = Point(1, 2),
        Friendly = Point(1, 3),
        Friendly2 = Point(4, 4),
        Target = Point(2, 1),
        CustomPawn = "EnvMechRanged"
    }
}

Env_Weapon_4_A = Env_Weapon_4:new{
    UpgradeDescription = Weapon_Texts.Env_Weapon_4_A_UpgradeDescription,
    Passive = "Env_Weapon_4_A",
    AllyImmune = true,
    TipImage = {
        Unit = Point(2, 3),
        Enemy = Point(2, 1),
        Enemy2 = Point(1, 2),
        Friendly = Point(1, 3),
        Friendly2 = Point(2, 2),
        Target = Point(2, 1),
        CustomPawn = "EnvMechRanged"
    }
}

Env_Weapon_4_B = Env_Weapon_4:new{
    UpgradeDescription = Weapon_Texts.Env_Weapon_4_B_UpgradeDescription,
    Passive = "Env_Weapon_4_B",
    Enhanced = true,
    TipDmg = 5
}

Env_Weapon_4_AB = Env_Weapon_4:new{
    Passive = "Env_Weapon_4_AB",
    AllyImmune = true,
    Enhanced = true,
    TipImage = Env_Weapon_4_A.TipImage,
    TipDmg = 5
}

-- 使用提示效果，用假方格模拟环境锁定
function Env_Weapon_4:GetSkillEffect(p1, p2)
    -- 不要作判断，直接全清，否则在不同 TipImage 间切换会混
    Board:SetCustomTile(Point(1, 1), "ground_0.png")
    Board:SetCustomTile(Point(2, 4), "ground_0.png")
    Board:SetCustomTile(Point(3, 2), "ground_0.png")
    Board:SetCustomTile(Point(3, 0), "ground_0.png")
    Board:SetCustomTile(Point(0, 2), "ground_0.png")

    local planned = {Point(1, 1), Point(2, 4), Point(3, 2)}
    if self.Enhanced then
        planned[#planned + 1] = Point(3, 0)
        planned[#planned + 1] = Point(0, 2)
    end

    local bounceAmount = 10
    local point = Point(2, 3)
    local ret = SkillEffect()
    local damage = SpaceDamage(point, 0)
    damage.sSound = "/weapons/gravwell"
    ret:AddDamage(damage)
    ret:AddBounce(point, bounceAmount)
    for j, space in ipairs(planned) do
        damage = SpaceDamage(space, 0)
        local delay = j < #planned and NO_DELAY or FULL_DELAY
        damage.sAnimation = "EnvExploRepulse"
        damage.sSound = "/impact/generic/explosion"
        damage.bHide = true
        ret:AddArtillery(point, damage, "effects/env_shot_U.png", delay)
    end

    -- 必须要用不同的全局变量存储，否则在不同 TipImage 间切换会混
    local global = nil
    if not self.AllyImmune and not self.Enhanced then
        global = "ENV_GLOBAL.Env_Passive_TipImage_Planned"
        ENV_GLOBAL.Env_Passive_TipImage_Planned = planned
    elseif self.AllyImmune and not self.Enhanced then
        global = "ENV_GLOBAL.Env_Passive_TipImage_Planned_A"
        ENV_GLOBAL.Env_Passive_TipImage_Planned_A = planned
    elseif not self.AllyImmune and self.Enhanced then
        global = "ENV_GLOBAL.Env_Passive_TipImage_Planned_B"
        ENV_GLOBAL.Env_Passive_TipImage_Planned_B = planned
    elseif self.AllyImmune and self.Enhanced then
        global = "ENV_GLOBAL.Env_Passive_TipImage_Planned_AB"
        ENV_GLOBAL.Env_Passive_TipImage_Planned_AB = planned
    end
    ret:AddScript([[
        for i, epp in ipairs(]] .. global .. [[) do
            Board:SetCustomTile(epp, "tile_lock.png")
        end
        Game:TriggerSound("/props/square_lightup")
    ]])
    ret:AddDelay(0.7)
    if self.AllyImmune then
        damage = SpaceDamage(Point(2, 2), 0, 1)
        damage.bHide = true
        ret:AddMelee(Point(1, 2), damage)
        ret:AddScript([[Board:SetCustomTile(Point(3, 2), "tile_lock_friendunit.png")]])
    end
    damage = SpaceDamage(Point(1, 2), 0, 0)
    damage.bHide = true
    ret:AddMelee(Point(1, 3), damage)
    ret:AddDelay(0.4)
    ret:AddSound("/impact/generic/explosion_large")
    for i, location in ipairs(planned) do
        if not self.AllyImmune or location ~= Point(3, 2) then -- 此处 PawnTeam 不是 TEAM_PLAYER，只能写死判断
            damage = SpaceDamage(location, self.TipDmg)
            damage.sAnimation = "Env_Passive_Animation" .. random_int(2)
            damage.bHide = true
            ret:AddDamage(damage)
        end
        ret:AddScript([[Board:SetCustomTile(]] .. location:GetString() .. [[, "ground_0.png")]])
    end
    if self.TipDmg < 5 then -- Alert 就不加了，TipImage 太小加了也看不见
        ret:AddScript([[Board:Ping(Point(1, 1), GL_Color(196, 182, 86, 0))]])
    end
    ret:AddDelay(1.2)
    return ret
end

local function initMissionWeapon(mission)
    pawnMap:Clear()
    local wp1 = tool:GetWeapon("Env_Weapon_1")
    if wp1 == "B" or wp1 == "AB" then
        local pawns = extract_table(Board:GetPawns(TEAM_MECH))
        for i, id in ipairs(pawns) do
            local pawn = Board:GetPawn(id)
            if tool:HasWeapon(pawn, "Env_Weapon_1") then
                pawnMap:Set(id, "JumpMove", true)
                pawnMap:Set(id, "IgnoreWeb", true)
                break -- 自定义中有同名机甲时可能会出错，干脆禁止玩家从中获利，不要让多个机甲获得加成
            end
        end
    end
    mission.EnvWeapon_Init = true
end

local Weapons = {}
function Weapons:Load()
    Global_Texts.EnvOverloadDisabled = EnvMod_Texts.env_overload_disabled
    Global_Texts.EnvPassiveDisabled_Title = Weapon_Texts.Env_Weapon_4_Name
    Global_Texts.EnvPassiveDisabled_Text = EnvMod_Texts.env_passive_disabled

    modApi:addNextTurnHook(function(mission)
        if not mission.EnvWeapon_Init then
            initMissionWeapon(mission)
        end
    end)
    modApi:addPostLoadGameHook(function() -- 继续游戏
        modApi:runLater(function(mission)
            -- 有时候尽管关卡也会执行该 Hook，更糟糕的是此时获取到的 GameData 中数据不是最新的，不能用
            -- 总之，等 NextTurn Hook 处理过一遍后再来
            -- 以后，只要是继续游戏，GameData 就必然是最新的
            if mission.EnvWeapon_Init then
                initMissionWeapon(mission)
            end
        end)
    end)
end
return Weapons
