if not SERVER then return end

local ok, err = pcall(require, "gterm")
if not ok then
    ErrorNoHalt("[Agent Toolkit] GTerm module unavailable: " .. tostring(err) .. "\n")
    return
end

print("[Agent Toolkit] GTerm server module loaded.")
