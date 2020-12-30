EnvMechPrime = Pawn:new{
    Name = EnvMod_Texts.mech_prime_name,
    Class = "Prime",
    Health = 4,
    MoveSpeed = 4,
    Image = "mech_env_prime",
    ImageOffset = FURL_COLORS.EnvManipulatorsColors,
    SkillList = {"Env_Weapon_1"},
    SoundLocation = "/mech/prime/rock_mech/",
    DefaultTeam = TEAM_PLAYER,
    ImpactMaterial = IMPACT_METAL,
    Massive = true
}

EnvMechRanged = Pawn:new{
    Name = EnvMod_Texts.mech_ranged_name,
    Class = "Ranged",
    Health = 3,
    MoveSpeed = 3,
    Image = "mech_env_ranged",
    ImageOffset = FURL_COLORS.EnvManipulatorsColors,
    SkillList = {"Env_Weapon_2", "Env_Weapon_4"},
    SoundLocation = "/mech/distance/dstrike_mech/",
    DefaultTeam = TEAM_PLAYER,
    ImpactMaterial = IMPACT_METAL,
    Massive = true
}

EnvMechScience = Pawn:new{
    Name = EnvMod_Texts.mech_science_name,
    Class = "Science",
    Health = 2,
    MoveSpeed = 4,
    Image = "mech_env_science",
    ImageOffset = FURL_COLORS.EnvManipulatorsColors,
    SkillList = {"Env_Weapon_3"},
    SoundLocation = "/mech/science/science_mech/",
    DefaultTeam = TEAM_PLAYER,
    ImpactMaterial = IMPACT_METAL,
    Massive = true,
    Flying = true
}
