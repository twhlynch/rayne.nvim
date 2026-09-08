local adb = require("rayne.adb")
local build_config = require("rayne.build_config")
local lldb = require("rayne.lldb")
local options = require("rayne.options")
local utils = require("rayne.utils")

local M = {}

local function find_jdk()
	-- try $JAVA_HOME first
	local java_home = vim.env.JAVA_HOME
	if java_home ~= nil then
		return java_home
	end

	-- then use first from java_home
	local jdk_path = vim.trim(vim.fn.system("/usr/libexec/java_home 2>/dev/null"))

	return #jdk_path ~= 0 and jdk_path or nil
end

local function pick_android_so(search_root)
	return utils.await(function(callback)
		utils.pick_files({
			source = "android_so",
			title = "Pick main .so for symbols",
			cmd = { "find", search_root, "-type", "f", "-iname", "*.so" },
			error = "No .so files found under " .. search_root,
		}, callback)
	end)
end

local function resolve_main_so()
	local main_lib_name = build_config.get_library_name()
	local so_search_root = build_config.get_so_search_root()

	if not main_lib_name then
		return pick_android_so(so_search_root)
	end

	local result = utils.find(main_lib_name, { directory = so_search_root, type = "f" })

	if #result == 0 then
		return pick_android_so(so_search_root)
	end
	if #result == 1 then
		return result[1]
	end

	-- prefer arm64 or aarch64 ABI
	for _, path in ipairs(result) do
		if path:match("arm64") or path:match("aarch64") then
			return path
		end
	end

	return pick_android_so(so_search_root)
end

local function run_gradle(project_dir, commands)
	return utils.await(function(done)
		local jdk_path = find_jdk()
		local java_env = jdk_path and "JAVA_HOME=" .. jdk_path .. " " or ""

		-- no-daemon since it can sometimes use a daemon of a different version
		local cmd = { "bash", "-c", java_env .. "cd " .. project_dir .. " && ./gradlew --no-daemon " .. table.concat(commands, " ") }

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

local function sync(project_dir)
	return run_gradle(project_dir, { "prepareKotlinBuildScriptModel" })
end

local function build_and_install(project_dir)
	return run_gradle(project_dir, { "assembleDebug", "installDebug" })
end

local function build(project_dir)
	return run_gradle(project_dir, { "assembleDebug" })
end

local function run_create_build_project(args)
	return utils.await(function(done)
		local jdk_path = find_jdk()
		local java_env = jdk_path and "JAVA_HOME=" .. jdk_path .. " " or ""

		local cmd = { "bash", "-c", java_env .. "python3 " .. table.concat(args, " ") }

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

local function setup_server_and_attach(pid)
	local package_name = build_config.get_package_name()
	local opts = options.get()
	local port = opts.android.forward_port

	-- Kill any existing server
	adb.kill_lldb_server()
	adb.remove_forward(port)
	vim.wait(300)

	-- Find lldb-server
	local lldb_server_path = lldb.find_server(opts.android.sdk_path)
	if not lldb_server_path then
		return
	end

	-- Start lldb-server (copies to app dir, runs with run-as)
	if not adb.start_lldb_server(package_name, port, lldb_server_path) then
		return
	end

	-- Wait for port to be ready
	if not adb.wait_for_port(port, 5000) then
		return
	end

	-- Find the .so for symbols
	local so_path = resolve_main_so()
	if not so_path then
		return
	end

	-- Attach via DAP
	lldb.attach_android({
		name = "Attach to Android native (" .. package_name .. ")",
		pid = tonumber(pid) or 0,
		port = port,
		program = so_path,
	})
end

local function get_clangd_compilation_database()
	local clangd_path = vim.fn.getcwd() .. "/.clangd"
	if vim.fn.filereadable(clangd_path) == 0 then
		return nil
	end

	local lines = vim.fn.readfile(clangd_path)
	for _, line in ipairs(lines) do
		local path = line:match("^%s*CompilationDatabase:%s*(.+)%s*$")
		if path then
			return path
		end
	end

	return nil
end

local function copy_compile_commands(project_dir)
	local results = utils.find("compile_commands.json", {
		directory = project_dir,
		type = "f",
	})

	if #results == 0 then
		return
	end

	local newest = results[1]
	for i = 2, #results do
		if vim.fn.getftime(results[i]) > vim.fn.getftime(newest) then
			newest = results[i]
		end
	end

	local cwd = vim.fn.getcwd()

	local dest_dir = get_clangd_compilation_database()
	if dest_dir then
		vim.fn.mkdir(dest_dir, "p")
	elseif vim.fn.isdirectory(cwd .. "/build") == 1 then
		dest_dir = cwd .. "/build"
	else
		dest_dir = cwd
	end

	local dest = dest_dir .. "/compile_commands.json"
	vim.fn.system({ "cp", newest, dest })
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

		local args = { script_path, build_config_path, "android", configuration or "oculus" }

		if not run_create_build_project(args) then
			vim.notify("Android project generation failed", vim.log.levels.ERROR)
			return
		end

		local project_dir = build_config.get_android_project_dir()
		if not utils.verify_directory(project_dir) then
			return
		end

		if not sync(project_dir) then
			vim.notify("Android project sync failed", vim.log.levels.ERROR)
			return
		end
	end)
end

function M.sync()
	utils.async(function()
		local project_dir = build_config.get_android_project_dir()
		if not utils.verify_directory(project_dir) then
			return
		end

		sync(project_dir)
	end)
end

function M.build()
	utils.async(function()
		local project_dir = build_config.get_android_project_dir()
		if not utils.verify_directory(project_dir) then
			return
		end

		if not build(project_dir) then
			return
		end

		copy_compile_commands(project_dir)
	end)
end

function M.build_install_launch()
	utils.async(function()
		local project_dir = build_config.get_android_project_dir()
		if not utils.verify_directory(project_dir) then
			return
		end

		local package_name = build_config.get_package_name()
		local native_activity = build_config.get_native_activity()

		if not build_and_install(project_dir) then
			return
		end

		copy_compile_commands(project_dir)

		if not adb.launch(package_name, native_activity) then
			return
		end
	end)
end

function M.build_install_launch_attach()
	utils.async(function()
		local project_dir = build_config.get_android_project_dir()
		if not utils.verify_directory(project_dir) then
			return
		end

		local package_name = build_config.get_package_name()
		local native_activity = build_config.get_native_activity()

		if not build_and_install(project_dir) then
			return
		end

		copy_compile_commands(project_dir)

		if not adb.launch(package_name, native_activity) then
			return
		end

		local pid = adb.wait_for_pid(package_name, 8000)
		if not pid then
			return
		end

		setup_server_and_attach(pid)
	end)
end

function M.attach()
	utils.async(function()
		local package_name = build_config.get_package_name()

		local pid = adb.get_pid(package_name)
		if not pid then
			return
		end

		setup_server_and_attach(pid)
	end)
end

return M
