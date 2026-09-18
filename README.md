# Bankroll for Roblox Studio

`src/Bankroll.lua` is a dependency-free Luau UI library that ports the supplied
bankroll ImGui menu to Roblox Studio. It is a UI/configuration library only: it
contains no gameplay automation, no exploit code and no filesystem calls, and
the module itself never makes network requests.

`src/BankrollLoader.lua` is an optional, separate bootstrap script for the
`loadstring(game:HttpGet(...))()` workflow. It performs one read-only HTTP GET
for `src/Bankroll.lua`, compiles the answer with `loadstring` and returns the
same module table, so the public API is identical with and without it. If you
use `require`, you can ignore or delete that file.

The reference geometry is kept deliberately small and fixed:

- window: `448 x 446` pixels (`420` content + `26` tab bar);
- title bar: `22` pixels;
- left/right columns: `200` / `214` pixels with a `14` pixel gap;
- the original dark palette, section borders, gradients, compact checkboxes,
  sliders, dropdowns, color picker and keybind treatment;
- tabs: `aim`, `visuals`, `skins`, `misc`, `config`, `lua`;
- the preview script includes every control present in the supplied C++ menu.

## Two ways to load it

Both options below end up with the exact same table, so every snippet in this
README works unchanged with either one.

| | Option 1: `require` | Option 2: remote loader |
| --- | --- | --- |
| Where | Roblox Studio, Rojo, published places | executor / `loadstring` environments |
| Needs `loadstring` | no | yes |
| Needs HTTP | no | yes |
| Files to copy | `src/Bankroll.lua` | nothing |

### Option 1 - Roblox Studio with `require`

1. Create a `ModuleScript` named `Bankroll` in `ReplicatedStorage` and paste
   `src/Bankroll.lua` into it.
2. Create a `LocalScript` in `StarterPlayerScripts` and paste
   `src/BankrollDemo.client.lua` next to it, or update the `require` path.
3. Press Play. `Insert` toggles the window. The demo is intentionally a
   LocalScript because Roblox does not permit a server script to own a player's
   `PlayerGui`.

```lua
local Bankroll = require(game.ReplicatedStorage.Bankroll)

local library = Bankroll.new()
local window = library:CreateWindow({ Title = "bankroll mafia" })
```

The included `default.project.json` also maps the module (and the loader) to
`ReplicatedStorage` and the demo to `StarterPlayerScripts` for Rojo users.

### Option 2 - remote loader with `game:HttpGet` and `loadstring`

Paste a single line into your executor (or any environment that provides
`game:HttpGet` and `loadstring`):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hrisitosenser/bankroll/main/src/BankrollLoader.lua"))()
```

`BankrollLoader.AutoLoad` is `true`, so that line already downloaded the
library. The loader table forwards everything the library exposes, which keeps
the usage identical to `require`:

```lua
local Bankroll = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/hrisitosenser/bankroll/main/src/BankrollLoader.lua"
))()

local library = Bankroll.new()
local window = library:CreateWindow({
    Title = "bankroll mafia",
    ToggleKey = Enum.KeyCode.Insert,
})

window:CreateTab({ Name = "aim" }):CreateGroupbox({ Name = "weapon group" })
    :AddToggle("aimbot", { Default = true, Keybind = "M1", Flag = "aimbot" })
```

You can also point the loader at different sources, control when the download
happens, or skip the loader and fetch the library file directly:

```lua
local LOADER_URL = "https://raw.githubusercontent.com/hrisitosenser/bankroll/main/src/BankrollLoader.lua"

-- a) explicit loading / a pinned commit instead of a branch
local BankrollLoader = loadstring(game:HttpGet(LOADER_URL))()
BankrollLoader.Quiet = true
local Bankroll = BankrollLoader.Load({
    Url = "https://raw.githubusercontent.com/hrisitosenser/bankroll/<commit>/src/Bankroll.lua",
})

-- b) describe the environment before trying (handy for bug reports)
print(BankrollLoader.IsSupported())
print(BankrollLoader.GetEnvironment().FetchClients) -- e.g. { "game:HttpGet" }

-- c) no loader at all: the library file is a plain Luau chunk
local Bankroll = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/hrisitosenser/bankroll/main/src/Bankroll.lua"
))()
```

How the loader works:

1. `Loader.Mirrors` lists four URLs for `src/Bankroll.lua` - `raw.githubusercontent.com`,
   the jsDelivr CDN, `github.com/.../raw` and raw.githack.com. They are tried in
   order, so a blocked or rate limited host does not break the script.
2. The first response that is not an error is checked: empty bodies, UTF-8 BOMs
   and HTML error pages are rejected with a readable message.
3. The source is compiled with `loadstring` and executed; the resulting table is
   verified (`Bankroll.new` must exist) before it is cached and returned.
4. `Loader.Load()` caches the module, so calling it again is free.
   `Loader.ClearCache()` forces a new download, `Loader.Load({ Force = true })`
   does the same on a single call.

Remote load prerequisites and limits:

- `loadstring` is required. In stock Roblox it only exists on the server when
  `LoadStringEnabled` is on; plain Studio clients have neither `loadstring` nor
  `game:HttpGet`, so use `require` there. `Loader.IsSupported()` tells you what
  the current environment supports.
- HTTP clients are probed in this order: `game:HttpGet`, `game:HttpGetAsync`,
  a global `HttpGet`, `request`, `http_request`, `syn.request`, and finally
  `HttpService:GetAsync` on the server when HTTP requests are enabled.
- `request` / `syn.request` return a table, so the loader reads `Body` / `Data`
  and treats `Status` >= 400 as a failure.
- Only `src/Bankroll.lua` from this repository is fetched. Point the loader only
  at sources you trust: it compiles and runs what the URL returns. For anything
  beyond personal/dev use, pin a commit hash instead of `main`.
- Using a script executor is against the Roblox Terms of Use and gets accounts
  banned; that risk is entirely on the caller.

If `Loader.Load()` fails it raises an error listing every URL and every reason
(`fetch:`, `compile:`, `run:`, or a version mismatch). Pass `NoThrow = true` -
or use `Loader.TryLoad()` - to receive `nil, message` instead.

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

### Remote loader

`src/BankrollLoader.lua` returns the loader table:

- `Loader.AutoLoad` (default `true`) - fetch the library as soon as the chunk
  runs; set it to `false` before loading to call `Load()` yourself.
- `Loader.Quiet`, `Loader.Verbose` (default `false`) - silence the informational
  prints, or also report why auto-load was skipped.
- `Loader.Repository`, `Loader.Tag`, `Loader.Path`, `Loader.Mirrors`,
  `Loader.Url` - where the library is fetched from.
- `Loader.Load({Url, Mirrors, Tag, Path, Repository, Fallback, ChunkName, RequiredVersion, Force, Quiet, NoThrow})`
  - returns the module table (cached).
- `Loader.TryLoad(options)` - `{Ok = true, Module = ...}` or `{Ok = false, Error = ...}`.
- `Loader.Fetch(url)` - raw GET, returns the body or `nil, reason`.
- `Loader.Compile(source, chunkName)` - returns a chunk or `nil, reason`.
- `Loader.GetEnvironment()` - `{FetchClients, Compilers, CanFetch, CanCompile, Supported, IsServer, Notes}`.
- `Loader.IsSupported()` - `true`, or `false, reason`.
- `Loader.BuildUrls(tag, path, repository)`, `Loader.ResolveUrls(options)` - URL helpers.
- `Loader.GetModule()`, `Loader.GetSource()`, `Loader.ClearCache()`.
- `Loader.LastUrl`, `Loader.LastError` - diagnostics for the last attempt.
- calling the loader table (`Loader(options)`) is the same as `Loader.Load(options)`.

Before the first successful load, `Loader.new` is not defined, so touching a
library field on the loader raises an error that points at `Loader.Load()`;
afterwards every field is forwarded to the module table.
