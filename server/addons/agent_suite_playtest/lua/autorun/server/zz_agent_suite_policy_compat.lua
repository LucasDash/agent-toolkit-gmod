if not SERVER then return end

local function isConfiguredOperator(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    local operator = GetConVar("agent_suite_operator_steamid64")
    if not operator then return false end
    local steamID64 = operator:GetString()
    return steamID64 ~= "" and steamID64 ~= "0" and ply:SteamID64() == steamID64
end

local function restrictedPlayer(ply)
    local policy = GetConVar("agent_bridge_lab_policy")
    return policy and policy:GetBool()
        and IsValid(ply)
        and ply:IsPlayer()
        and not ply:IsAdmin()
        and not isConfiguredOperator(ply)
end

-- Rebind Agent Bridge's hook IDs as a local compatibility layer for the
-- pinned server image; keep the configured-operator exception in this addon.
local function applyPolicyCompatibility()
    local function ordinaryUser(ply)
        if restrictedPlayer(ply) and ply:GetUserGroup() ~= "user" then
            ply:SetUserGroup("user")
        end
    end
    hook.Add("PlayerInitialSpawn", "AgentBridge.LabPolicy.User", ordinaryUser)
    hook.Add("PlayerSpawn", "AgentBridge.LabPolicy.User", ordinaryUser)
    hook.Add("PlayerLoadout", "AgentBridge.LabPolicy.Loadout", function(ply)
        if not restrictedPlayer(ply) then return end
        ply:StripWeapons()
        ply:RemoveAllAmmo()
        ply:Give("weapon_fists")
        ply:Give("gmod_camera")
        ply:SelectWeapon("weapon_fists")
        return true
    end)

    for _, event in ipairs({
        "PlayerSpawnProp", "PlayerSpawnRagdoll", "PlayerSpawnEffect", "PlayerSpawnNPC",
        "PlayerSpawnSENT", "PlayerSpawnVehicle", "PlayerSpawnSWEP", "PlayerGiveSWEP",
        "CanTool", "CanProperty"
    }) do
        hook.Add(event, "AgentBridge.LabPolicy.Restrict", function(ply)
            if restrictedPlayer(ply) then return false end
        end)
    end

    hook.Add("PlayerNoClip", "AgentBridge.LabPolicy.NoClip", function(ply, desiredState)
        if not restrictedPlayer(ply) then return end
        if desiredState then return false end
        return true
    end)
end

hook.Add("Initialize", "AgentSuite.Playtest.PolicyCompatibility", applyPolicyCompatibility)
timer.Simple(0, applyPolicyCompatibility)
MsgN("[Agent Suite Playtest] Agent Bridge lab policy compatibility is ready.")
