local mod = mod_loader.mods[modApi.currentMod]
local tool = mod.tool

Mission_Force.Env_MountainValid = true -- 破坏两座山关卡
Mission_Holes.Env_FlyValid = true -- 深坑马蜂关卡

-- 水坝关卡
function Mission_Dam:GetEnvForceZone()
    local ret = {}
    local damZone = Board:GetZone("dam")
    if damZone and damZone:size() > 0 then
        local dam = damZone:index(1) -- 只锁真实位置，附加位置上无法显示环境警告，很容易被玩家忽略
        local pawn = Board:GetPawn(dam)
        if pawn and not pawn:IsDead() then
            ret = {dam, dam} -- 增加被锁定的概率
        end
    end
    return ret
end

-- 破坏两座山关卡
function Mission_Force:GetEnvForceZone()
    local ret = {}
    local mounts = {}
    for _, x in ipairs({0, 7}) do
        for y = 0, 7 do
            local point = Point(x, y)
            if tool:IsDamagedMountain(point) then
                mounts[#mounts + 1] = point
            end
        end
    end
    for _, y in ipairs({0, 7}) do
        for x = 1, 6 do
            local point = Point(x, y)
            if tool:IsDamagedMountain(point) then
                mounts[#mounts + 1] = point
            end
        end
    end
    local cnt = 0
    while cnt < 1 and #mounts > 0 do -- 选 n 座加进来
        ret[#ret + 1] = random_removal(mounts)
        cnt = cnt + 1
    end
    return ret
end

local this = {}

function this:Load()
    -- nothing to do
end

return this
