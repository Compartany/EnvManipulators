local mod = mod_loader.mods[modApi.currentMod]
local scriptPath = mod.scriptPath

local this = {
    FirstLoad = true
}

local _modApi_loadLanguage = modApi.loadLanguage
function modApi:loadLanguage(languageIndex, ...)
    if this.FirstLoad then
        this.FirstLoad = false
        return _modApi_loadLanguage(self, languageIndex, ...)
    else
        this:LoadText(languageIndex)
        local ret = _modApi_loadLanguage(self, languageIndex, ...)
        this:SetText()
        return ret
    end
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
    this:SetText()
end

function this:Load()
    -- nothing to do
end

return this
