local mod = mod_loader.mods[modApi.currentMod]
local tool = mod.tool

------------------
-- Env_Weapon_1 --
------------------
Env_Weapon_1 = Skill:new{
    Name = EnvWeapon_Texts.Env_Weapon_1_Name,
    Description = EnvWeapon_Texts.Env_Weapon_1_Description,
    Class = "Prime",
    Icon = "weapons/env_weapon_1.png",
    Damage = 0,
    Pull = false,
    PullLength = 3,
    Overload = false,
    PowerCost = 0,
    Upgrades = 2,
    UpgradeCost = {2, 3},
    UpgradeList = {EnvWeapon_Texts.Env_Weapon_1_Upgrade1, EnvWeapon_Texts.Env_Weapon_1_Upgrade2},
    TipImage = {
        Unit = Point(2, 2),
        Enemy = Point(2, 1),
        Enemy2 = Point(2, 3),
        Enemy3 = Point(3, 2),
        Target = Point(1, 1)
    }
}

Env_Weapon_1_A = Env_Weapon_1:new{
    UpgradeDescription = EnvWeapon_Texts.Env_Weapon_1_A_UpgradeDescription,
    Pull = true,
    TipImage = {
        Unit = Point(2, 2),
        Enemy = Point(2, 0),
        Enemy2 = Point(5, 2),
        Target = Point(2, 1)
    }
}

Env_Weapon_1_B = Env_Weapon_1:new{
    UpgradeDescription = EnvWeapon_Texts.Env_Weapon_1_B_UpgradeDescription,
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
            for _, v in ipairs(dirs) do
                local target = curr + DIR_VECTORS[v]
                if Board:IsValid(target) then
                    ret:push_back(target)
                end
            end
        end
        if self.Pull then
            for i = 2, self.PullLength do
                curr = point + DIR_VECTORS[dir] * i
                if tool:IsMovable(curr) then
                    local valid = true
                    for j = 1, i - 1 do
                        local target = curr - DIR_VECTORS[dir] * j
                        local terrain = Board:GetTerrain(target)
                        if not tool:IsEmptyTile(target) then
                            valid = false
                        elseif not Pawn:IsFlying() and (terrain == TERRAIN_WATER or terrain == TERRAIN_HOLE) then
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
                        if not valid then
                            break
                        end
                    end
                    if valid then
                        ret:push_back(point + DIR_VECTORS[dir])
                    end
                    break
                end
            end
        end
    end
    return ret
end

function Env_Weapon_1:GetSkillEffect(p1, p2)
    return Board:IsTipImage() and self:GetSkillEffect_TipImage() or self:GetSkillEffect_Inner(p1, p2)
end

-- 不能直接在 GetSkillEffect() 上追加参数，因为其他 MOD 引进的 modApiExt 也可能在上面追加参数导致冲突
function Env_Weapon_1:GetSkillEffect_Inner(p1, p2, tipImageCall, skillEffect, param)
    tipImageCall = tipImageCall or false
    local overloadActive = Pawn:IsEnvOverloadActive()
    local tipImageFire = tipImageCall and self.Overload
    local iFire = EFFECT_NONE
    if not Pawn:IsIgnoreFire() then
        if overloadActive or tipImageFire or Pawn:IsFire() then
            iFire = EFFECT_CREATE
        end
    end
    local iAcid = Pawn:IsAcid() and EFFECT_CREATE or EFFECT_NONE
    local bHide = tipImageCall and self.Overload
    local hidePullPath = param and param.hidePullPath or false

    local ret = skillEffect or SkillEffect()
    local dist = p1:Manhattan(p2)
    local damage = nil

    if dist == 1 and self.Pull then
        local dir = GetDirection(p2 - p1)
        local dirBack = GetDirection(p1 - p2)
        local obj = p1 + DIR_VECTORS[dir] * 2
        for i = 3, self.PullLength do
            if tool:IsMovable(obj) then
                break
            end
            obj = p1 + DIR_VECTORS[dir] * i
        end
        local p3 = obj - DIR_VECTORS[dir]
        local pullDist = obj:Manhattan(p2)
        if iFire == EFFECT_NONE then
            iFire = (Board:IsFire(p3) and not Pawn:IsIgnoreFire()) and EFFECT_CREATE or EFFECT_NONE
        end
        if iAcid == EFFECT_NONE then
            iAcid = Board:IsAcid(p3) and EFFECT_CREATE or EFFECT_NONE
        end
        if hidePullPath then
            ret:AddScript(string.format([[
                local p1 = %s
                local p3 = %s
                local fx = SkillEffect()
                fx:AddMove(Board:GetSimplePath(p1, p3), FULL_DELAY)
                fx:AddDelay(0.3)
                fx:AddMove(Board:GetSimplePath(p3, p1), FULL_DELAY)
                Board:AddEffect(fx)
            ]], p1:GetString(), p3:GetString()))
            ret:AddDelay(0.5) -- 让 script 在 delay 期间运行
        else
            ret:AddMove(Board:GetSimplePath(p1, p3), FULL_DELAY)
            ret:AddDelay(0.3)
            ret:AddMove(Board:GetSimplePath(p3, p1), FULL_DELAY)
        end
        if overloadActive or tipImageFire then
            ret:AddSafeDamage(tool:RemoveDebuffDamage(p1, EFFECT_NONE)) -- SafeDamage 会将刚刚引燃的地面给修复
        else
            ret:AddSafeDamage(tool:RemoveDebuffDamage(p1))
        end
        damage = SpaceDamage(obj, self.Damage)
        if pullDist < 2 then
            damage.iPush = dirBack
        end
        damage.iFire = iFire
        damage.iAcid = iAcid
        damage.bHide = bHide
        ret:AddDamage(damage)
        if pullDist > 1 then
            ret:AddCharge(Board:GetSimplePath(obj, p2), FULL_DELAY)
        end
    else
        local objs = {}
        for dir = DIR_START, DIR_END do
            local curr = p1 + DIR_VECTORS[dir]
            if Board:IsPawnSpace(curr) then
                objs[#objs + 1] = curr
            end
        end
        -- 优先处理逆时针方向位移
        local pushDelay = false
        for _, obj in ipairs(objs) do
            local dir = GetDirection(obj - p1)
            local dir2 = GetDirection(p2 - obj)
            local dirLeft = (dir + 3) % 4
            if dir2 == dirLeft then
                damage = SpaceDamage(obj, self.Damage, dir2)
                damage.iFire = iFire
                damage.iAcid = iAcid
                damage.bHide = bHide
                damage.sAnimation = "explopunch1_" .. dir2
                damage.sSound = "/weapons/titan_fist"
                ret:AddMelee(p1, damage)

                if overloadActive or tipImageFire then
                    ret:AddSafeDamage(tool:RemoveDebuffDamage(p1, EFFECT_NONE))
                    iFire = EFFECT_CREATE
                else
                    ret:AddSafeDamage(tool:RemoveDebuffDamage(p1))
                    iFire = Board:IsFire(p1) and EFFECT_CREATE or EFFECT_NONE
                end
                if Pawn:IsIgnoreFire() then
                    iFire = EFFECT_NONE
                end
                iAcid = EFFECT_NONE

                -- 判断是否应该添加延时以避免无法同时位移两个地面敌人至水中或深坑中
                -- 非常奇怪的是，像破损的山、一血建筑、一血单位等都不会在这种情况出现问题，只有掉入水中或深坑中动画太长才会导致这一问题
                local pawn = Board:GetPawn(obj)
                if not pawn:IsGuarding() then
                    if Board:IsTerrain(p2, TERRAIN_WATER) then
                        if (not pawn:IsFlying() or pawn:IsFrozen()) and not _G[pawn:GetType()].Massive then
                            pushDelay = true
                        end
                    elseif Board:IsTerrain(p2, TERRAIN_HOLE) then
                        if not pawn:IsFlying() or pawn:IsFrozen() then
                            pushDelay = true
                        end
                    end
                end
                break
            end
        end
        for _, obj in ipairs(objs) do
            local dir = GetDirection(obj - p1)
            local dir2 = GetDirection(p2 - obj)
            local dirRight = (dir + 1) % 4
            if dir2 == dirRight then
                if pushDelay and not Board:GetPawn(obj):IsGuarding() then
                    ret:AddDelay(0.52) -- 0.5 就够，给多一点保险一些
                end
                damage = SpaceDamage(obj, self.Damage, dir2)
                damage.iFire = iFire
                damage.iAcid = iAcid
                damage.bHide = bHide
                damage.sAnimation = "explopunch1_" .. dir2
                damage.sSound = "/weapons/titan_fist"
                ret:AddMelee(p1, damage)
                if overloadActive or tipImageFire then
                    ret:AddSafeDamage(tool:RemoveDebuffDamage(p1, EFFECT_NONE))
                else
                    ret:AddSafeDamage(tool:RemoveDebuffDamage(p1))
                end
                break
            end
        end
    end

    -- overloadActive 时 sImageMark 会被覆盖，此时需要在外层处理中添加 sImageMark
    if not overloadActive then
        local rmdebuff = 0
        if Board:IsFire(p1) and not Pawn:IsIgnoreFire() then
            rmdebuff = 2
        elseif Pawn:IsFire() or Pawn:IsAcid() then
            rmdebuff = 1
        end
        if rmdebuff > 0 then
            damage = SpaceDamage(p1, 0)
            damage.sImageMark = string.format("combat/icons/icon_env_rmdebuff%d.png", rmdebuff)
            damage.bHide = bHide
            ret:AddDamage(damage)
        end
    end

    if self.Overload then
        ret:AddDelay(0.2)
        ret:AddScript(string.format([[
            local id = %d
            local pawn = Board:GetPawn(id)
            if pawn then
                local space = pawn:GetSpace()
                pawn:SetActive(true)
                Game:TriggerSound("/enemy/shared/robot_power_on")
                Board:Ping(space, ENV_GLOBAL.themeColor)

                local mission = GetCurrentMission()
                if mission then
                    if not mission.Overload then
                        mission.Overload = {}
                    end
                    mission.Overload[id] = Game:GetTurnCount()
                end
            end
        ]], Pawn:GetId()))
        ret:AddDelay(0.1)
    end
    return ret
end

-- 注意：TipImage 必须要设置 Unit、Enemy、Target，且它们必须得满足正常攻击发起的逻辑，否则 TipImage 无效
function Env_Weapon_1:GetSkillEffect_TipImage()
    local ret = nil
    local selfSpace = Point(2, 2)
    local s = "Z"
    if self.Pull and not self.Overload then
        s = "A"
        if not self.TI_A then
            self.TI_A = 0
        end
    elseif not self.Pull and self.Overload then
        s = "B"
    elseif self.Pull and self.Overload then
        s = "AB"
    else
        if not self.TI_Z then
            self.TI_Z = 0
        end
    end

    if s == "B" or s == "AB" then
        local fx = SkillEffect()
        fx:AddScript([[
            local fx = SkillEffect()
            local p1 = Point(2, 4)
            local p2 = Point(2, 2)
            local move = PointList()
            fx:AddSound("/weapons/leap")
            move:push_back(p1)
            move:push_back(p2)
            fx:AddBurst(p1, "Emitter_Burst_$tile", DIR_NONE)
            fx:AddLeap(move, FULL_DELAY)
            fx:AddBurst(p2, "Emitter_Burst_$tile", DIR_NONE)
            for i = DIR_START, DIR_END do
                local damage = SpaceDamage(p2 + DIR_VECTORS[i], 0)
                damage.sAnimation = PUSH_ANIMS[i]
                fx:AddDamage(damage)
            end
            fx:AddDamage(ENV_GLOBAL.tool:OverloadDamage(1, p2, p1))
            fx:AddSound("/impact/generic/mech")
            fx:AddBounce(p2, 3)
            Board:AddEffect(fx)
        ]])
        fx:AddDelay(1.6) -- script 会在 delay 期间运行（感谢 Lemonymous 提供的技巧）

        local damage = tool:OverloadDamage(2, selfSpace)
        damage.bHide = true
        if s == "B" then
            ret = self:GetSkillEffect_Inner(selfSpace, Point(1, 1), true, fx)
            ret:AddDelay(1.25)
            ret:AddDamage(damage)
            ret:AddDelay(0.35)
            ret = self:GetSkillEffect_Inner(selfSpace, Point(3, 3), true, fx)
            ret:AddDelay(0.6)
        else
            fx:AddDelay(0.2)
            ret = self:GetSkillEffect_Inner(selfSpace, Point(2, 1), true, fx, {
                hidePullPath = true
            })
            ret:AddDelay(1.25)
            ret:AddDamage(damage)
            ret:AddDelay(0.35)
            ret = self:GetSkillEffect_Inner(selfSpace, Point(3, 3), true, fx)
            ret:AddDelay(0.6)
        end
    else
        Pawn:SetAcid(true)
        if s == "A" then
            if self.TI_A == 0 then
                ret = self:GetSkillEffect_Inner(selfSpace, Point(2, 1), true)
            else
                ret = self:GetSkillEffect_Inner(selfSpace, Point(3, 2), true)
            end
            self.TI_A = (self.TI_A + 1) % 2
        else
            if self.TI_Z == 0 then
                ret = self:GetSkillEffect_Inner(selfSpace, Point(1, 1), true)
            else
                ret = self:GetSkillEffect_Inner(selfSpace, Point(3, 3), true)
                ret:AddDelay(0.6)
            end
            self.TI_Z = (self.TI_Z + 1) % 2
        end
    end
    return ret
end

local _Move_GetTargetArea = Move.GetTargetArea
function Move:GetTargetArea(point, ...)
    if Pawn:IsEnvJumpMove() and (Pawn:IsFlying() or Board:GetTerrain(point) ~= TERRAIN_WATER) and
        (Pawn:IsIgnoreSmoke() or not Board:IsSmoke(point)) then
        return Board:GetReachable(point, 14, PATH_FLYER)
    end
    return _Move_GetTargetArea(self, point, ...)
end
local _Move_GetSkillEffect = Move.GetSkillEffect
function Move:GetSkillEffect(p1, p2, ...)
    if Pawn:IsEnvJumpMove() and (Pawn:IsFlying() or Board:GetTerrain(p1) ~= TERRAIN_WATER) and
        (Pawn:IsIgnoreSmoke() or not Board:IsSmoke(p1)) then
        local needJump = true
        local speed = nil
        if Pawn:IsAbility("Shifty") and Pawn:GetMoveSpeed() == 1 then
            speed = 1
        elseif Pawn:IsEnvHeavy() then
            speed = Pawn:GetBasicMoveSpeed()
        else
            speed = Pawn:GetMoveSpeed()
        end
        local groundReachable = Board:GetReachable(p1, speed, Pawn:GetPathProf())
        for _, point in ipairs(extract_table(groundReachable)) do
            if p2 == point then
                needJump = false
                break
            end
        end
        local ret = SkillEffect()
        if needJump then -- 会飞的时候也进不来
            -- 默认的跳跃处理无特效
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
            local forceAcid = false
            if Board:IsAcid(p2) then
                if not Pawn:IsFlying() or Board:GetTerrain(p2) ~= TERRAIN_WATER then
                    forceAcid = true
                end
            end
            ret:AddDamage(tool:OverloadDamage(1, p2, p1, forceAcid))
            ret:AddScript(string.format([[
                local pawn = Board:GetPawn(%d)
                local hp = pawn:GetHealth()
                if hp > 1 then
                    Game:TriggerSound("/ui/battle/critical_damage")
                end
            ]], Pawn:GetId()))
            ret:AddSound("/impact/generic/mech")
            ret:AddBounce(p2, 3)
        else
            ret = _Move_GetSkillEffect(self, p1, p2, ...)
        end
        if Pawn:IsAbility("Shifty") or Pawn:IsAbility("Post_Move") then
            if Pawn:IsActive() then
                ret:AddDelay(0.2)
                ret:AddScript(string.format([[
                    local id = %d
                    local pawn = Board:GetPawn(id)
                    if pawn then
                        pawn:SetActive(true)
                    end
                ]], Pawn:GetId()))
            end
        end
        return ret
    end
    return _Move_GetSkillEffect(self, p1, p2, ...)
end

------------------
-- Env_Weapon_2 --
------------------
Env_Weapon_2 = LineArtillery:new{
    Name = EnvWeapon_Texts.Env_Weapon_2_Name,
    Description = EnvWeapon_Texts.Env_Weapon_2_Description,
    Class = "Ranged",
    Icon = "weapons/env_weapon_2.png",
    Chain1 = false,
    Chain2 = false,
    PowerCost = 0,
    Damage = 0,
    Range = 7,
    Upgrades = 2,
    UpgradeCost = {2, 2},
    UpgradeList = {EnvWeapon_Texts.Env_Weapon_2_Upgrade1, EnvWeapon_Texts.Env_Weapon_2_Upgrade2},
    LaunchSound = "/weapons/gravwell",
    ImpactSound = "/impact/generic/explosion",
    TipImage = {
        Unit = Point(2, 4),
        Enemy = Point(2, 2),
        Friendly = Point(3, 2),
        Target = Point(2, 2)
    }
}

Env_Weapon_2_A = Env_Weapon_2:new{
    UpgradeDescription = EnvWeapon_Texts.Env_Weapon_2_A_UpgradeDescription,
    Chain1 = true,
    TipImage = {
        Unit = Point(2, 4),
        Enemy = Point(2, 2),
        Enemy2 = Point(1, 1),
        Friendly = Point(3, 2),
        Target = Point(2, 2)
    }
}

Env_Weapon_2_B = Env_Weapon_2:new{
    UpgradeDescription = EnvWeapon_Texts.Env_Weapon_2_B_UpgradeDescription,
    Chain2 = true,
    TipImage = {
        Unit = Point(2, 4),
        Enemy = Point(2, 2),
        Enemy2 = Point(2, 3),
        Friendly = Point(2, 1),
        Friendly2 = Point(3, 2),
        Target = Point(2, 2)
    }
}

Env_Weapon_2_AB = Env_Weapon_2:new{
    Chain1 = true,
    Chain2 = true,
    TipImage = {
        Unit = Point(2, 4),
        Enemy = Point(2, 2),
        Enemy2 = Point(2, 3),
        Enemy3 = Point(1, 1),
        Friendly = Point(2, 1),
        Friendly2 = Point(3, 2),
        Target = Point(2, 2)
    }
}

function Env_Weapon_2:GetTargetArea(point)
    local ret = PointList()
    for dir = DIR_START, DIR_END do
        for i = 2, self.Range do
            local curr = point + DIR_VECTORS[dir] * i
            if Board:IsValid(curr) then
                ret:push_back(curr)
            else
                break
            end
        end
    end
    return ret
end

function Env_Weapon_2:GetSkillEffect(p1, p2)
    return Board:IsTipImage() and self:GetSkillEffect_TipImage() or self:GetSkillEffect_Inner(p1, p2)
end

function Env_Weapon_2:GetSkillEffect_Inner(p1, p2, tipImageCall, skillEffect, param)
    tipImageCall = tipImageCall or false
    local ret = skillEffect or SkillEffect()
    local direction = GetDirection(p2 - p1)
    local tiC1 = param and param.tiC1 or false

    local mission = GetCurrentMission()
    local env = mission and mission.LiveEnvironment
    local envName = mission and mission.Environment or "Env_Null"
    envName = envName and envName or "Env_Null"

    ret:AddBounce(p1, 10)
    local damage = SpaceDamage(p2, self.Damage, direction)
    damage.sAnimation = "EnvExplo"
    local envImmune = not (mission and mission.NoEnvImmune) and IsPassiveSkill("Env_Weapon_4_A")
    local sImageMark = "combat/icons/env_lock.png"
    if envName == "EnvArtificial" or tipImageCall or
        (not mission.MasteredEnv and (not env.Locations or #env.Locations == 0 or mission.SpecialEnv)) then
        if envImmune and tool:IsEnvImmuneProtected(p2, true) then
            sImageMark = "combat/icons/env_lock_immune.png"
        elseif tool:IsGroundReflective(p2) then
            sImageMark = "combat/icons/env_lock_dark.png"
        end
    else
        local immune = envImmune and tool:IsEnvImmuneProtected(p2)
        local mark = env and env:GetEnvImageMark(immune)
        if mark then
            sImageMark = mark
        elseif immune then
            sImageMark = "combat/icons/env_lock_immune.png"
        elseif tool:IsGroundReflective(p2) then
            sImageMark = "combat/icons/env_lock_dark.png"
        end
    end
    damage.sImageMark = sImageMark
    ret:AddArtillery(damage, "effects/env_shot_U.png")

    if envName ~= "Env_Null" and not tipImageCall then -- TipImage 会引起 Script 执行
        local strEnv = "local env = GetCurrentMission().LiveEnvironment"
        if not mission.MasteredEnv and (not env.Locations or #env.Locations == 0 or mission.SpecialEnv) then
            strEnv = strEnv .. ".OverlayEnv"
        end
        ret:AddScript(strEnv .. "; env.Locations[#env.Locations + 1] = " .. p2:GetString())
    end

    local dirLeft = (direction + 3) % 4
    local dirRight = (direction + 1) % 4
    local pushDirs = {dirLeft, dirRight}
    for _, dir in ipairs(pushDirs) do
        damage = SpaceDamage(p2 + DIR_VECTORS[dir], 0, dir)
        damage.sAnimation = PUSH_ANIMS[dir]
        ret:AddDamage(damage)
    end
    local p3 = p2 + DIR_VECTORS[direction]
    if self.Chain1 then
        if tiC1 or (tool:IsMovable(p2) and tool:IsEmptyTile(p3)) then
            ret:AddDelay(0.35)
            for _, dir in ipairs({dirLeft, dirRight}) do
                damage = SpaceDamage(p3 + DIR_VECTORS[dir], 0, dir)
                damage.sAnimation = PUSH_ANIMS[dir]
                damage.bHide = tiC1
                ret:AddDamage(damage)
            end
        end
    end
    if self.Chain2 then
        if not tiC1 and not tool:IsEmptyTile(p2) and (not tool:IsMovable(p2) or not tool:IsEmptyTile(p3)) then
            local dirBack = (direction + 2) % 4
            ret:AddDelay(0.25)
            for _, dir in ipairs({direction, dirBack}) do
                damage = SpaceDamage(p2 + DIR_VECTORS[dir], 0, dir)
                damage.sAnimation = PUSH_ANIMS[dir]
                ret:AddDamage(damage)
            end
        end
    end
    return ret
end

function Env_Weapon_2:GetSkillEffect_TipImage()
    local ret = SkillEffect()
    if self.Chain1 and self.Chain2 then
        self:GetSkillEffect_Inner(Point(2, 4), Point(2, 2), true, ret)
        ret:AddScript([[Board:SetCustomTile(Point(2, 2), "tile_lock.png")]])
        ret:AddDelay(1.2)
        self:GetSkillEffect_Inner(Point(2, 4), Point(2, 2), true, ret, {
            tiC1 = true
        })
        ret:AddDelay(1.5)
        ret:AddScript([[Board:SetCustomTile(Point(2, 2), "ground_0.png")]])
    else
        self:GetSkillEffect_Inner(Point(2, 4), Point(2, 2), true, ret)
        ret:AddScript([[Board:SetCustomTile(Point(2, 2), "tile_lock.png")]])
        ret:AddDelay(1.5)
        ret:AddScript([[Board:SetCustomTile(Point(2, 2), "ground_0.png")]])
    end
    return ret
end

------------------
-- Env_Weapon_3 --
------------------
Env_Weapon_3 = Skill:new{
    Name = EnvWeapon_Texts.Env_Weapon_3_Name,
    Description = EnvWeapon_Texts.Env_Weapon_3_Description,
    Class = "Science",
    Icon = "weapons/env_weapon_3.png",
    Range = 3,
    Damage = 0,
    PowerCost = 1,
    Upgrades = 2,
    UpgradeCost = {1, 3},
    UpgradeList = {EnvWeapon_Texts.Env_Weapon_3_Upgrade1, EnvWeapon_Texts.Env_Weapon_3_Upgrade2},
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
    UpgradeDescription = EnvWeapon_Texts.Env_Weapon_3_A_UpgradeDescription,
    Range = 4,
    TipImage = {
        Unit = Point(2, 4),
        Enemy = Point(2, 1),
        Mountain = Point(2, 2),
        Target = Point(2, 0)
    }
}

Env_Weapon_3_B = Env_Weapon_3:new{
    UpgradeDescription = EnvWeapon_Texts.Env_Weapon_3_B_UpgradeDescription,
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
        for i = 2, self.Range do
            local curr = point + DIR_VECTORS[dir] * i
            if Board:IsValid(curr) then
                ret:push_back(curr)
            else
                break
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
    for i = 1, dist do -- 将 dist 处的 obj 也加进来方便 dest 计算
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
            local needMove = obj ~= dests[i]
            local movable = tool:IsMovable(obj)
            if needMove and movable then
                ret:AddCharge(Board:GetSimplePath(obj, dests[i]), FULL_DELAY)
            end
            local dest = tool:IsMovable(obj) and dests[i] or obj
            if dest ~= p2 then
                local damage = SpaceDamage(dest, self.Damage)
                damage.sAnimation = "EnvExplo"
                damage.sSound = "/impact/generic/explosion"
                ret:AddDamage(damage)
                ret:AddBounce(dest, -2)
                ret:AddDelay(0.05)
            else
                ret:AddDamage(SpaceDamage(dest, self.Damage)) -- 一定要加，否则 XP 会被平分
            end
            if needMove and not movable then -- 需将 obj 移动却移动不了，说明已经断链
                break
            end
        end
    end
    return ret
end

------------------
-- Env_Weapon_4 --
------------------
Env_Weapon_4 = PassiveSkill:new{
    Name = EnvWeapon_Texts.Env_Weapon_4_Name,
    Description = EnvWeapon_Texts.Env_Weapon_4_Description,
    Passive = "Env_Weapon_4",
    Icon = "weapons/env_weapon_4.png",
    PowerCost = 3,
    Upgrades = 2,
    UpgradeCost = {3, 3},
    UpgradeList = {EnvWeapon_Texts.Env_Weapon_4_Upgrade1, EnvWeapon_Texts.Env_Weapon_4_Upgrade2},
    EnvImmune = false,
    BaseArea = 4,
    BaseDamage = 4,
    Enhanced = false,
    Damage = 4,
    TipImage = {
        Unit = Point(2, 3),
        Enemy = Point(2, 1),
        Enemy2 = Point(1, 2),
        Friendly = Point(1, 3),
        Friendly2 = Point(5, 5), -- 多添加一个友方单位使 Friendly 变成 1 号机甲
        Target = Point(2, 1),
        CustomPawn = "EnvMechRanged"
    }
}

Env_Weapon_4_A = Env_Weapon_4:new{
    UpgradeDescription = EnvWeapon_Texts.Env_Weapon_4_A_UpgradeDescription,
    Passive = "Env_Weapon_4_A",
    EnvImmune = true,
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
    UpgradeDescription = EnvWeapon_Texts.Env_Weapon_4_B_UpgradeDescription,
    Passive = "Env_Weapon_4_B",
    Enhanced = true,
    Damage = 5
}

Env_Weapon_4_AB = Env_Weapon_4:new{
    Passive = "Env_Weapon_4_AB",
    EnvImmune = true,
    Enhanced = true,
    TipImage = Env_Weapon_4_A.TipImage,
    Damage = 5
}

-- 使用提示效果，用假方格模拟环境锁定
function Env_Weapon_4:GetSkillEffect(p1, p2)
    -- 不要作判断，直接全清，否则在不同 TipImage 间切换会混
    Board:SetCustomTile(Point(1, 1), "ground_0.png")
    Board:SetCustomTile(Point(2, 4), "ground_0.png")
    Board:SetCustomTile(Point(3, 2), "ground_0.png")
    Board:SetCustomTile(Point(4, 4), "ground_0.png")

    local planned = {Point(1, 1), Point(2, 4), Point(3, 2), Point(4, 4)}
    local bounceAmount = 10
    local point = Point(2, 3)
    local ret = SkillEffect()
    local damage = SpaceDamage(point, 0)
    damage.sSound = "/weapons/gravwell"
    ret:AddDamage(damage)
    ret:AddBounce(point, bounceAmount)
    for i, space in ipairs(planned) do
        damage = SpaceDamage(space, 0)
        local delay = i < #planned and NO_DELAY or FULL_DELAY
        damage.sAnimation = "EnvExplo"
        damage.sSound = "/impact/generic/explosion"
        damage.bHide = true
        ret:AddArtillery(point, damage, "effects/env_shot_U.png", delay)
    end

    -- 必须要用不同的全局变量存储，否则在不同 TipImage 间切换会混
    local global = nil
    if not self.EnvImmune and not self.Enhanced then
        global = "ENV_GLOBAL.EnvArtificial_TipImage_Planned"
        ENV_GLOBAL.EnvArtificial_TipImage_Planned = planned
    elseif self.EnvImmune and not self.Enhanced then
        global = "ENV_GLOBAL.EnvArtificial_TipImage_Planned_A"
        ENV_GLOBAL.EnvArtificial_TipImage_Planned_A = planned
    elseif not self.EnvImmune and self.Enhanced then
        global = "ENV_GLOBAL.EnvArtificial_TipImage_Planned_B"
        ENV_GLOBAL.EnvArtificial_TipImage_Planned_B = planned
    elseif self.EnvImmune and self.Enhanced then
        global = "ENV_GLOBAL.EnvArtificial_TipImage_Planned_AB"
        ENV_GLOBAL.EnvArtificial_TipImage_Planned_AB = planned
    end
    ret:AddScript([[
        for _, epp in ipairs(]] .. global .. [[) do
            Board:SetCustomTile(epp, "tile_lock.png")
        end
        Game:TriggerSound("/props/square_lightup")
    ]])
    ret:AddDelay(0.7)
    if self.EnvImmune then
        damage = SpaceDamage(Point(2, 2), 0, 1)
        damage.bHide = true
        ret:AddMelee(Point(1, 2), damage)
        ret:AddScript([[Board:SetCustomTile(Point(3, 2), "tile_lock_immune.png")]])
    end
    damage = SpaceDamage(Point(1, 2), 0, 0)
    damage.bHide = true
    ret:AddMelee(Point(1, 3), damage)
    ret:AddDelay(0.4)
    ret:AddSound("/impact/generic/explosion_large")
    for _, location in ipairs(planned) do
        if not self.EnvImmune or location ~= Point(3, 2) then -- TipImage 中 PawnTeam 不是 TEAM_PLAYER，只能写死判断
            damage = SpaceDamage(location, self.Damage)
            damage.sAnimation = "EnvArtificial_Animation" .. random_int(2)
            damage.bHide = true
            ret:AddDamage(damage)
        end
        ret:AddScript([[Board:SetCustomTile(]] .. location:GetString() .. [[, "ground_0.png")]])
    end
    if self.Damage < 5 then -- Alert 就不加了，TipImage 太小加了也看不见
        ret:AddScript([[Board:Ping(Point(1, 1), ENV_GLOBAL.themeColor)]])
    end
    ret:AddDelay(1.2)
    return ret
end

local Weapons = {}
function Weapons:Load()
    Global_Texts.EnvArtificialDisabled_Title = EnvWeapon_Texts.Env_Weapon_4_Name
    Global_Texts.EnvArtificialDisabled_Text = EnvMod_Texts.envArtificial_disabled

    env_modApiExt:addSkillBuildHook(function(mission, pawn, weaponId, p1, p2, skillFx)
        if weaponId ~= "Move" and pawn and pawn:IsEnvOverloadActive() then
            if not skillFx.effect:empty() then
                local fx = SkillEffect()
                local effects = extract_table(skillFx.effect)
                local damage = tool:OverloadDamage(2, p1)
                local shifter = tool:ExtractWeapon(weaponId) == "Env_Weapon_1"
                local repair = modApi:stringStartsWith(weaponId, "Skill_Repair")

                local dmg = 2
                if pawn:IsShield() then
                    dmg = 0
                elseif pawn:IsAcid() then
                    dmg = 4
                end
                if repair then
                    dmg = dmg - 1
                end
                local alive = pawn:GetHealth() - dmg > 0
                if not repair then
                    if shifter and alive then
                        if pawn:IsFire() or pawn:IsAcid() then
                            damage.sImageMark = "combat/icons/icon_env_rmdebuff2.png"
                        end
                    end
                    fx:AddDamage(damage)
                    if alive then
                        fx:AddDelay(0.35)
                    end
                end
                if alive then
                    -- 过载融化冰面会打断攻击
                    if pawn:IsFlying() or Board:GetTerrain(p1) ~= TERRAIN_ICE then
                        for _, e in pairs(effects) do
                            fx.effect:push_back(e)
                        end
                    end
                    if IsTestMechScenario() and not shifter then
                        fx:AddScript([[
                            local mission = GetCurrentMission()
                            if mission then
                                mission.Overload = {}
                            end
                        ]])
                    end
                end
                if repair then
                    fx:AddDamage(damage)
                end
                skillFx.effect = fx.effect
            end
        end
    end)
    modApi:addTestMechEnteredHook(function(mission)
        mission.Overload = nil
    end)
end
return Weapons
