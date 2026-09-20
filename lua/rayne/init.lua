local M = {}

--- plugin setup
--- @param opts Rayne.Options option overrides
function M.setup(opts)
	local options = require("rayne.options")
	options.set(opts)

	if options.get().snippets then
		if vim.fn.filereadable(vim.fn.getcwd() .. "/build-config.json") == 1 then
			require("rayne.snippets").setup()
		end
	end

	if options.get().manifest_completion then
		require("rayne.manifest_completion").setup()
	end
end

return M
