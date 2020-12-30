-- 简化操作的全局变量，仅适用于临时传递
-- 某些状态需要退出游戏后固化到本地，可以存在 Mission 上
ENV_GLOBAL = {}

local mod = {
    id = "EnvManipulators",
    name = "EnvManipulators",
    version = "1.0.4.20201230",
    requirements = {},
    modApiVersion = "2.5.4",
    icon = "img/icon.png",
    autor = "Compartany"
}
print(mod.version) -- for package

-- 该 MOD 的装备不加到商店中，没有配合用不出来，且会极大程度增加 MOD 编写难度
function mod:init()
    if modApi:getLanguageIndex() == Languages.Chinese_Simplified then
        modApi:addWeapon_Texts(require(self.scriptPath .. "localization/chinese/Weapon_Texts"))
        require(self.scriptPath .. "localization/chinese/EnvMod_Texts")
    else
        modApi:addWeapon_Texts(require(self.scriptPath .. "localization/english/Weapon_Texts"))
        require(self.scriptPath .. "localization/english/EnvMod_Texts")
    end

    require(self.scriptPath .. "lib/FURL")(self, {{
        Type = "color",
        Name = "EnvManipulatorsColors",
        PlateHighlight = {76, 161, 255}, -- lights
        PlateLight = {196, 182, 86}, -- main highlight
        PlateMid = {96, 86, 32}, -- main light
        PlateDark = {30, 29, 10}, -- main mid
        PlateOutline = {0, 0, 0}, -- main dark
        PlateShadow = {28, 28, 28}, -- metal dark
        BodyColor = {67, 72, 68}, -- metal mid
        BodyHighlight = {159, 170, 153} -- metal light
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

    -- 加载的顺序很重要，不要乱调
    self.tool = require(self.scriptPath .. "tool")
    self.animations = require(self.scriptPath .. "animations")
    self.mechs = require(self.scriptPath .. "mechs")
    self.weapons = require(self.scriptPath .. "weapons")
    self.environment = require(self.scriptPath .. "environment")
    self.env_passive = require(self.scriptPath .. "env_passive")
    self.shop = require(self.scriptPath .. "lib/shop")

    modApi:appendAsset("img/combat/icons/env_lock.png", self.resourcePath .. "img/env_lock.png")
    -- 需提供 U、R 两张图才能被平射使用
    modApi:appendAsset("img/effects/env_shot_U.png", self.resourcePath .. "img/env_shot.png")
    modApi:appendAsset("img/effects/env_shot_R.png", self.resourcePath .. "img/env_shot.png")

    -- 加到方格目录下，这样可以被 Board:SetCustomTile() 使用
    local tileType = {"grass", "sand", "snow", "acid", "volcano", "lava"}
    for i, type in ipairs(tileType) do
        modApi:appendAsset("img/combat/tiles_" .. type .. "/tile_lock.png",
            self.resourcePath .. "img/tile_lock/" .. type .. ".png")
        modApi:appendAsset("img/combat/tiles_" .. type .. "/tile_lock_friendunit.png",
            self.resourcePath .. "img/tile_lock/" .. type .. "_friendunit.png")
    end

    -- 设置图片的偏移
    Location["combat/icons/env_lock.png"] = Point(-27, 2)

    local weapons = {"Env_Weapon_1", "Env_Weapon_2", "Env_Weapon_3", "Env_Weapon_4"}
    for i, weapon in ipairs(weapons) do
        local name = Weapon_Texts[weapon .. "_Name"]
        self.shop:addWeapon({
            id = weapon,
            name = name,
            desc = string.format(EnvMod_Texts.add_to_shop, name)
        })
    end
end

function mod:load(options, version)
    self.environment:Load()
    self.env_passive:Load()
    self.weapons:Load()
    self.shop:load(options)
    modApi:addSquad({EnvMod_Texts.squad_name, "EnvMechPrime", "EnvMechRanged", "EnvMechScience"},
        EnvMod_Texts.squad_name, EnvMod_Texts.squad_description, self.resourcePath .. "img/icon.png")
end

return mod