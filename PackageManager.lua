--[[
	@author: William J. Horn
	@written: 12/9/2024
	
	A super light-weight package manager for handling global dependency imports. This
	module mimmicks a weak version of CommonJS modules. 
	
	TODO:
		- add warning for if multiple instance names exist in a directory
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerService = game:GetService("Players")
local RunService = game:GetService("RunService")

local Path__Dependencies = ReplicatedStorage:WaitForChild("Dependencies")
local Path__UtilPackage = Path__Dependencies.Util

-- dependencies
local isString = require(Path__UtilPackage.Types.isString)()
local isTable = require(Path__UtilPackage.Types.isTable)()
local isInstance = require(Path__Dependencies.Util.Types.isInstance)()
--local Commands = require(Path__Dependencies.Commands)()

local PackageManager = {}

do
	-- ROOT IMPORT DIRECTORY --
	local rootDirectory = Path__Dependencies
	PackageManager._rootDirectory = rootDirectory
	
	-- package manager import commands
	--PackageManager.importCommands = Commands.new()
end


--do
--	-- DEFINE PACKAGE MANAGER IMPORT COMMANDS --
--	local importCommands = PackageManager.importCommands
	
--	importCommands:add("nocache", {
--		execute = function(package)
--			print("Nocache command called")
--		end,
--	})

--	importCommands:add("benchmark", {
--		execute = function(package)
--			print("Benchmark command called")
--		end,
--	})
--end

local function requireDirectory(directory, withoutDefault)
	if (not isInstance(directory)) then
		error("Could not require directory. Instance expected, got: \"" .. type(directory) .. "\"", 2)
	end
	
	-- case: directory is module:
	if (directory:IsA("ModuleScript")) then
		local package = require(directory)
		local packageIsTable = isTable(package)
		
		if (packageIsTable and not withoutDefault and package.default ~= nil) then
			return package.default
			
		elseif (packageIsTable and not withoutDefault) then
			error("Import failed. A default export was expected for package: \"" .. directory.Name .. "\"", 2)
		else
			
			return package
		end
	end
	
	-- case: directory is not module:
	local defaultExport = directory:FindFirstChild("default")

	assert(
		defaultExport and defaultExport:IsA("ModuleScript"), 
		"Failed to import from file: \"" .. directory.Name .. "\" (does not contain a default export module)"
	)

	return require(defaultExport)
end

local function requireAllChildren(dir)
	local package = {}

	for moduleName, module in next, dir:GetChildren() do
		if (module:IsA("ModuleScript")) then
			package[module.Name] = require(module)
		end 
	end

	return package
end

local function requireAllDescendants(dir)
	local package = {}

	return package
end

local function parsePathSegmentName(segment)
	local esc
	local mod

	segment, esc = segment:gsub("^@", "")
	segment, mod = segment:gsub("%*$", "")
	segment = segment:gsub("^%.$", "default")

	return segment, esc > 0, mod > 0
end

local function interpretPathSegment(segment)
	return {
		isBackDirectory = segment == "..",
		isAllChildren = segment == "*",
		isAllDescendants = segment == "**",
		isDefault = segment == "default"
	}
end

local function getPathLocation(dir, pathname)
	local dirIsRequired = isTable(dir)

	-- parse the path string
	for segment in pathname:gmatch("[^/]+") do
		local segmentName, requireIsEscaped, defaultIsEscaped = parsePathSegmentName(segment)
		print(segmentName, requireIsEscaped, defaultIsEscaped)
		
		-- DIRECTORY HAS BEEN REQUIRED BEYOND THIS POINT --
		if (dirIsRequired and dir[segment] ~= nil) then
			dir = dir[segment]
			continue
			
		elseif (dirIsRequired) then
			error("Path segment \"" .. segment .. "\" does not exist in directory", 2)
		end

		-- DIRECTORY HAS NOT BEEN REQUIRED YET BEYOND THIS POINT -- 
		local child = dir:FindFirstChild(segmentName)
		local segmentType = interpretPathSegment(segment)
		
		-- is escaping require by using "@"
		if (requireIsEscaped) then
			dir = child
			continue
		end

		-- back directory "../"
		if (segmentType.isBackDirectory and dir.Parent) then
			dir = dir.Parent
			continue
			
		elseif (segmentType.isBackDirectory) then
			error("Cannot cd to parent of: \"" .. tostring(dir) .. "\" (parent does not exist)", 2)
		end

		-- wild card "*"
		if (segmentType.isAllChildren) then
			dir = requireAllChildren(dir)
			continue
		end

		-- child not found in directory
		if (not child) then
			error("Import failed. Could not find path segment: \"" .. segmentName .. "\"", 2)
		end
		
		-- SEGMENT WAS SUCCESSFULLY REQUIRED -- 
		local requiredDirectory = requireDirectory(child, defaultIsEscaped)
		
		dirIsRequired = true
		dir = requiredDirectory
	end

	return dir
end

function PackageManager:import(location, ...)
	--local importCommands = self._importCommands
	local rootDirectory = self._rootDirectory
	
	local export = {}
	local importParams = {...}
	
	local cd = getPathLocation(rootDirectory, location)
	
	--if no import params are given, return the directory's default export
	if (#importParams == 0) then
		return cd
	end
	
	--if import params are given, return the file's export
	for _, param in next, importParams do
		if (not isString(param)) then
			error("Invalid import parameter. Got type: \"" .. typeof(param) .. "\" (expected string). Value: \"" .. tostring(param) .. "\"")
		end
		
		--if (importCommands:hasCommandPrefix(param)) then
		--	importCommands:run(param)
		--else
		--	export[#export + 1] = getPathLocation(cd, param)
		--end
		export[#export + 1] = getPathLocation(cd, param)
	end
	
	return unpack(export)
end

return PackageManager
