local decoders = require("luau-tree.server.decoders")

local M = {}

function M.headers(str, meta)
  if str == "" then
    return
  end

  local headers = {}
  local metadata = {}

  for match in string.gmatch(str, "([^\r\n]+)\r\n") do
    local name, value = string.match(match, "(.+): (.+)")

    if name and value then
      headers[string.lower(name):gsub("%-", "_")] = value
    elseif meta then
      local method, place = string.match(match, "(%w+) (.+) HTTP/1%.1")

      if method and place then
        local path, rawQueries = string.match(place, "([^%?]+)(.*)")
        local queries = {}

        if rawQueries then
          for query, queryValue in string.gmatch(rawQueries, "(%w+)=([^&=]+)") do
            queries[query] = queryValue
          end
        end

        metadata.method = string.lower(method)
        metadata.queries = queries
        metadata.path = path
      end
    end
  end

  return headers, metadata
end

function M.response(headers, body, status)
  assert(type(body) == "string", "Body must be a string")

  local data = {
    "HTTP/1.1 " .. tostring(status),
    "Content-Length: " .. tostring(string.len(body)),
    "",
    body
  }

  -- Safe to use, as indexes are converted to lowercase beforehand.
  if not headers["content-type"] then
    table.insert(data, 2, "Content-Type: text/plain")
  end

  for name, value in pairs(headers) do
    table.insert(data, 4, string.format("%s: %s", name, value))
  end

  return table.concat(data, "\r\n")
end

function M.request(metadata, headers, body)
  local request = {
    headers = headers
  }

  for key, value in pairs(metadata) do
    request[key] = value
  end

  local contentType = string.lower(headers.content_type or "") -- Make sure to convert to lowercase, since content type apparently is case-insesitive.
  local decoder = body and decoders[contentType]

  request.body = decoder and decoder(body) or body

  return request
end

return M
