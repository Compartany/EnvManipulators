local mod = mod_loader.mods[modApi.currentMod]
local scriptPath = mod.scriptPath

local this = {
    FirstLoad = true
}

local _modApi_loadLanguage = modApi.loadLanguage
function modApi:loadLanguage(languageIndex, ...)
    -- 尽管首次加载语言时会重复在 Init() 中执行的代码，但这里必须得重复执行，否则其他 MOD 也采用这种方式加载文本时会出错
    this:LoadText(languageIndex)
    local ret = _modApi_loadLanguage(self, languageIndex, ...)
    this:SetText()
    return ret
end

function this:LoadText(language)
    language = language or modApi:getLanguageIndex()
    local langPath = nil
    if language == Languages.Chinese_Simplified then
        langPath = scriptPath .. "localization/chinese/"
    else
        langPath = scriptPath .. "localization/english/"
    end
    EnvMod_Texts = require(langPath .. "EnvMod_Texts")
    EnvWeapon_Texts = require(langPath .. "EnvWeapon_Texts")
    Env_Texts = require(scriptPath .. "localization/Env_Texts")

    TILE_TOOLTIPS.artificial0 = {EnvWeapon_Texts.EnvWeapon4_Name .. " - " .. EnvWeapon_Texts.EnvWeapon4_Upgrade1,
                              EnvWeapon_Texts.EnvWeapon4_A_UpgradeDescription}
    for damage = 1, 6 do -- 为了方便修改，还是将伤害从 1 到 6 全弄出 tooltip 来
        TILE_TOOLTIPS["artificial" .. damage] = {EnvMod_Texts.envArtificial_name,
                                              string.format(EnvMod_Texts.envArtificial_template_description, damage)}
    end
end

function this:SetText()
    for id, text in pairs(EnvWeapon_Texts) do
        modApi:setText(id, text)
    end
    for id, text in pairs(Env_Texts) do
        modApi:setText(id, text)
    end
end

function this:Init()
    this:LoadText()
end

function this:Load()
    -- nothing to do
end

return this
