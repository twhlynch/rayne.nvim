local build_config = require("rayne.build_config")
local utils = require("rayne.utils")

local M = {}

--- @class Rayne.OculusAppSecrets
--- @field app-id string | nil
--- @field secret string | nil

--- @class Rayne.BuildSecrets
--- @field keystore-password string | nil
--- @field keystore-key-password string | nil
--- @field oculus table<string, Rayne.OculusAppSecrets> | nil

--- @type Rayne.BuildSecrets | nil
local build_secrets = nil

local function get_build_secrets_path()
	local config = build_config.get_build_config()
	local relative = config and config["build-secrets"]
	if relative then
		return vim.fn.getcwd() .. "/" .. relative
	end

	return vim.fn.getcwd() .. "/Other/build-secrets.json"
end

--- @return Rayne.BuildSecrets | nil
function M.get_build_secrets()
	if build_secrets then
		return build_secrets
	end

	local filepath = get_build_secrets_path()
	build_secrets = utils.load_json_file(filepath)

	if not build_secrets then
		vim.notify("Could not load build secrets from " .. filepath, vim.log.levels.ERROR)
		return nil
	end

	return build_secrets
end

--- @return string | nil store_password
--- @return string | nil key_password
function M.get_keystore_passwords()
	local secrets = M.get_build_secrets()
	if not secrets then
		return nil, nil
	end

	local store_password = secrets["keystore-password"]
	local key_password = secrets["keystore-key-password"]

	if not store_password or store_password == "" then
		vim.notify("keystore-password not set in build secrets", vim.log.levels.ERROR)
		return nil, nil
	end

	if not key_password or key_password == "" then
		vim.notify("keystore-key-password not set in build secrets", vim.log.levels.ERROR)
		return nil, nil
	end

	return store_password, key_password
end

--- @param platform string
function M.get_oculus_app_secrets(platform)
	local oculus_secrets = (M.get_build_secrets() or {})["oculus"]

	if not oculus_secrets then
		vim.notify("oculus not set in build secrets", vim.log.levels.ERROR)
		return nil
	end

	local platform_secrets = oculus_secrets[platform]
	if not platform_secrets or not platform_secrets["app-id"] or not platform_secrets["secret"] then
		return nil
	end

	return platform_secrets
end

return M
