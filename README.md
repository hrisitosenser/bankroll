# Bankroll for Roblox Studio

`src/Bankroll.lua` is a dependency-free Luau UI library that ports the supplied
bankroll ImGui menu to Roblox Studio. It is a UI/configuration library only: it
does not contain gameplay automation, exploit code, HTTP loaders, or filesystem
calls.

The reference geometry is kept deliberately small and fixed:

- window: `448 x 446` pixels (`420` content + `26` tab bar);
- title bar: `22` pixels;
- left/right columns: `200` / `214` pixels with a `14` pixel gap;
- the original dark palette, section borders, gradients, compact checkboxes,
  sliders, dropdowns, color picker and keybind treatment;
- tabs: `aim`, `visuals`, `skins`, `misc`, `config`, `lua`;
- the preview script includes every control present in the supplied C++ menu.

## Studio setup

1. Create a `ModuleScript` named `Bankroll` in `ReplicatedStorage` and paste
   `src/Bankroll.lua` into it.
2. Create a `LocalScript` in `StarterPlayerScripts` and paste
   `src/BankrollDemo.client.lua` next to it, or update the `require` path.
3. Press Play. `Insert` toggles the window. The demo is intentionally a
   LocalScript because Roblox does not permit a server script to own a player's
   `PlayerGui`.

The included `default.project.json` also maps the module to `ReplicatedStorage`
and the demo to `StarterPlayerScripts` for Rojo users.

## Small API example

```lua
local Bankroll = require(game.ReplicatedStorage.Bankroll)
local library = Bankroll.new()
local window = library:CreateWindow({
    Title = "bankroll mafia",
    ToggleKey = Enum.KeyCode.Insert,
})

local tab = window:CreateTab({ Name = "aim" })
local box = tab:CreateGroupbox({ Name = "weapon group", Side = "Left" })

local enabled = box:AddToggle("aimbot", {
    Default = true,
    Keybind = "M1",
    Flag = "aimbot",
    Callback = function(value)
        print("aimbot UI value:", value)
    end,
})

local fov = box:AddSlider("field of view", {
    Min = 0,
    Max = 180,
    Default = 90,
    Format = "%.1f",
    Callback = function(value)
        print("fov UI value:", value)
    end,
})

box:AddDropdown("hitbox", {
    Values = { "head", "neck", "chest", "stomach", "pelvis" },
    Default = 1,
})

box:AddButton("reset", function()
    enabled:SetValue(false)
    fov:SetValue(90)
end)
```

## Public surface

### Library and window

- `Bankroll.new(options)`
- `library:CreateWindow(options)`
- `window:CreateTab({Name = "aim"})` / `window:AddTab(...)`
- `window:SelectTab("aim")`, `window:GetTab("aim")`
- `window:SetAccent(Color3)`, `window:SetVisible(bool)`, `window:Toggle()`
- `window:Notify({Title = "...", Content = "..."})`
- `window:Destroy()`

`window.OnChanged` and `window.OnVisibilityChanged` are lightweight signals.

### Groupboxes and controls

`tab:CreateGroupbox({Name = "...", Side = "Left" or "Right"})` returns a
section with:

- `AddToggle(label, {Default, Keybind, Colors, Flag, Callback})`
- `AddSlider(label, {Min, Max, Default, Suffix, Format, Flag, Callback})`
- `AddDropdown(label, {Values, Default, Flag, Callback})`
- `AddColorPicker(label, {Default, Alpha, Flag, Callback})`
- `AddInput(label, {Default, Placeholder, Flag, Callback})`
- `AddKeybind(label, {Default, Flag, Callback})`
- `AddButton(label, callback)`
- `AddSeparator(label)`

Control objects expose `Changed`, `GetValue`, `SetValue`, `Export`, and
`Import` where applicable. A toggle's `Colors` option accepts one or more
`Color3` values, and each swatch opens the 220 x 220 HSV/alpha picker. A
slider supports mouse dragging and the `-` / `+` 1% step buttons. Keybinds can
be clicked and then assigned by pressing a keyboard key or mouse button;
`Escape` cancels capture. The toggle key is also handled globally when the
window is visible.

Visuals can use the same subtab structure as the source menu:

```lua
local visuals = window:CreateTab({Name = "visuals"})
local enemy = visuals:AddSubTab("enemy")
local esp = enemy:CreateGroupbox({Name = "enemy esp", Side = "Left"})
esp:AddToggle("box", {Default = true, Colors = {Color3.new(1, 1, 1)}})
```

### Configs

`tab:CreateConfigPanel({Name = "configs", Side = "Right"})` creates the same
list, input, `create`, `save`, `load`, and `open directory` controls as the
reference. A config is made from controls with `Flag`s and is stored in memory
by default for the current play session:

```lua
window.Configs:Create("legit")
window.Configs:Save("legit")
window.Configs:Load("legit")
print(window.Configs:List())
```

Normal Roblox games cannot access a local filesystem, so `open directory`
shows a notice unless an adapter is supplied. For persistence, pass an adapter
when creating a window:

```lua
local data = {}
local window = library:CreateWindow({
    Persistence = {
        List = function() return {"default"} end,
        Save = function(name, snapshot) data[name] = snapshot end,
        Load = function(name) return data[name] end,
        OpenDirectory = function() print("Use your own Studio/DataStore UI") end,
    },
})
```

The adapter receives plain Luau tables. If persistence crosses the client /
server boundary, validate the data and use a server-side DataStore instead of
trusting client input.
