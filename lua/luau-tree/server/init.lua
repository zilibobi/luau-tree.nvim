local http = require("luau-tree.server.http")

-- This has been pretty useful as the TCP API is not really documented and it's my first time working with stuff like this:
-- https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp/rpc.lua
local function requestParserLoop()
  local headerBuffer = ""

  while true do
    local start, finish = string.find(headerBuffer, "\r\n\r\n", 1, true) -- In HTTP/1.1, headers end with double CRLF

    -- The headers have been assembled, start assembling the body.
    if start then
      local headers, metadata = http.headers(headerBuffer, true)
      local contentLength = headers and tonumber(headers.content_length) or 0

      local bodyChunks = { string.sub(headerBuffer, finish + 1) }
      local bodyLength = #bodyChunks[1]

      while bodyLength < contentLength do
        local chunk = coroutine.yield()
            or error("Expected more chunks for the body.")

        table.insert(bodyChunks, chunk)
        bodyLength = bodyLength + #chunk
      end

      -- Trim the last chunk so it matches the content length.
      local lastChunk = bodyChunks[#bodyChunks]
      bodyChunks[#bodyChunks] = string.sub(lastChunk, 1, contentLength - bodyLength - 1)

      local remaining = ""

      if bodyLength > contentLength then
        remaining = string.sub(lastChunk, contentLength - bodyLength)
      end

      local body = table.concat(bodyChunks)
      local chunk = coroutine.yield(metadata, headers, body)
          or error("Expected more chunks for the header.")

      headerBuffer = remaining .. chunk
    else
      -- Wait for more header chunks to buffer.
      local chunk = coroutine.yield()
          or error("Expected more chunks for the header.")

      headerBuffer = headerBuffer .. chunk
    end
  end
end

local function handleRequest(listeners, socket, metadata, headers, body)
  local request = http.request(metadata, headers, body)

  local methodListeners = listeners[request.method]
  local listener = methodListeners and methodListeners[request.path]

  local resObj = {
    status = 200,
    headers = {},
    body = "",
  }

  -- Allow the callback function to modify the response object.
  if listener then
    local success, err = pcall(listener.callback, request, resObj)

    if success then
      -- Validate headers.
      local validated = {}

      for name, value in pairs(resObj.headers) do
        name, value = tostring(name), tostring(value)

        assert(name, "Invalid header name type.")
        assert(value, "Invalid header value type.")

        validated[string.lower(name)] = value
      end

      resObj.headers = validated
    else
      resObj.status = 500
      resObj.headers = {} -- Make sure it's a table to prevent further errors.
      resObj.body = "Error while running callback: " .. err
    end
  else
    resObj.status = 404
  end

  local response = http.response(resObj.headers, resObj.body, resObj.status)
  socket:write(response)
end

local M = {}
M.__index = M

function M.new()
  local server = setmetatable({}, M)
  server.listeners = {}

  return server
end

function M:on(method, path, callback, force)
  method = string.lower(method)

  local methodListeners = self.listeners[method]
  local existingListener = methodListeners and methodListeners[path]

  if not force and existingListener then
    error(
      string.format(
      "'%s' method '%s' is already being listened to. Use the 'force' argument or the :destroy() function to override/remove this listener.",
        path, method)
    )
  end

  local obj = {
    path = path,
    method = method,
    callback = callback,
  }

  if not self.listeners[method] then
    self.listeners[method] = {}
  end

  self.listeners[method][path] = obj

  -- Return a way to destroy the listener.
  local listener = {}
  listener.obj = obj

  function listener:destroy()
    self.listeners[method][path] = nil
  end

  return listener
end

function M:listen(host, port)
  assert(type(host) == "string", "Server host must be a string.")
  assert(type(port) == "number", "Server port must be a number.")

  if self.listening then
    assert(
      string.format("This server object is already bound to http://%s:%d.", self.host, self.port)
    )
  end

  self.listening = true

  self.host = host
  self.port = port

  local tcp = vim.uv.new_tcp()
  tcp:bind(host, port)

  self.tcp = tcp

  tcp:listen(128, function(bindErr)
    assert(not bindErr, bindErr)

    local socket = vim.uv.new_tcp()
    tcp:accept(socket)

    self.socket = socket

    local parseChunk = coroutine.wrap(requestParserLoop)
    parseChunk() -- Yield until the next chunk.

    socket:read_start(function(readErr, chunk)
      assert(not readErr, readErr)

      if chunk then
        while true do
          local metadata, headers, body = parseChunk(chunk)

          if metadata then
            local success, err = pcall(handleRequest, self.listeners, socket, metadata, headers, body)

            if not success then
              local response = http.response({}, "Error while generating response: " .. err, 500)
              socket:write(response)
            end

            chunk = ""
          else
            break
          end
        end
      else
        socket:close()
      end
    end)
  end)
end

function M:shutdown()
  if self.listening then
    self.tcp:shutdown()

    if self.socket then
      self.socket:shutdown()
    end

    self.listening = false
  end
end

-- Copy-paste: define functions for all standard methods.
function M:get(path, callback, force)
  return self:on("GET", path, callback, force)
end

function M:post(path, callback, force)
  return self:on("POST", path, callback, force)
end

function M:put(path, callback, force)
  return self:on("PUT", path, callback, force)
end

function M:patch(path, callback, force)
  return self:on("PATCH", path, callback, force)
end

function M:delete(path, callback, force)
  return self:on("DELETE", path, callback, force)
end

function M:head(path, callback, force)
  return self:on("HEAD", path, callback, force)
end

function M:options(path, callback, force)
  return self:on("OPTIONS", path, callback, force)
end

return M
