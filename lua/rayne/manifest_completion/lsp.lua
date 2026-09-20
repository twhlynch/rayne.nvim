local schema_builder = require("rayne.manifest_completion.schema_builder")

local M = {}

--- configure jsonls to use the build-config schema
function M.setup()
	local schema_path = schema_builder.get_path()

	if vim.fn.filereadable(schema_path) == 0 then
		schema_builder.write()
	end

	vim.lsp.config("jsonls", {
		settings = {
			json = {
				schemas = {
					{
						fileMatch = { "build-config.json" },
						url = "file://" .. schema_path,
						name = "Rayne Build Config",
					},
				},
				validate = { enable = true },
			},
		},
	})

	vim.lsp.enable("jsonls")
end

return M
