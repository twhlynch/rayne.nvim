local utils = require("rayne.utils")

local M = {}

--- @class Rayne.Manifest
--- @field ["RNApplication"] string | nil application name
--- @field ["RNSearchPaths"] string[] | nil resources directories
--- @field ["RNModules"] string[] | nil rayne module dependancies
--- @field ["RNPreferredTextureFileExtension~macos"] string | nil dds, astc
--- @field ["RNPreferredTextureFileExtension~windows"] string | nil
--- @field ["RNPreferredTextureFileExtension~linux"] string | nil
--- @field ["RNPreferredTextureFileExtension~android"] string | nil

--- @type Rayne.Manifest | nil
local manifest = nil

local manifest_file_name = "build-config.json"

function M.get_manifest_path()
	return vim.fn.getcwd() .. "/" .. manifest_file_name
end

function M.get_manifest()
	if manifest ~= nil then
		return manifest
	end

	local filepath = M.get_manifest_path()
	manifest = utils.load_json_file(filepath)

	return manifest
end

return M
