local options = {
  enabled = {
    value = true,
  },
  port = {
    value = 3667,
    invalid = "value must be between 1024 and 49151.",
    validator = function(value)
      return value >= 1024 and value <= 49151
    end,
  },
  host = {
    value = "127.0.0.1",
  },
}

local hooks = {}

local M = {}
local C = {}

function M:__index(index)
  local option = options[index]
  assert(option, string.format("Invalid option %s'.", tostring(index)))

  return option.value
end

function M:__newindex(index, value)
  index = tostring(index)
  local option = options[index]

  assert(option, string.format("Invalid option %s.", index))
  assert(type(value) == type(option.value), string.format("Expected %s to be %s, got %s.", index, type(option.value), type(value)))

  if option.validator then
    assert(option.validator(value), string.format("Could not validate %s: %s", index, option.invalid))
  end

  for _, hook in ipairs(hooks) do
    if hook.name == index then
      hook.callback(value)
    end
  end

  option.value = value
end

function C:hook(index, callback)
  assert(type(index) == "string", "Hook name must be a string.")
  assert(type(callback) == "function", "Callback must be a function.")

  local hook = {
    name = index,
    callback = callback,
  }

  table.insert(hooks, hook)

  -- Unhook
  local obj = {}

  function obj:unhook()
    for i, v in ipairs(hooks) do
      if v == hook then
        table.remove(hooks, i)
        break
      end
    end
  end

  return obj
end

return setmetatable(C, M)
