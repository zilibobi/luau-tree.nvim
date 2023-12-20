# luau-tree.nvim
Luau-tree is a 100% Lua HTTP/1.1 server for bringing your Roblox DataModel into Neovim.

## Installation
Use a package manager of your choice or clone this repo yourself.
Here is an example using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "zilibobi/luau-tree.nvim"
}
```

## Dependencies
Although this plugin does not have any dependencies, it relies on you having [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) configured in Neovim
and the companion plugin installed in Roblox Studio. Download the `.rbxm` plugin file from the [latest release](https://github.com/JohnnyMorganz/luau-lsp/releases/latest)
and move it to your plugins folder in Studio.

To add Roblox types and Rojo support, use [luau-lsp.nvim](https://github.com/lopi-py/luau-lsp.nvim).

---
Tip: using [lsp-zero.nvim](https://github.com/VonHeikemen/lsp-zero.nvim) is an easy way to set up and configure your LSPs.

## Configuration
Here is the default configuration:

```lua
local config = require("luau-tree.config")

config.host = "127.0.0.1" -- Equivalent to 'localhost'.
config.port = 3667 -- Valid values are between 1024 and 49151.

config.enabled = true
```

Hook a function that listens to configuration changes:

```lua
local hook = config:hook("enabled", function(value)
  print(tostring(value) .. " is the new value of 'enabled'.")
end)

-- Unhook the function.
hook:unhook()
```

## Server API
Use the server API to create your own apps.

> [!WARNING]
> The server code is not tested and may be vulnerable to attacks.
> **Do not use it in production**.

Here is an example that entirely documents the built-in server API:
```lua
local server = require("luau-tree.server")

-- Creates a new app, does not listen to any requests yet.
local app = server.new()

-- All standard methods have their own functions.
local listener = app:get("/", function(req, res)
  -----------
  -- REQUEST:
  -----------
  -- The headers that were sent with the request.
  local content_type = req.headers.content_type -- All letters are lowercase and the '-' symbol is replaced with '_'.

  -- The body that was sent with the request.
  local body = req.body -- It is automatically decoded based on the 'Content-Type' header. Currently only JSON is supported. Text is the fallback type.

  -- The queries that were passed together with the path.
  local name = req.queries.name -- For example: https://example.com/resource?name=my+resource&value=foo
  -- Currently, the queries are taken literally, meaning the value of 'name' will not be 'my resource' but 'my+resource'.

  -- The path path of the request without queries.
  local path = req.path

  -- The method of the request (e.g. GET, POST)
  local method = req.method
  ------------
  -- RESPONSE:
  ------------
  -- All headers will be converted to lowercase, so your casing does not matter. Do not make duplicate headers, though.
  res.headers["content-type"] = "text/html"

  -- The status code the of the response. Default is '200' - OK.
  res.status = 100

  -- The body of the response. Only accepts strings.
  res.body = "<h1>Hello, world!</h1>"
end, false) -- The last argument: 'force' (optional) - indicates whether to overwrite an already existing
-- listener for this path and method, otherwise an error will be thrown.

-- Stop listening to GET requests on this path.
listener:destroy()

-- Binds the server to the specified host and port.
-- Can only be called once.

-- Listeners added after this function will still work, but it's generally
-- a good idea to call this function after all listeners have been added.
app:listen("127.0.0.1", 9834)

-- Stops accepting messages from clients.
app:shutdown()

-- Restart the server on a new port or host:
app:listen("127.0.0.1", 9834)

app:shutdown()
app:listen("127.0.0.1", 3498)
```
