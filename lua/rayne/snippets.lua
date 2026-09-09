local M = {}

--- @return string | nil
local function get_plugin_root()
	local source = debug.getinfo(1, "S").source
	return source:match("@(.*)/lua/rayne/snippets%.lua$")
end

function M.setup()
	local root = get_plugin_root()
	if not root then
		return
	end

	local snippet_path = root .. "/snippets"
	local ok, _ = pcall(function()
		require("luasnip.loaders.from_lua").load({ paths = snippet_path })
	end)

	if not ok then
		vim.notify("rayne: failed to load snippets from " .. snippet_path, vim.log.levels.WARN)
	end
end

return M
