local M = {}

--- whether fidget's progress module is available
--- @return boolean
function M.has_fidget()
	local ok, mod = pcall(require, "fidget.progress")
	return ok and mod ~= nil
end

--- notify the user, preferring fidget when installed
--- @param msg string
--- @param level integer|nil vim.log.levels value
function M.notify(msg, level)
	level = level or vim.log.levels.INFO
	local ok, fidget = pcall(require, "fidget")
	if ok and fidget and type(fidget.notify) == "function" then
		local ok_notify = pcall(fidget.notify, msg, level, { title = "rayne.nvim" })
		if ok_notify then
			return
		end
	end
	vim.notify(msg, level, { title = "rayne.nvim" })
end

--- create a progress handle for a long-running task.
--- uses fidget when installed, otherwise degrades to vim.notify on finish.
--- @param title string
--- @param message string|nil initial message
--- @return { report: fun(self, message: string, percentage: integer|nil), finish: fun(self, message: string|nil), fail: fun(self, message: string|nil) }
function M.create(title, message)
	local ok, fprogress = pcall(require, "fidget.progress")
	if ok and fprogress and fprogress.handle and type(fprogress.handle.create) == "function" then
		local ok_create, handle = pcall(fprogress.handle.create, {
			title = title,
			message = message,
			lsp_client = { name = "rayne" },
		})
		if ok_create and handle then
			return {
				_report = handle,
				report = function(self, msg, percentage)
					pcall(handle.report, handle, { message = msg, percentage = percentage })
				end,
				finish = function(self, msg)
					if msg then
						pcall(handle.report, handle, { message = msg, percentage = 100 })
					end
					pcall(handle.finish, handle)
				end,
				fail = function(self, msg)
					if msg then
						pcall(handle.report, handle, { message = msg })
					end
					if type(handle.cancel) == "function" then
						pcall(handle.cancel, handle)
					else
						pcall(handle.finish, handle)
					end
					M.notify(msg or title .. " failed", vim.log.levels.ERROR)
				end,
			}
		end
	end

	-- fallback without fidget: stay quiet during progress, notify when done
	return {
		report = function(self, msg, percentage) end,
		finish = function(self, msg)
			M.notify(msg or title .. " done", vim.log.levels.INFO)
		end,
		fail = function(self, msg)
			M.notify(msg or title .. " failed", vim.log.levels.ERROR)
		end,
	}
end

return M
