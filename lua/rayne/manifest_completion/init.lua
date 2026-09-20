local lsp_config = require("rayne.manifest_completion.lsp")
local progress = require("rayne.manifest_completion.progress")
local schema_mod = require("rayne.manifest_completion.schema")
local updater = require("rayne.manifest_completion.updater")

local M = {}

function M.setup()
	-- configure jsonls immediately
	lsp_config.setup()

	-- create :AndroidManifestUpdate command (runs in the background)
	vim.api.nvim_create_user_command("AndroidManifestUpdate", function(cmd_args)
		if updater.is_running() then
			progress.notify("Android manifest schema update already running", vim.log.levels.WARN)
			return
		end

		if cmd_args.bang then
			local sources_dir = updater.get_sources_dir()
			if vim.fn.isdirectory(sources_dir) == 1 then
				vim.fn.delete(sources_dir, "rf")
			end
		end

		local started = updater.update_async(function(ok)
			if ok then
				schema_mod.invalidate()
				lsp_config.setup()
			end
		end)
		if not started then
			progress.notify("Android manifest schema update already running", vim.log.levels.WARN)
		end
	end, {
		bang = true,
		desc = "Update Android manifest completion schema",
	})

	-- prompt to install schema when opening build-config.json
	local prompted = false

	vim.api.nvim_create_autocmd("BufReadPost", {
		callback = function(args)
			if prompted or not vim.fn.bufname(args.buf):match("build%-config%.json$") then
				return
			end
			if schema_mod.load() then
				return
			end

			prompted = true
			vim.ui.select({ "Yes", "No" }, {
				prompt = "Android manifest completion is not setup. Run :AndroidManifestUpdate?",
			}, function(choice)
				if choice == "Yes" then
					vim.cmd("AndroidManifestUpdate")
				end
			end)
		end,
	})
end

return M
