local M = {}

--- read and parse a json file to a table
--- @param filepath string
function M.load_json_file(filepath)
	local ok, lines = pcall(vim.fn.readfile, filepath)
	if not ok or not lines then
		vim.notify("Failed to read " .. filepath, vim.log.levels.ERROR)
		return nil
	end

	local config_content = table.concat(lines, "\n")

	---@diagnostic disable-next-line: redefined-local
	local ok, decoded = pcall(vim.json.decode, config_content)
	if not ok or not decoded then
		vim.notify("Failed to parse " .. filepath, vim.log.levels.ERROR)
		return nil
	end

	return decoded
end

function M.verify_directory(directory)
	if vim.fn.isdirectory(directory) == 0 then
		vim.notify("Directory " .. directory .. " does not exist", vim.log.levels.ERROR)
		return false
	end
	return true
end

function M.verify_file(filepath)
	if vim.fn.filereadable(filepath) == 0 then
		vim.notify("File " .. filepath .. " does not exist", vim.log.levels.ERROR)
		return false
	end
	return true
end

--- @class Rayne.pick_files_opts
--- @field source string
--- @field title string
--- @field cmd string[]
--- @field error string

--- @param opts Rayne.pick_files_opts
function M.pick_files(opts, callback)
	Snacks.picker.pick({
		source = opts.source,
		title = opts.title,
		cwd = vim.fn.getcwd(),

		finder = function()
			local ok, results = pcall(vim.fn.systemlist, opts.cmd)
			if not ok or #results == 0 then
				vim.notify(opts.error, vim.log.levels.WARN)
				return {}
			end

			local items = {}
			for _, path in ipairs(results) do
				items[#items + 1] = { text = path, file = path }
			end
			return items
		end,

		format = "file",

		confirm = function(picker, item)
			picker:close()
			if item then
				callback(item.file)
			end
		end,
	})
end

--- @class Rayne.pick_string_opts
--- @field source string
--- @field title string
--- @field items string[]

--- @param opts Rayne.pick_string_opts
function M.pick(opts, callback)
	Snacks.picker.pick({
		source = opts.source,
		title = opts.title,

		finder = function()
			local items = {}
			for _, item in ipairs(opts.items) do
				items[#items + 1] = { text = item, file = item }
			end
			return items
		end,

		confirm = function(picker, item)
			picker:close()
			if item then
				callback(item.file)
			end
		end,
	})
end

--- @class Rayne.confirm_opts
--- @field prompt string
--- @field yes string
--- @field no string

---@param opts Rayne.confirm_opts
---@param callback fun(confirmed: boolean)
function M.confirm(opts, callback)
	vim.ui.select({ opts.yes, opts.no }, {
		prompt = opts.prompt,
	}, function(choice)
		callback(choice == opts.yes)
	end)
end

--- @class Rayne.find_opts
--- @field directory string | nil
--- @field maxdepth integer | nil
--- @field insensitive boolean | nil
--- @field type "f" | "d" | nil

--- @param opts Rayne.find_opts
--- @param name string
function M.find(name, opts)
	local cmd = { "find" }

	table.insert(cmd, opts.directory or vim.fn.getcwd())

	if opts.maxdepth ~= nil then
		table.insert(cmd, tostring(opts.maxdepth))
	end

	if opts.type ~= nil then
		table.insert(cmd, "-type")
		table.insert(cmd, opts.type)
	end

	table.insert(cmd, opts.insensitive and "-iname" or "-name")
	table.insert(cmd, name)

	return vim.fn.systemlist(cmd)
end

--- @generic T
--- @param func fun(callback: fun(value: T))
--- @return T
function M.await(func)
	local co = coroutine.running()

	func(function(...)
		coroutine.resume(co, ...)
	end)

	return coroutine.yield()
end

--- @param func fun()
function M.async(func)
	coroutine.wrap(func)()
end

return M
