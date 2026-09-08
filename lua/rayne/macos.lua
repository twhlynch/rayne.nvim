local build_config = require("rayne.build_config")
local options = require("rayne.options")
local utils = require("rayne.utils")

local M = {}

local function run_create_build_project(args)
	return utils.await(function(done)
		local cmd = { "bash", "-c", "python3 " .. table.concat(args, " ") }

		local term = Snacks.terminal.open(cmd, {
			win = { position = "bottom", height = 0.35 },
			auto_close = false,
		})

		vim.api.nvim_create_autocmd("TermClose", {
			buffer = term.buf,
			once = true,
			callback = function()
				local exit_code = vim.v.event and vim.v.event.status or 0
				done(exit_code == 0)
			end,
		})
	end)
end

local function xcodebuild(project_dir, scheme, configuration)
	return utils.await(function(done)
		local cmd = {
			"xcodebuild",
			"-project",
			project_dir .. "/" .. scheme .. ".xcodeproj",
			"-scheme",
			scheme,
			"-configuration",
			configuration,
			"build",
		}

		local term = Snacks.terminal.open(cmd, {
			win = { position = "bottom", height = 0.35 },
			auto_close = false,
		})

		vim.api.nvim_create_autocmd("TermClose", {
			buffer = term.buf,
			once = true,
			callback = function()
				local exit_code = vim.v.event and vim.v.event.status or 0
				done(exit_code == 0)
			end,
		})
	end)
end

local function find_app_bundle(project_dir, app_name)
	local results = utils.find(app_name .. ".app", {
		directory = project_dir,
		type = "d",
		insensitive = true,
	})

	for _, path in ipairs(results) do
		if path:match("%.app$") then
			return path
		end
	end

	return nil
end

local function launch_app(app_path)
	vim.fn.system({ "open", app_path })
end

local function resolve_app_and_launch(project_dir, app_name)
	local app_path = find_app_bundle(project_dir, app_name)
	if not app_path then
		vim.notify("Could not find " .. app_name .. ".app in " .. project_dir, vim.log.levels.ERROR)
		return false
	end

	launch_app(app_path)
	return true
end

local function get_pid_by_name(app_name)
	local output = vim.fn.system({ "pgrep", "-x", app_name })
	output = vim.trim(output)

	if #output == 0 then
		return nil
	end

	return tonumber(output:match("^(%d+)"))
end

local function attach_debugger(pid, binary_path, app_name)
	local dap = require("dap")

	dap.run({
		name = "Attach to macOS (" .. app_name .. ")",
		type = "lldb",
		request = "attach",
		pid = pid,
		program = binary_path,
		stopOnEntry = false,
	})
end

local function find_binary_in_app(app_path)
	return app_path .. "/Contents/MacOS/" .. vim.fn.fnamemodify(app_path, ":t:r")
end

-- MARK: Public

function M.generate(configuration)
	utils.async(function()
		local config = build_config.get_build_config()
		if not config then
			return
		end

		local opts = options.get()
		local script_path = opts.engine_path .. "/Tools/BuildHelper/CreateBuildProject.py"
		local build_config_path = build_config.get_build_config_path()

		if not utils.verify_file(script_path) then
			return
		end

		local args = { script_path, build_config_path, "macos", configuration or "independent" }

		if not run_create_build_project(args) then
			vim.notify("macOS project generation failed", vim.log.levels.ERROR)
			return
		end

		local project_dir = build_config.get_macos_project_dir()
		if not utils.verify_directory(project_dir) then
			return
		end
	end)
end

function M.build()
	utils.async(function()
		local project_dir = build_config.get_macos_project_dir()
		if not utils.verify_directory(project_dir) then
			return
		end

		local app_name = build_config.get_application_name()
		if not app_name then
			return
		end

		xcodebuild(project_dir, app_name, "Debug")
	end)
end

function M.build_launch()
	utils.async(function()
		local project_dir = build_config.get_macos_project_dir()
		if not utils.verify_directory(project_dir) then
			return
		end

		local app_name = build_config.get_application_name()
		if not app_name then
			return
		end

		if not xcodebuild(project_dir, app_name, "Debug") then
			return
		end

		resolve_app_and_launch(project_dir, app_name)
	end)
end

function M.build_launch_attach()
	utils.async(function()
		local project_dir = build_config.get_macos_project_dir()
		if not utils.verify_directory(project_dir) then
			return
		end

		local app_name = build_config.get_application_name()
		if not app_name then
			return
		end

		if not xcodebuild(project_dir, app_name, "Debug") then
			return
		end

		local app_path = find_app_bundle(project_dir, app_name)
		if not app_path then
			return
		end

		launch_app(app_path)

		vim.wait(1000)

		local pid = get_pid_by_name(app_name)
		if not pid then
			vim.notify("Could not find running process for " .. app_name, vim.log.levels.ERROR)
			return
		end

		local binary_path = find_binary_in_app(app_path)
		attach_debugger(pid, binary_path, app_name)
	end)
end

function M.attach()
	utils.async(function()
		local app_name = build_config.get_application_name()
		if not app_name then
			return
		end

		local pid = get_pid_by_name(app_name)
		if not pid then
			vim.notify("Could not find running process for " .. app_name, vim.log.levels.ERROR)
			return
		end

		local project_dir = build_config.get_macos_project_dir()
		local app_path = find_app_bundle(project_dir, app_name)
		local binary_path = app_path and find_binary_in_app(app_path) or nil

		if not binary_path then
			binary_path = vim.fn.input("Binary path: ")
			if #binary_path == 0 then
				return
			end
		end

		attach_debugger(pid, binary_path, app_name)
	end)
end

return M
