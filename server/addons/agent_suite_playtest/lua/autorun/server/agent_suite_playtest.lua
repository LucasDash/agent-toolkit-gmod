if not SERVER then return end

local configuredSteamID64 = string.Trim(file.Read("agent_suite_operator_steamid64.txt", "DATA") or "0")
if configuredSteamID64 ~= "0" and (#configuredSteamID64 ~= 17 or not configuredSteamID64:match("^%d+$")) then
    MsgN("[Agent Suite Playtest] Invalid local operator ID file; no operator grant configured.")
    configuredSteamID64 = "0"
end

local operatorSteamID64ConVar = CreateConVar(
    "agent_suite_operator_steamid64",
    configuredSteamID64,
    FCVAR_PROTECTED,
    "SteamID64 of the local playtest operator; set by the ignored collection data file."
)

if operatorSteamID64ConVar:GetString() ~= configuredSteamID64 then
    operatorSteamID64ConVar:SetString(configuredSteamID64)
    MsgN("[Agent Suite Playtest] Synchronized the operator setting from the local data file.")
end

-- The server collection mounts the model for the server; this also requests the
-- model and materials from Workshop for clients joining the playtest.
resource.AddWorkshop("3845592300")
MsgN("[Agent Suite Playtest] Registered Veejay Workshop content for client downloads.")
MsgN(configuredSteamID64 ~= "0"
    and "[Agent Suite Playtest] Local operator access is configured."
    or "[Agent Suite Playtest] No local operator account is configured.")

local function grantOperator(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    local targetSteamID64 = configuredSteamID64
    if targetSteamID64 == "0" or targetSteamID64 == "" then return false end
    if ply:SteamID64() ~= targetSteamID64 then return false end
    if not ULib or not ULib.ucl or not ULib.ucl.addUser then
        MsgN("[Agent Suite Playtest] ULib UCL is unavailable; local operator grant was not applied.")
        return false
    end

    if ply:GetUserGroup() == "superadmin" and ply:IsAdmin() then
        MsgN("[Agent Suite Playtest] Configured local operator is already ULX superadmin.")
        return true
    end

    local ucl = ULib.ucl
    local id = ucl.getUserRegisteredID and ucl.getUserRegisteredID(ply) or nil
    if not id or id == "" then id = ply:SteamID() end
    local existingUser = (ucl.authed and ucl.authed[ply:UniqueID()]) or ucl.users[id] or {}

    local ok, err = pcall(
        ucl.addUser,
        id,
        existingUser.allow or {},
        existingUser.deny or {},
        "superadmin"
    )
    if not ok then
        MsgN("[Agent Suite Playtest] ULib rejected the configured operator grant: " .. tostring(err))
        return false
    end

    if ply:GetUserGroup() ~= "superadmin" or not ply:IsAdmin() then
        MsgN("[Agent Suite Playtest] ULib saved the operator grant but did not apply superadmin access to the live player.")
        return false
    end

    MsgN("[Agent Suite Playtest] Configured local operator granted ULX superadmin access.")
    return true
end

local uclAuthHook = ULib and ULib.HOOK_UCLAUTH
if not uclAuthHook then
    MsgN("[Agent Suite Playtest] ULib UCL authentication hook is unavailable; automatic operator grant is disabled.")
    return
end

local pendingOperatorGrants = setmetatable({}, { __mode = "k" })
hook.Remove("PlayerInitialSpawn", "AgentSuite.Playtest.Operator")
hook.Remove("PlayerAuthed", "AgentSuite.Playtest.Operator")
hook.Remove(uclAuthHook, "AgentSuite.Playtest.Operator")
local function scheduleOperatorGrant(ply, authSource)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local targetSteamID64 = configuredSteamID64
    if targetSteamID64 == "0" or targetSteamID64 == "" then return end
    if pendingOperatorGrants[ply] then return end

    pendingOperatorGrants[ply] = true
    local attempts = 0
    local function waitForSteamAuthentication()
        if not IsValid(ply) then
            pendingOperatorGrants[ply] = nil
            return
        end

        local fullyAuthenticated = ply.IsFullyAuthenticated and ply:IsFullyAuthenticated()
        if not fullyAuthenticated then
            attempts = attempts + 1
            if attempts < 40 then
                timer.Simple(0.25, waitForSteamAuthentication)
            else
                if ply:SteamID64() == targetSteamID64 then
                    MsgN("[Agent Suite Playtest] Configured local operator did not reach full Steam authentication; no grant was applied.")
                end
                pendingOperatorGrants[ply] = nil
            end
            return
        end

        if ply:SteamID64() == targetSteamID64 then
            MsgN("[Agent Suite Playtest] Configured local operator reached full Steam authentication via " .. authSource .. ".")
            grantOperator(ply)
        end
        pendingOperatorGrants[ply] = nil
    end

    timer.Simple(0, waitForSteamAuthentication)
end

hook.Add("PlayerInitialSpawn", "AgentSuite.Playtest.Operator", function(ply)
    scheduleOperatorGrant(ply, "initial spawn")
end)
hook.Add("PlayerAuthed", "AgentSuite.Playtest.Operator", function(ply)
    scheduleOperatorGrant(ply, "engine authentication")
end)
hook.Add(uclAuthHook, "AgentSuite.Playtest.Operator", function(ply)
    scheduleOperatorGrant(ply, "ULib UCL authentication")
end)
MsgN("[Agent Suite Playtest] Engine and ULib operator grant hooks are ready.")
hook.Remove("PlayerDisconnected", "AgentSuite.Playtest.OperatorCleanup")
hook.Add("PlayerDisconnected", "AgentSuite.Playtest.OperatorCleanup", function(ply)
    pendingOperatorGrants[ply] = nil
end)

-- Also cover an authenticated operator already connected when this addon reloads.
for _, ply in ipairs(player.GetAll()) do
    scheduleOperatorGrant(ply, "hot reload")
end
