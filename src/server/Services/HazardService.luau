--!strict
--[[
	HazardService — environmental danger: lava pools in the Lava Fields burn characters standing
	in them, and characters that fall off the floating island die (and respawn) once they drop
	below GameConfig.Hazards.VoidKillHeight. Position-based (tile lookup) instead of Touched
	events: cheap, deterministic, no per-part connections. Decisions live in HazardRules.
	Players are told why they died (and what it cost them) and warned while they burn.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Server = ServerScriptService.Server
local HazardRules = require(Server.Systems.Hazards.HazardRules)
local MapService = require(Server.Services.MapService)
local Notifier = require(Server.Systems.Notifier)
local ServerConfig = require(Server.ServerConfig)
local ShardService = require(Server.Services.ShardService)

local HazardService = {
	name = "HazardService",
}

-- os.clock() of the last "get out of the lava" warning, per player.
local lastBurnWarning: { [Player]: number } = {}

local function tick(dt: number)
	local hazards = GameConfig.Hazards
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			local position = root.Position
			local hazard = HazardRules.classify(position.Y, MapService.tileAt(position), hazards.VoidKillHeight)
			-- Read before the death: dying drops (or loses) every carried shard.
			local carrying = ShardService.getCarryCount(player)
			if hazard == "void" then
				-- Health = 0 rather than TakeDamage: a spawn ForceField must not save a falling player.
				humanoid.Health = 0
			elseif hazard == "lava" then
				humanoid:TakeDamage(hazards.LavaDamagePerSecond * dt)
				if humanoid.Health > 0 then
					local now = os.clock()
					if HazardRules.shouldWarnBurn(lastBurnWarning[player], now, hazards.BurnNoticeSeconds) then
						lastBurnWarning[player] = now
						Notifier.send(player, "🔥 Lava! Get out before you burn!", "error")
					end
				end
			end
			local notice = if humanoid.Health <= 0 then HazardRules.deathNotice(hazard, carrying) else nil
			if notice then
				Notifier.send(player, notice, "warning")
			end
		end
	end
end

function HazardService.init(_self: any)
	-- Nothing to prepare: lava tiles come from the map layout.
end

function HazardService.start(_self: any)
	Players.PlayerRemoving:Connect(function(player)
		lastBurnWarning[player] = nil
	end)
	local interval = ServerConfig.Gameplay.HazardTickSeconds
	while true do
		local dt = task.wait(interval)
		tick(dt)
	end
end

return HazardService
