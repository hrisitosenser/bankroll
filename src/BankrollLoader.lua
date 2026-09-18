--!nocheck
-- BankrollLoader
-- Remote bootstrap for the Bankroll UI library (src/Bankroll.lua).
--
-- There are two supported ways to use Bankroll, and both end up with the very
-- same module table, so the public API is identical:
--
--   1) Studio / Rojo
--        local Bankroll = require(game.ReplicatedStorage.Bankroll)
--
--   2) Remote loader (single line, nothing to install)
--        local Bankroll = loadstring(game:HttpGet(
--            "https://raw.githubusercontent.com/hrisitosenser/bankroll/main/src/BankrollLoader.lua"
--        ))()
--        local library = Bankroll.new()
--
-- This file only does plumbing: it performs one read-only GET request for
-- src/Bankroll.lua, compiles the response with loadstring and returns the
-- module. It never runs gameplay code, never sends data anywhere and never
-- touches the file system.
--
-- Requirements for the remote variant: an environment that exposes an HTTP
-- client (`game:HttpGet` and friends, or a server script with HttpService
-- enabled) and a compiler (`loadstring`, which needs LoadStringEnabled on the
-- server). Plain Roblox Studio clients have neither - use `require` there.

local Loader = {}

Loader.Version = "1.0.0"
Loader.Repository = "hrisitosenser/bankroll"
Loader.Tag = "main"
Loader.Path = "src/Bankroll.lua"
Loader.ChunkName = "BankrollRemote"

-- When the chunk is executed straight from loadstring the library is fetched
-- immediately, so `Bankroll.new()` works right away. Set to false if you want
-- to call Loader.Load() yourself first.
Loader.AutoLoad = true

-- Set to true to silence the informational print statements.
Loader.Quiet = false

-- Set to true to also print why auto-load was skipped.
Loader.Verbose = false

-- Last failure message produced by Loader.Load (nil after a success).
Loader.LastError = nil
-- URL that actually served the library.
Loader.LastUrl = nil

--------------------------------------------------------------------------------
-- small helpers
--------------------------------------------------------------------------------

local function typeName(value)
    if typeof ~= nil then
        return typeof(value)
    end
    return type(value)
end

local function truncate(text, limit)
    text = tostring(text)
    limit = limit or 160
    if #text <= limit then
        return text
    end
    return text:sub(1, limit) .. "..."
end

-- Instance member access throws for unknown members ("X is not a valid member
-- of Y"), and executor globals are not guaranteed to exist, so never index
-- anything without a pcall here.
local function safeIndex(object, key)
    if object == nil then
        return nil
    end
    local ok, value = pcall(function()
        return object[key]
    end)
    if ok then
        return value
    end
    return nil
end

-- Explicit readers keep the compiler happy while still resolving executor
-- globals that are not mirrored into _G.
local GLOBAL_READERS = {
    loadstring = function() return loadstring end,
    load = function() return load end,
    HttpGet = function() return HttpGet end,
    request = function() return request end,
    http_request = function() return http_request end,
    syn = function() return syn end,
    RunService = function()
        return game:GetService("RunService")
    end,
}

local function readGlobal(name)
    local reader = GLOBAL_READERS[name]
    if reader == nil then
        return nil
    end
    local ok, value = pcall(reader)
    if ok then
        return value
    end
    return nil
end

--------------------------------------------------------------------------------
-- environment detection
--------------------------------------------------------------------------------

local function isServer()
    local runService = readGlobal("RunService")
    if runService == nil then
        return false
    end
    local ok, value = pcall(function()
        return runService:IsServer()
    end)
    return ok and value == true
end

-- Returns a list of { Name = string, Call = function(url) } and a list of
-- human readable notes about clients that were skipped.
local function httpClients()
    local clients = {}
    local notes = {}

    local function add(name, call)
        table.insert(clients, { Name = name, Call = call })
    end

    if type(safeIndex(game, "HttpGet")) == "function" then
        add("game:HttpGet", function(url)
            return game:HttpGet(url)
        end)
    end

    if type(safeIndex(game, "HttpGetAsync")) == "function" then
        add("game:HttpGetAsync", function(url)
            return game:HttpGetAsync(url)
        end)
    end

    if type(readGlobal("HttpGet")) == "function" then
        add("HttpGet", function(url)
            return readGlobal("HttpGet")(url)
        end)
    end

    if type(readGlobal("request")) == "function" then
        add("request", function(url)
            return readGlobal("request")({ Url = url, Method = "GET" })
        end)
    end

    if type(readGlobal("http_request")) == "function" then
        add("http_request", function(url)
            return readGlobal("http_request")({ Url = url, Method = "GET" })
        end)
    end

    local syn = readGlobal("syn")
    if type(syn) == "table" and type(safeIndex(syn, "request")) == "function" then
        add("syn.request", function(url)
            return syn.request({ Url = url, Method = "GET" })
        end)
    end

    -- Vanilla Roblox fallback: HttpService:GetAsync works on the server only.
    if isServer() then
        local ok, httpService = pcall(function()
            return game:GetService("HttpService")
        end)
        if ok and httpService ~= nil then
            local okEnabled, enabled = pcall(function()
                return httpService.HttpEnabled
            end)
            if okEnabled and enabled == true and type(safeIndex(httpService, "GetAsync")) == "function" then
                add("HttpService:GetAsync", function(url)
                    return httpService:GetAsync(url)
                end)
            else
                table.insert(notes, "HttpService:GetAsync skipped: HTTP requests are not enabled in this place")
            end
        end
    else
        table.insert(notes, "HttpService:GetAsync skipped: it only works from a server script")
    end

    return clients, notes
end

-- Returns a list of { Name = string, Call = function(source, chunkName) }.
local function compilers()
    local available = {}
    local loadstringFn = readGlobal("loadstring")

    if type(loadstringFn) == "function" then
        table.insert(available, { Name = "loadstring", Call = loadstringFn })
    end

    local loadFn = readGlobal("load")
    if type(loadFn) == "function" and loadFn ~= loadstringFn then
        table.insert(available, { Name = "load", Call = loadFn })
    end

    return available
end

local function responseBody(response)
    if type(response) == "string" then
        return response
    end

    if type(response) ~= "table" then
        return nil, "unexpected response type " .. typeName(response)
    end

    local status = response.Status or response.status or response.StatusCode or response.statusCode
    local body = response.Body or response.body or response.Data or response.data

    if typeof ~= nil and typeof(status) == "EnumItem" then
        status = status.Value
    end

    if type(status) == "number" and status >= 400 then
        return nil, "the server answered with HTTP " .. tostring(status)
    end

    if type(body) == "string" then
        return body
    end

    return nil, "the response table has no body"
end

-- Strips a UTF-8 BOM / shebang and rejects HTML pages so that a wrong branch
-- or path produces a readable error instead of a confusing compile failure.
local function sanitizeSource(source, url)
    if type(source) ~= "string" then
        return nil, "empty response"
    end

    source = source:gsub("^\239\187\191", "")
    source = source:gsub("^#![^\r\n]*[\r\n]+", "")

    if source == "" then
        return nil, "the response was empty"
    end

    local head = source:sub(1, 512):lower()
    if string.find(head, "<!doctype html", 1, true) or string.find(head, "<html", 1, true) then
        return nil, "the response looks like an HTML page, check the URL (" .. url .. ")"
    end

    return source
end

local function verifyModule(module, options)
    if type(module) ~= "table" then
        return false, "the remote chunk returned " .. typeName(module) .. " instead of the Bankroll module"
    end

    if type(module.new) ~= "function" then
        return false, "the remote chunk returned a table without Bankroll.new"
    end

    local required = options and options.RequiredVersion
    if required ~= nil and module.Version ~= required then
        return false, "version mismatch: expected " .. tostring(required) .. ", received " .. tostring(module.Version)
    end

    return true
end

--------------------------------------------------------------------------------
-- public API
--------------------------------------------------------------------------------

Loader.Url = "https://raw.githubusercontent.com/hrisitosenser/bankroll/main/src/Bankroll.lua"

-- Builds the mirror list for a repository / tag / path combination.
function Loader.BuildUrls(tag, path, repository)
    tag = tag or Loader.Tag
    path = path or Loader.Path
    repository = repository or Loader.Repository

    return {
        string.format("https://raw.githubusercontent.com/%s/%s/%s", repository, tag, path),
        string.format("https://cdn.jsdelivr.net/gh/%s@%s/%s", repository, tag, path),
        string.format("https://github.com/%s/raw/%s/%s", repository, tag, path),
        string.format("https://raw.githack.com/%s/%s/%s", repository, tag, path),
    }
end

-- Mirrors are tried in order until one of them answers with usable source.
Loader.Mirrors = Loader.BuildUrls()

-- Resolves the URL list for a Load() call: explicit URLs first, then the tag
-- based mirrors, then Loader.Mirrors unless Fallback = false was passed.
function Loader.ResolveUrls(options)
    options = options or {}
    local urls = {}
    local seen = {}

    local function add(url)
        if type(url) == "string" and url ~= "" and not seen[url] then
            seen[url] = true
            table.insert(urls, url)
        end
    end

    add(options.Url)
    for _, url in ipairs(options.Mirrors or {}) do
        add(url)
    end

    if options.Tag ~= nil or options.Path ~= nil or options.Repository ~= nil then
        for _, url in ipairs(Loader.BuildUrls(options.Tag, options.Path, options.Repository)) do
            add(url)
        end
    end

    if options.Fallback ~= false then
        for _, url in ipairs(Loader.Mirrors) do
            add(url)
        end
    end

    return urls
end

-- A short description of what this environment can do, useful for bug reports.
function Loader.GetEnvironment()
    local clients, notes = httpClients()
    local available = compilers()

    local fetchNames = {}
    for _, client in ipairs(clients) do
        table.insert(fetchNames, client.Name)
    end

    local compilerNames = {}
    for _, compiler in ipairs(available) do
        table.insert(compilerNames, compiler.Name)
    end

    local reasons = {}
    if #clients == 0 then
        table.insert(reasons, "no HTTP client available (game:HttpGet / request / HttpService)")
    end
    if #available == 0 then
        table.insert(reasons, "loadstring is not available (server scripts need LoadStringEnabled)")
    end
    for _, note in ipairs(notes) do
        table.insert(reasons, note)
    end

    return {
        FetchClients = fetchNames,
        Compilers = compilerNames,
        CanFetch = #clients > 0,
        CanCompile = #available > 0,
        Supported = #clients > 0 and #available > 0,
        IsServer = isServer(),
        Notes = reasons,
    }
end

-- Returns true when the remote variant can work here, plus a reason otherwise.
function Loader.IsSupported()
    local environment = Loader.GetEnvironment()
    if environment.Supported then
        return true
    end
    return false, table.concat(environment.Notes, "; ")
end

-- Downloads a URL and returns the body as a string (plus the client used).
function Loader.Fetch(url)
    local clients = httpClients()
    if #clients == 0 then
        return nil, "no HTTP client available: use require() in Studio or an executor style game:HttpGet"
    end

    local errors = {}
    for _, client in ipairs(clients) do
        local ok, response = pcall(client.Call, url)
        if ok then
            local body, reason = responseBody(response)
            if body ~= nil then
                return body, client.Name
            end
            table.insert(errors, client.Name .. ": " .. tostring(reason))
        else
            table.insert(errors, client.Name .. ": " .. truncate(response))
        end
    end

    return nil, table.concat(errors, "; ")
end

-- Compiles Lua source into a chunk. Returns the chunk or nil plus a reason.
function Loader.Compile(source, chunkName)
    local available = compilers()
    if #available == 0 then
        return nil, "loadstring is not available here: Studio clients and servers without "
            .. "LoadStringEnabled cannot compile remote source, use require(game.ReplicatedStorage.Bankroll)"
    end

    chunkName = chunkName or Loader.ChunkName

    local errors = {}
    for _, compiler in ipairs(available) do
        local ok, chunk, reason = pcall(compiler.Call, source, chunkName)
        if ok and type(chunk) == "function" then
            return chunk, compiler.Name
        end
        table.insert(errors, compiler.Name .. ": " .. truncate(reason or chunk))
    end

    return nil, table.concat(errors, "; ")
end

-- Fetches, compiles and executes src/Bankroll.lua, then returns the module.
-- The result is cached; pass Force = true to download again.
--
-- options:
--   Url             string   - use this URL instead of the mirrors
--   Mirrors         {string} - extra URLs to try
--   Tag/Path/Repository string - build the mirror URLs from these values
--   Fallback        boolean  - false = do not fall back to Loader.Mirrors
--   ChunkName       string   - chunk name used in stack traces
--   RequiredVersion string   - fail unless the module reports this Version
--   Force           boolean  - ignore the cache and download again
--   Quiet           boolean  - skip the informational print
--   NoThrow         boolean  - return nil, message instead of raising
function Loader.Load(options)
    options = options or {}

    local cached = rawget(Loader, "_module")
    if cached ~= nil and options.Force ~= true then
        return cached
    end

    local urls = Loader.ResolveUrls(options)
    if #urls == 0 then
        local message = "[Bankroll] no URL to load from. Pass options.Url or set Loader.Mirrors."
        rawset(Loader, "LastError", message)
        if options.NoThrow then
            return nil, message
        end
        error(message, 2)
    end

    local failures = {}

    for _, url in ipairs(urls) do
        local source, fetchReason = Loader.Fetch(url)
        if source == nil then
            table.insert(failures, url .. "\n    fetch: " .. tostring(fetchReason))
        else
            local clean, sanitizeReason = sanitizeSource(source, url)
            if clean == nil then
                table.insert(failures, url .. "\n    " .. tostring(sanitizeReason))
            else
                local chunk, compileReason = Loader.Compile(clean, options.ChunkName)
                if chunk == nil then
                    table.insert(failures, url .. "\n    compile: " .. tostring(compileReason))
                else
                    local ok, module = pcall(chunk, Loader)
                    if not ok then
                        table.insert(failures, url .. "\n    run: " .. truncate(module, 240))
                    else
                        local valid, verifyReason = verifyModule(module, options)
                        if valid then
                            rawset(Loader, "_module", module)
                            rawset(Loader, "_source", clean)
                            rawset(Loader, "LastUrl", url)
                            rawset(Loader, "LastError", nil)

                            if options.Quiet ~= true and Loader.Quiet ~= true then
                                print(string.format(
                                    "[Bankroll] loaded v%s from %s",
                                    tostring(module.Version),
                                    url
                                ))
                            end

                            return module
                        end
                        table.insert(failures, url .. "\n    " .. tostring(verifyReason))
                    end
                end
            end
        end
    end

    local message = "[Bankroll] unable to load the library:\n  " .. table.concat(failures, "\n  ")
    rawset(Loader, "LastError", message)

    if options.NoThrow then
        return nil, message
    end
    error(message, 2)
end

-- Loads with NoThrow = true and gives back a plain result table, handy for
-- `local result = Loader.TryLoad()` style call sites.
function Loader.TryLoad(options)
    local module, reason = Loader.Load(options)
    if module == nil then
        return { Ok = false, Error = reason }
    end
    return { Ok = true, Module = module }
end

function Loader.GetModule()
    return rawget(Loader, "_module")
end

function Loader.GetSource()
    return rawget(Loader, "_source")
end

function Loader.ClearCache()
    rawset(Loader, "_module", nil)
    rawset(Loader, "_source", nil)
    rawset(Loader, "LastUrl", nil)
end

--------------------------------------------------------------------------------
-- proxy + optional auto-load
--------------------------------------------------------------------------------

-- The table returned by the chunk is the loader, but it transparently forwards
-- anything the library exposes, so `Bankroll.new()` works right after
-- `loadstring(game:HttpGet(loaderUrl))()`.
setmetatable(Loader, {
    __index = function(self, key)
        local module = rawget(self, "_module")
        if module ~= nil then
            return module[key]
        end

        error(string.format(
            "[Bankroll] '%s' is not available: the library is not loaded.\n    %s",
            tostring(key),
            rawget(self, "LastError") or "Call BankrollLoader.Load() first."
        ), 2)
    end,

    __call = function(self, options)
        return rawget(self, "Load")(options)
    end,
})

-- `AutoLoad` only fires where the remote variant can actually work: an HTTP
-- client plus loadstring. Requiring this file inside plain Studio therefore
-- stays silent and you can keep using require(game.ReplicatedStorage.Bankroll).
if Loader.AutoLoad then
    local supported = Loader.IsSupported()
    if supported then
        local ok, reason = pcall(Loader.Load)
        if not ok and Loader.Quiet ~= true then
            print("[Bankroll] auto-load failed: " .. tostring(reason))
        end
    elseif Loader.Verbose == true then
        local _, reason = Loader.IsSupported()
        print("[Bankroll] auto-load skipped: " .. tostring(reason))
    end
end

return Loader
