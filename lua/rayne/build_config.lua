local utils = require("rayne.utils")

local M = {}

--- @class Rayne.PermissionImpl
--- @field type string | nil
--- @field name string | nil
--- @field required boolean | nil
---
--- @alias Rayne.Permission Rayne.PermissionImpl | string

--- @class Rayne.Dependency
--- @field type string | nil
--- @field name string | nil
--- @field path string | nil

--- @class Rayne.BuildConfig
--- @field ["bundle-id"] string bundle id like com.example.app
--- @field ["name"] string application name
--- @field ["name-demo"] string | nil
--- @field ["build-directory"] string | nil Builds
--- @field ["release-directory"] string | nil
--- @field ["changelog"] string | nil
--- @field ["cmake-build-type"] string | nil
--- @field ["cmake-parameters"] string | nil
--- @field ["cmake-targets~android"] string[] | nil usually Rayne, RayneX, Vendor, Project
--- @field ["permissions~android"] Rayne.Permission[] | nil
--- @field ["android-custom-native-activity"] string | nil path/___NativeActivity.java
--- @field ["android-dependencies"] Rayne.Dependency[] | nil
--- @field ["sdk-version-target~android"] string | nil
--- @field ["sdk-version-min~android"] string | nil
--- @field ["icons~android"] string | nil
--- @field ["keystore~android"] string | nil
--- @field ["build-secrets"] string | nil
--- @field ["dependencies"] Rayne.Dependency[] | nil

--- @type Rayne.BuildConfig | nil
local build_config = nil

local config_file_name = "build-config.json"

local function get_build_config_path()
	return vim.fn.getcwd() .. "/" .. config_file_name
end

local function validate()
	if build_config == nil then
		return false
	end

	local required = {
		"bundle-id",
		"name",
	}

	for _, key in ipairs(required) do
		if build_config[key] == nil then
			vim.notify("build-config.json missing " .. key, vim.log.levels.ERROR)
			return false
		end
	end

	return true
end

function M.get_build_config()
	if build_config ~= nil then
		return build_config
	end

	local filepath = get_build_config_path()
	build_config = utils.load_json_file(filepath)

	if not validate() then
		build_config = nil
	end

	return build_config
end

--- @param absolute boolean
function M.get_build_directory(absolute)
	local dir = (M.get_build_config() or {})["build-directory"] or "Builds"
	return absolute and (vim.fn.getcwd() .. "/" .. dir) or dir
end

function M.get_package_name()
	return (M.get_build_config() or {})["bundle-id"]
end

function M.get_native_activity()
	local activity = (M.get_build_config() or {})["android-custom-native-activity"]

	if activity then
		return "." .. vim.fn.fnamemodify(activity, ":t:r")
	end

	return ".NativeActivity"
end

function M.get_application_name()
	return (M.get_build_config() or {})["name"]
end

function M.get_library_name()
	return "lib" .. M.get_application_name() .. ".so"
end

function M.get_android_project_dir()
	return M.get_build_directory(true) .. "/android_oculus"
end

function M.get_macos_project_dir()
	return M.get_build_directory(true) .. "/macos_independent"
end

function M.get_so_search_root()
	return M.get_android_project_dir() .. "/app/build/intermediates/cxx/Debug"
end

return M
