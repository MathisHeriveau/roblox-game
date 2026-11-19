--!strict
--[[
	LeaderstatsService — the in-game player list columns (Coins, Level, Rebirths).
	Roblox sorts the list by the first column.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ReplicatedStorage.Shared.Game.Economy)
local Server = ServerScriptService.Server
local PlayerDataSchema = require(Server.Systems.Persistence.PlayerDataSchema)
local PlayerDataService = require(Server.Services.PlayerDataService)

local LeaderstatsService = {
	name = "LeaderstatsService",
}

local function ensure(player: Player): Folder
	local existing = player:FindFirstChild("leaderstats")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in { "Coins", "Level", "Rebirths" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = folder
	end
	folder.Parent = player
	return folder
end

local function setValue(folder: Folder, name: string, value: number)
	local holder = folder:FindFirstChild(name)
	if holder and holder:IsA("IntValue") and holder.Value ~= value then
		holder.Value = value
	end
end

local function refresh(player: Player, data: PlayerDataSchema.PlayerData)
	local folder = ensure(player)
	local level = Economy.levelFromXp(data.xp)
	setValue(folder, "Coins", data.coins)
	setValue(folder, "Level", level)
	setValue(folder, "Rebirths", data.rebirths)
end

function LeaderstatsService.init(_self: any)
	-- Folders are created when players join.
end

function LeaderstatsService.start(_self: any)
	Players.PlayerAdded:Connect(ensure)
	for _, player in Players:GetPlayers() do
		ensure(player)
	end
	PlayerDataService.loaded:connect(refresh)
	PlayerDataService.changed:connect(refresh)
end

return LeaderstatsService
