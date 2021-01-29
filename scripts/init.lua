local mod = {
    id = "EnvManipulators",
    name = "EnvManipulators",
    version = "2.2.5.20210129",
    requirements = {"kf_ModUtils"},
    modApiVersion = "2.5.4",
    icon = "img/icon.png",
    author = "Compartany"
}
print(mod.version) -- for package and release

function mod:init()
    -- 简化操作的全局变量，仅适用于临时传递
    -- 某些状态需要退出游戏后固化到本地，可以存在 Mission 上
    ENV_GLOBAL = {
        weaponNames = {"EnvWeapon1", "EnvWeapon2", "EnvWeapon3", "EnvWeapon4"},
        envImageMarks = {"airstrike", "crack", "fireball", "hightide", "lava", "lightning", "rock", "snowstorm",
        "tentacle"},
        themeColor = GL_Color(196, 182, 86, 0)
    }

    self:initLibs()
    self:initResources()
    self:initScripts()
    self:initOptions()
end

-- 改变设置、继续游戏都会重新加载
function mod:load(options, version)
    self.lib.modApiExt:load(self, options, version)
    self.lib.shop:load(options)
    self.lib.trait:load()
    self:loadScripts()
    modApi:addSquad({EnvMod_Texts.squad_name, "EnvMechPrime", "EnvMechRanged", "EnvMechScience"},
        EnvMod_Texts.squad_name, EnvMod_Texts.squad_description, self.resourcePath .. "img/icon.png")
end

function mod:loadScripts()
    self.i18n:Load()
    self.tool:Load()
    self.animations:Load()
    self.pawns:Load()
    self.mechs:Load()
    self.weapons:Load()
    self.envArtificial:Load()
    self.environment:Load()
    self.missions:Load()
end

function mod:initLibs()
    env_modApiExt = require(self.scriptPath .. "modApiExt/modApiExt")
    env_modApiExt:init()
    self.lib = {}
    self.lib.modApiExt = env_modApiExt
    self.lib.palettes = require(self.scriptPath .. "libs/customPalettes")
    self.lib.shop = require(self.scriptPath .. "libs/shop")
    self.lib.trait = require(self.scriptPath .. "libs/trait")
end

function mod:initScripts()
    -- 加载的顺序很重要，不要乱调
    self.i18n = require(self.scriptPath .. "i18n")
    self.i18n:Init()
    self.tool = require(self.scriptPath .. "tool")
    self.animations = require(self.scriptPath .. "animations")
    self.pawns = require(self.scriptPath .. "pawns")
    self.mechs = require(self.scriptPath .. "mechs")
    self.weapons = require(self.scriptPath .. "weapons")
    self.envArtificial = require(self.scriptPath .. "envArtificial")
    self.environment = require(self.scriptPath .. "environment")
    self.missions = require(self.scriptPath .. "missions")
end

function mod:initOptions()
    local disabled = {
        EnvWeapon4 = true
    }
    for _, weapon in ipairs(ENV_GLOBAL.weaponNames) do
        local name = EnvWeapon_Texts[weapon .. "_Name"]
        self.lib.shop:addWeapon({
            id = weapon,
            name = name,
            desc = string.format(EnvMod_Texts.addToShop, name),
            default = disabled[weapon] and {
                enabled = false
            } or nil
        })
    end
end

function mod:initResources()
    for _, weapon in ipairs(ENV_GLOBAL.weaponNames) do
        local wpImg = weapon .. ".png"
        modApi:appendAsset("img/weapons/" .. wpImg, self.resourcePath .. "img/weapons/" .. wpImg)
    end
    modApi:appendAsset("img/combat/icons/env_lock.png", self.resourcePath .. "img/icons/env_lock.png")
    modApi:appendAsset("img/combat/icons/env_lock_dark.png", self.resourcePath .. "img/icons/env_lock_dark.png")
    modApi:appendAsset("img/combat/icons/env_lock_immune.png", self.resourcePath .. "img/icons/env_lock_immune.png")
    modApi:appendAsset("img/combat/icons/icon_envheavy.png", self.resourcePath .. "img/icons/icon_envheavy.png")
    modApi:appendAsset("img/combat/icons/icon_envheavy_glow.png",
        self.resourcePath .. "img/icons/icon_envheavy_glow.png")
    modApi:appendAsset("img/combat/icons/icon_env_rmdebuff1.png",
        self.resourcePath .. "img/icons/icon_env_rmdebuff1.png")
    modApi:appendAsset("img/combat/icons/icon_env_rmdebuff2.png",
        self.resourcePath .. "img/icons/icon_env_rmdebuff2.png")

    -- 需提供 U、R 两张图才能被平射使用
    modApi:appendAsset("img/effects/envShot_U.png", self.resourcePath .. "img/effects/envShot.png")
    modApi:appendAsset("img/effects/envShot_R.png", self.resourcePath .. "img/effects/envShot.png")
    modApi:appendAsset("img/effects/envArtificial_effect0.png",
        self.resourcePath .. "img/effects/envArtificial_effect0.png")
    modApi:appendAsset("img/effects/envArtificial_effect1.png",
        self.resourcePath .. "img/effects/envArtificial_effect1.png")
    modApi:appendAsset("img/effects/envExplo.png", self.resourcePath .. "img/effects/envExplo.png")

    modApi:appendAsset("img/combat/tile_icon/tile_artificial.png",
        self.resourcePath .. "img/environments/tile_artificial.png")

    -- 加到方格目录下，这样可以被 Board:SetCustomTile() 使用
    local tileTypes = {"grass", "sand", "snow", "acid", "volcano", "lava"}
    for _, type in ipairs(tileTypes) do
        modApi:appendAsset("img/combat/tiles_" .. type .. "/tile_lock.png",
            self.resourcePath .. "img/tile_lock/" .. type .. ".png")
        modApi:appendAsset("img/combat/tiles_" .. type .. "/tile_lock_immune.png",
            self.resourcePath .. "img/tile_lock/" .. type .. "_immune.png")
    end

    for _, mark in ipairs(ENV_GLOBAL.envImageMarks) do
        local f1 = "imagemark_" .. mark .. ".png"
        local f2 = "imagemark_immune_" .. mark .. ".png"
        modApi:appendAsset("img/combat/icons/" .. f1, self.resourcePath .. "img/environments/" .. f1)
        modApi:appendAsset("img/combat/icons/" .. f2, self.resourcePath .. "img/environments/" .. f2)
        Location["combat/icons/" .. f1] = Point(-27, 2)
        Location["combat/icons/" .. f2] = Point(-27, 2)
    end

    -- 设置图片偏移
    Location["combat/tile_icon/tile_artificial.png"] = Point(-27, 2)
    Location["combat/icons/env_lock.png"] = Point(-27, 2)
    Location["combat/icons/env_lock_dark.png"] = Point(-27, 2)
    Location["combat/icons/env_lock_immune.png"] = Point(-27, 2)
    Location["combat/icons/icon_envheavy.png"] = Point(-12, 8)
    Location["combat/icons/icon_env_rmdebuff1.png"] = Point(10, -7)
    Location["combat/icons/icon_env_rmdebuff2.png"] = Point(10, -7)

    self.lib.palettes.addPalette({
        ID = "envManipulators_palette",
        Name = "EnvManipulators",
        PlateHighlight = {76, 161, 255}, -- 高光    rgb(76, 161, 255)
        PlateLight = {196, 182, 86}, -- 主色        rgb(196, 182, 86)
        PlateMid = {96, 86, 32}, -- 主色阴影        rgb(96, 86, 32)
        PlateDark = {30, 29, 10}, -- 主色暗部       rgb(30, 29, 10)
        PlateOutline = {0, 0, 0}, -- 线条           rgb(0, 0, 0)
        PlateShadow = {28, 28, 28}, -- 副色暗部     rgb(28, 28, 28)
        BodyColor = {67, 72, 68}, -- 副色阴影       rgb(67, 72, 68)
        BodyHighlight = {159, 170, 153} -- 副色     rgb(159, 170, 153)
    })

    require(self.scriptPath .. "libs/FURL")(mod, {{
        Type = "mech",
        Name = "EnvMechPrime",
        Filename = "EnvMechPrime",
        Path = "img/mechs/prime",
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
        Name = "EnvMechRanged",
        Filename = "EnvMechRanged",
        Path = "img/mechs/ranged",
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
        Name = "EnvMechScience",
        Filename = "EnvMechScience",
        Path = "img/mechs/science",
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
