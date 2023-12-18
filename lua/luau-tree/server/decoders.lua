local M = {}

M["application/json"] = function(content)
  return vim.json.decode(content)
end

return M
