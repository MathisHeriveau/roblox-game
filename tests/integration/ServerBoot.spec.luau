--!strict
--[[
	Integration (Studio only): the real server booted with the real engine.
	Skipped headlessly — Lune has no engine to run Scripts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local BOOT_TIMEOUT_SECONDS = 10

return function()
	describe("Server boot (Studio)", function()
		if __LUNE_RUNTIME__ then
			SKIP()
		end

		it("generates the map into Workspace", function()
			local map = Workspace:WaitForChild("Map", BOOT_TIMEOUT_SECONDS)
			expect(map).to.be.ok()
			expect((map :: Instance):FindFirstChild("SpawnLocation")).to.be.ok()
		end)

		it("creates every declared remote, and nothing else", function()
			local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName, BOOT_TIMEOUT_SECONDS) :: Folder
			expect(folder).to.be.ok()
			local declared = 0
			for name in Remotes.Definitions do
				declared += 1
				expect(folder:FindFirstChild(name)).to.be.ok()
			end
			expect(#folder:GetChildren()).to.equal(declared)
		end)

		it("keeps server-only modules out of replicated containers", function()
			expect(ReplicatedStorage:FindFirstChild("ServerConfig", true)).to.equal(nil)
			expect(ServerScriptService:FindFirstChild("ServerConfig", true)).to.be.ok()
		end)
	end)
end
