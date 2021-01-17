-- 简化操作的全局变量，仅适用于临时传递
-- 某些状态需要退出游戏后固化到本地，可以存在 Mission 上
ENV_GLOBAL = {}

local mod = {
    id = "EnvManipulators",
    name = "EnvManipulators",
    version = "1.7.1.20210118",
    requirements = {"kf_ModUtils"},
    modApiVersion = "2.5.4",
    icon = "img/icon.png",
    author = "Compartany"
}
print(mod.version) -- for package and release

function mod:init()
    self:initResources()
    self:initScripts()
    self:initOptions()
end

-- 改变设置、继续游戏都会重新加载
function mod:load(options, version)
    env_modApiExt:load(self, options, version)
    self.mechs:Load()
    self.weapons:Load()
    self.env_passive:Load()
    self.environment:Load()
    self.missions:Load()
    self.shop:load(options)
    self.trait:load()
    modApi:addSquad({EnvMod_Texts.squad_name, "EnvMechPrime", "EnvMechRanged", "EnvMechScience"},
        EnvMod_Texts.squad_name, EnvMod_Texts.squad_description, self.resourcePath .. "img/icon.png")
end

function mod:initScripts()
    -- 加载的顺序很重要，不要乱调
    env_modApiExt = require(self.scriptPath .. "modApiExt/modApiExt")
    env_modApiExt:init()
    self.tool = require(self.scriptPath .. "tool")
    self.animations = require(self.scriptPath .. "animations")
    self.mechs = require(self.scriptPath .. "mechs")
    self.weapons = require(self.scriptPath .. "weapons")
    self.env_passive = require(self.scriptPath .. "env_passive")
    self.environment = require(self.scriptPath .. "environment")
    self.missions = require(self.scriptPath .. "missions")
    self.shop = require(self.scriptPath .. "libs/shop")
    self.trait = require(self.scriptPath .. "libs/trait")
end

function mod:initOptions()
    local weapons = {"Env_Weapon_1", "Env_Weapon_2", "Env_Weapon_3", "Env_Weapon_4"}
    local disabled = {
        Env_Weapon_4 = true
    }
    for i, weapon in ipairs(weapons) do
        local name = Weapon_Texts[weapon .. "_Name"]
        self.shop:addWeapon({
            id = weapon,
            name = name,
            desc = string.format(EnvMod_Texts.add_to_shop, name),
            default = disabled[weapon] and {
                enabled = false
            } or nil
        })
    end
end

function mod:initResources()
    modApi:appendAsset("img/combat/icons/env_lock.png", self.resourcePath .. "img/env_lock.png")
    -- 需提供 glow
    modApi:appendAsset("img/combat/icons/icon_envheavy.png", self.resourcePath .. "img/icon/icon_envheavy.png")
    modApi:appendAsset("img/combat/icons/icon_envheavy_glow.png", self.resourcePath .. "img/icon/icon_envheavy_glow.png")
    -- 需提供 U、R 两张图才能被平射使用
    modApi:appendAsset("img/effects/env_shot_U.png", self.resourcePath .. "img/env_shot.png")
    modApi:appendAsset("img/effects/env_shot_R.png", self.resourcePath .. "img/env_shot.png")

    -- 加到方格目录下，这样可以被 Board:SetCustomTile() 使用
    local tileTypes = {"grass", "sand", "snow", "acid", "volcano", "lava"}
    for i, type in ipairs(tileTypes) do
        modApi:appendAsset("img/combat/tiles_" .. type .. "/tile_lock.png",
            self.resourcePath .. "img/tile_lock/" .. type .. ".png")
        modApi:appendAsset("img/combat/tiles_" .. type .. "/tile_lock_friendunit.png",
            self.resourcePath .. "img/tile_lock/" .. type .. "_friendunit.png")
    end

    -- 设置图片偏移
    Location["combat/icons/env_lock.png"] = Point(-27, 2)
    Location["combat/icons/icon_envheavy.png"] = Point(-12, 8)

    local weaponImgs = {"env_weapon_1.png", "env_weapon_2.png", "env_weapon_3.png", "env_weapon_4.png"}
    for i, weaponImg in ipairs(weaponImgs) do
        modApi:appendAsset("img/weapons/" .. weaponImg, self.resourcePath .. "img/weapons/" .. weaponImg)
    end

    if modApi:getLanguageIndex() == Languages.Chinese_Simplified then
        modApi:addWeapon_Texts(require(self.scriptPath .. "localization/chinese/Weapon_Texts"))
        require(self.scriptPath .. "localization/chinese/EnvMod_Texts")
    else
        modApi:addWeapon_Texts(require(self.scriptPath .. "localization/english/Weapon_Texts"))
        require(self.scriptPath .. "localization/english/EnvMod_Texts")
    end

    require(self.scriptPath .. "libs/FURL")(mod, {{
        Type = "color",
        Name = "EnvManipulatorsColors",
        PlateHighlight = {76, 161, 255}, -- 高光    rgb(76, 161, 255)
        PlateLight = {196, 182, 86}, -- 主色        rgb(196, 182, 86)
        PlateMid = {96, 86, 32}, -- 主色阴影        rgb(96, 86, 32)
        PlateDark = {30, 29, 10}, -- 主色暗部       rgb(30, 29, 10)
        PlateOutline = {0, 0, 0}, -- 线条           rgb(0, 0, 0)
        PlateShadow = {28, 28, 28}, -- 副色暗部     rgb(28, 28, 28)
        BodyColor = {67, 72, 68}, -- 副色阴影       rgb(67, 72, 68)
        BodyHighlight = {159, 170, 153} -- 副色     rgb(159, 170, 153)
    }, {
        Type = "mech",
        Name = "mech_env_prime",
        Filename = "mech_env_prime",
        Path = "img/mech_prime",
        Default = {
            PosX = -19,
            PosY = -13
        },
        Animated = {
            PosX = -19,
            PosY = -13,
            NumFrames = 4
        },
        Submerged = {
            PosX = -18,
            PosY = 10
        },
        Broken = {
            PosX = -19,
            PosY = -13
        },
        SubmergedBroken = {
            PosX = -18,
            PosY = 10
        },
        Icon = {}
    }, {
        Type = "mech",
        Name = "mech_env_ranged",
        Filename = "mech_env_ranged",
        Path = "img/mech_ranged",
        Default = {
            PosX = -19,
            PosY = -7
        },
        Animated = {
            PosX = -19,
            PosY = -7,
            NumFrames = 4
        },
        Submerged = {
            PosX = -19,
            PosY = 10
        },
        Broken = {
            PosX = -19,
            PosY = -7
        },
        SubmergedBroken = {
            PosX = -19,
            PosY = 10
        },
        Icon = {}
    }, {
        Type = "mech",
        Name = "mech_env_science",
        Filename = "mech_env_science",
        Path = "img/mech_science",
        Default = {
            PosX = -16,
            PosY = -9
        },
        Animated = {
            PosX = -16,
            PosY = -9,
            NumFrames = 4
        },
        Submerged = {
            PosX = -16,
            PosY = 9
        },
        Broken = {
            PosX = -16,
            PosY = 5
        },
        SubmergedBroken = {
            PosX = -16,
            PosY = 9
        },
        Icon = {}
    }})
end

return mod
