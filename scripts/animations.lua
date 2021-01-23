ANIMS.EnvArtificial_Animation0 = ANIMS.Animation:new{
    Image = "effects/envArtificial_effect0.png",
    NumFrames = 1,
    Time = 0.45,
    PosX = -26,
    PosY = -55,
    Loop = false
}

ANIMS.EnvArtificial_Animation1 = ANIMS.EnvArtificial_Animation0:new{
    Image = "effects/envArtificial_effect1.png"
}

ANIMS.EnvExplo = ANIMS.Animation:new{
    Image = "effects/envExplo.png",
    NumFrames = 8,
    Time = 0.05,
    PosX = -33,
    PosY = -14
}

local this = {}

function this:Load()
    -- nothing to do
end

return this
