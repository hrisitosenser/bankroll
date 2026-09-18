-- Bankroll full UI preview
-- Put this LocalScript next to Bankroll.lua (or change the require path) in
-- StarterPlayerScripts to preview every control from the original menu.

local module = script.Parent:FindFirstChild("Bankroll")
    or game:GetService("ReplicatedStorage"):WaitForChild("Bankroll")
local Bankroll = require(module)

local library = Bankroll.new()
local window = library:CreateWindow({
    Title = "bankroll mafia",
    ToggleKey = Enum.KeyCode.Insert,
    Accent = Color3.fromRGB(188, 130, 187),
    Name = "BankrollDemo",
})

local function c(r, g, b)
    return Color3.fromRGB(r, g, b)
end

-- aim -----------------------------------------------------------------------
local aim = window:CreateTab({ Name = "aim" })
local weaponGroup = aim:CreateGroupbox({ Name = "weapon group", Side = "Left" })
weaponGroup:AddDropdown("weapon", {
    Values = { "shared", "pistols", "rifles", "snipers", "smg" },
    Default = 1,
    Flag = "weapon_sel",
})
weaponGroup:AddToggle("override shared", { Default = false, Flag = "override_shared" })
weaponGroup:AddSeparator("general")
weaponGroup:AddToggle("aimbot", {
    Default = true,
    Keybind = "M1",
    Flag = "aimbot",
})
weaponGroup:AddDropdown("hitbox", {
    Values = { "head", "neck", "chest", "stomach", "pelvis" },
    Default = 1,
    Flag = "hitbox_sel",
})
weaponGroup:AddToggle("backtrack", { Default = false, Flag = "backtrack" })
weaponGroup:AddToggle("triggerbot", {
    Default = false,
    Keybind = "ALT",
    Flag = "triggerbot",
})
weaponGroup:AddDropdown("hitgroup", {
    Values = { "head, chest...", "head only", "all", "chest, arms" },
    Default = 1,
    Flag = "hitgroup_sel",
})
weaponGroup:AddToggle("magnet", { Default = false, Flag = "magnet" })
weaponGroup:AddToggle("penetration", {
    Default = false,
    Keybind = "ALT",
    Flag = "penetration",
})

local aimbotParams = aim:CreateGroupbox({ Name = "aimbot params", Side = "Right" })
aimbotParams:AddToggle("silent", { Default = false, Flag = "silent" })
aimbotParams:AddSlider("field of view", {
    Min = 0, Max = 180, Default = 90, Format = "%.1f", Flag = "fov",
})
aimbotParams:AddSlider("smooth", {
    Min = 0, Max = 100, Default = 0, Suffix = "%", Format = "%.0f", Flag = "smooth",
})
aimbotParams:AddToggle("recoil control", { Default = false, Flag = "recoil_ctrl" })

local triggerParams = aim:CreateGroupbox({ Name = "triggerbot params", Side = "Right" })
triggerParams:AddToggle("seed prediction", { Default = false, Flag = "seed_pred" })
triggerParams:AddSlider("delay", {
    Min = 0, Max = 500, Default = 0, Suffix = "ms", Format = "%.0f", Flag = "delay",
})
triggerParams:AddSlider("hitchance", {
    Min = 0, Max = 100, Default = 0, Suffix = "%", Format = "%.0f", Flag = "hitchance",
})

-- visuals -------------------------------------------------------------------
local visuals = window:CreateTab({ Name = "visuals" })
local enemy = visuals:AddSubTab("enemy")
local friendly = visuals:AddSubTab("friendly")
local world = visuals:AddSubTab("world")
local extra = visuals:AddSubTab("extra")

local enemyEsp = enemy:CreateGroupbox({ Name = "enemy esp", Side = "Left" })
enemyEsp:AddToggle("box", {
    Default = true,
    Colors = { c(255, 255, 255) },
    Flag = "box",
})
enemyEsp:AddToggle("health", {
    Default = true,
    Colors = { c(255, 102, 179), c(255, 255, 255) },
    Flag = "health",
})
enemyEsp:AddToggle("name", {
    Default = true,
    Colors = { c(255, 255, 255) },
    Flag = "name",
})
enemyEsp:AddToggle("weapon", {
    Default = true,
    Colors = { c(255, 255, 255) },
    Flag = "weapon",
})
enemyEsp:AddToggle("ammo", {
    Default = false,
    Colors = { c(255, 102, 179), c(255, 255, 255) },
    Flag = "ammo",
})
enemyEsp:AddToggle("out of view indicator", {
    Default = false,
    Colors = { c(77, 128, 255) },
    Flag = "out_of_view",
})
enemyEsp:AddToggle("skeleton", {
    Default = false,
    Colors = { c(255, 255, 255) },
    Flag = "skeleton",
})
enemyEsp:AddToggle("flags", {
    Default = false,
    Colors = { c(255, 255, 255), c(255, 255, 255), c(255, 255, 255) },
    Flag = "flags_esp",
})

local chams = enemy:CreateGroupbox({ Name = "enemy chams", Side = "Right" })
chams:AddToggle("visible", {
    Default = false,
    Colors = { c(255, 255, 255) },
    Flag = "visible",
})
chams:AddToggle("occluded", {
    Default = false,
    Colors = { c(255, 255, 255) },
    Flag = "occluded",
})
chams:AddToggle("history", { Default = false, Flag = "history" })
chams:AddToggle("glow", {
    Default = false,
    Colors = { c(217, 26, 26), c(217, 26, 26) },
    Flag = "glow",
})

-- Keep the three empty sections from the source menu available as real tab
-- pages. They are intentionally blank in the ImGui reference as well.
friendly:CreateGroupbox({ Name = "friendly", Side = "Left" })
world:CreateGroupbox({ Name = "world", Side = "Left" })
extra:CreateGroupbox({ Name = "extra", Side = "Left" })

-- misc ----------------------------------------------------------------------
local misc = window:CreateTab({ Name = "misc" })
local movement = misc:CreateGroupbox({ Name = "movement", Side = "Left" })
movement:AddToggle("edge jump", { Keybind = "disabled", Flag = "edge_jump" })
movement:AddToggle("ladder edge jump", { Keybind = "disabled", Flag = "ladder_edge_jump" })
movement:AddToggle("long jump", { Keybind = "disabled", Flag = "long_jump" })
movement:AddToggle("long jump on edge", { Default = true, Keybind = "M3", Flag = "long_jump_edge" })
movement:AddToggle("mini jump", { Keybind = "M3", Flag = "mini_jump" })
movement:AddToggle("null strafe", { Default = true, Keybind = "always on", Flag = "null_strafe" })
movement:AddToggle("mousespeed limiter", { Keybind = "none", Flag = "mousespeed_lim" })

local miscellaneous = misc:CreateGroupbox({ Name = "miscellaneous", Side = "Left" })
miscellaneous:AddToggle("chat logs", { Default = true, Flag = "chat_logs" })
miscellaneous:AddDropdown("chat log type", {
    Values = { "edgebug", "killfeed", "both" },
    Default = 1,
    Flag = "chat_logs_type",
})
miscellaneous:AddToggle("healthshot", { Flag = "healthshot" })
miscellaneous:AddToggle("sounds", { Default = true, Flag = "sounds" })
miscellaneous:AddDropdown("sound type", {
    Values = { "hit", "kill", "hurt" },
    Default = 1,
    Flag = "sounds_type",
})
miscellaneous:AddSlider("volume", {
    Min = 0, Max = 100, Default = 30, Format = "%.0f", Flag = "sounds_volume",
})

local indicators = misc:CreateGroupbox({ Name = "indicators", Side = "Right" })
indicators:AddSlider("offset", {
    Min = 0, Max = 200, Default = 67, Format = "%.0f", Flag = "ind_offset",
})
indicators:AddToggle("keybinds", {
    Colors = { c(51, 217, 51), c(255, 255, 255) },
    Flag = "ind_keybinds",
})
indicators:AddToggle("velocity text", {
    Colors = { c(230, 89, 102), c(255, 179, 51), c(51, 217, 51) },
    Flag = "vel_text",
})
indicators:AddToggle("keystrokes", {
    Colors = { c(255, 255, 255) },
    Flag = "keystrokes",
})
indicators:AddToggle("velocity graph", {
    Colors = { c(255, 255, 255), c(255, 255, 255) },
    Flag = "vel_graph",
})

-- config --------------------------------------------------------------------
local config = window:CreateTab({ Name = "config" })
local menu = config:CreateGroupbox({ Name = "menu", Side = "Left" })
menu:AddToggle("toggle menu", { Keybind = "INS", Flag = "toggle_menu" })
menu:AddColorPicker("menu color", {
    Default = c(175, 100, 200),
    Flag = "menu_color",
    Callback = function(color)
        window:SetAccent(color)
    end,
})
config:CreateConfigPanel({ Name = "configs", Side = "Right" })

-- skins and lua are intentionally empty reference tabs, but are created so
-- callers can add their own groupboxes without changing the layout API.
window:CreateTab({ Name = "skins" })
window:CreateTab({ Name = "lua" })

-- Keep the reference's initial tab active after all tabs have been registered.
window:SelectTab("aim")
