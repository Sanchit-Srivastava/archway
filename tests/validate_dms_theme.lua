-- Exercise path selection without a DMS process, plugins, or user config.
local root = vim.fn.getcwd()
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local selected
package.loaded.base46 = {
  _DMS_SUPPORT = true,
  theme_tables = {},
  get_builtin_theme = function(name)
    selected = name
    return { type = "dark" }
  end,
  theme_harmonize = function(theme) return theme end,
  theme_set_bg = function(theme) return theme end,
  load = function() end,
}
vim.system = function()
  return { wait = function() return { stdout = "dark" } end }
end
_G._matugen_theme_watcher = true

local function settings(dir, name)
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ vim.json.encode({
    matugenTemplateNeovimSettings = { dark = { baseTheme = name } },
  }) }, dir .. "/settings.json")
end

local function check(name, setup, expected)
  local config = tmp .. "/" .. name
  vim.fn.mkdir(config, "p")
  vim.env.XDG_CONFIG_HOME = config
  setup(config)
  package.loaded.base46.theme_tables = {}
  selected = nil
  dofile(root .. "/dots/nvim/colors/dms.lua")
  assert(selected == expected, name .. ": selected " .. tostring(selected))
  print(name .. ": PASS")
end

local ok, err = pcall(function()
  check("new-only", function(c) settings(c .. "/dms", "new") end, "new")
  check("legacy-only", function(c) settings(c .. "/DankMaterialShell", "legacy") end, "legacy")
  check("both", function(c)
    settings(c .. "/dms", "new")
    settings(c .. "/DankMaterialShell", "legacy")
  end, "new")
  check("migrated", function(c)
    settings(c .. "/dms", "new")
    assert(vim.uv.fs_symlink("dms", c .. "/DankMaterialShell"))
  end, "new")
  check("persisted-legacy", function(c)
    settings(c .. "/DankMaterialShell", "legacy")
    assert(vim.uv.fs_symlink("DankMaterialShell", c .. "/dms"))
  end, "legacy")
  for _, file in ipairs({
    "dots/nvim/lua/plugins/dankcolors.lua",
    "dots/nvim/lua/lualine/themes/dms.lua",
  }) do
    assert(loadfile(root .. "/" .. file))
  end
end)
vim.fn.delete(tmp, "rf")
if not ok then error(err) end
print("DMS theme path tests and Lua syntax: PASS")
