--!strict
--[[
	Integration (Studio only): the real server booted with the real engine.
	Skipped headlessly — Lune has no engine to run Scripts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local BOOT_TIMEOUT_SECONDS = 15

return function()
	describe("Server boot (Studio)", function()
		if __LUNE_RUNTIME__ then
			SKIP()
		end

		it("builds the island, the bases and the shard container", function()
			expect(Workspace:WaitForChild("Map", BOOT_TIMEOUT_SECONDS)).to.be.ok()
			local bases = Workspace:WaitForChild("Bases", BOOT_TIMEOUT_SECONDS) :: Folder
			expect(#bases:GetChildren()).to.equal(GameConfig.Base.PlotCount)
			expect(Workspace:WaitForChild("Shards", BOOT_TIMEOUT_SECONDS)).to.be.ok()
		end)

		it("creates every declared remote, and nothing else", function()
			local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName, BOOT_TIMEOUT_SECONDS) :: Folder
			local declared = 0
			for name in Remotes.Definitions do
				declared += 1
				expect(folder:WaitForChild(name, BOOT_TIMEOUT_SECONDS)).to.be.ok()
			end
			expect(#folder:GetChildren()).to.equal(declared)
		end)

		it("schedules sky events", function()
			task.wait(1)
			expect(type(Workspace:GetAttribute("NextMeteorAt"))).to.equal("number")
			expect(type(Workspace:GetAttribute("NextCometAt"))).to.equal("number")
		end)

		it("keeps server-only modules out of replicated containers", function()
			expect(ReplicatedStorage:FindFirstChild("ServerConfig", true)).to.equal(nil)
			expect(ServerScriptService:FindFirstChild("ServerConfig", true)).to.be.ok()
		end)
	end)
end
