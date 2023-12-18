local server = require("luau-tree.server")
local config = require("luau-tree.config")

local app = server.new()

app:post("/full", function(req, res)
  local client = vim.lsp.get_clients({ name = "luau_lsp" })[1]

  if not client then
    res.status = 500
    return
  end

  if req.body.tree then
    client.notify("$/plugin/full", req.body.tree)
  else
    res.status = 400
  end
end)

app:post("/clear", function(_, res)
  local client = vim.lsp.get_clients({ name = "luau_lsp" })[1]

  if not client then
    res.status = 500
    return
  end

  client.notify("$/plugin/clear")
end)

app:listen(config.host, config.port)

-- Hook configuration
local function restart()
  app:shutdown()
  app:listen(config.host, config.port)
end

config:hook("enabled", function(value)
  if value and not app.listening then
    restart()
  elseif not value and app.listening then
    app:shutdown()
  end
end)

config:hook("host", restart)
config:hook("port", restart)
