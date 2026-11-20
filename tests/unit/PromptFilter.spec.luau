--!strict
--[[
	PromptFilter: client-only prompt hiding that never loses the server's value.

	Regression: BaseController hid every "Lock base" prompt before the player's plot owner had
	replicated, then "released" the player's own prompt without restoring Enabled. The server
	never toggles that prompt again, so the local `false` stuck and players could not lock their
	base for the whole session.
]]

local StarterPlayer = game:GetService("StarterPlayer")

local PromptFilter = require(StarterPlayer.StarterPlayerScripts.Client.Bases.PromptFilter)

local function prompt(name: string, enabled: boolean): ProximityPrompt
	local instance = Instance.new("ProximityPrompt")
	instance.Name = name
	instance.Enabled = enabled
	return instance
end

-- Simulates the server replicating a new value: the property changes, then the signal fires.
local function replicate(filter: PromptFilter.PromptFilter, instance: ProximityPrompt, enabled: boolean)
	if instance.Enabled ~= enabled then
		instance.Enabled = enabled
		filter:onEnabledChanged(instance)
	end
end

return function()
	describe("PromptFilter.shouldHide", function()
		it("hides Steal on your own plot and Lock on other plots", function()
			expect(PromptFilter.shouldHide("StealPrompt", true)).to.equal(true)
			expect(PromptFilter.shouldHide("StealPrompt", false)).to.equal(false)
			expect(PromptFilter.shouldHide("LockPrompt", true)).to.equal(false)
			expect(PromptFilter.shouldHide("LockPrompt", false)).to.equal(true)
			expect(PromptFilter.shouldHide("SomethingElse", false)).to.equal(false)
		end)
	end)

	describe("PromptFilter", function()
		it("restores the server value when a prompt hidden too early is shown (join race)", function()
			local filter = PromptFilter.new()
			local lock = prompt("LockPrompt", true)
			-- Client boots before OwnerUserId replicates: every console looks foreign.
			filter:hide(lock)
			expect(lock.Enabled).to.equal(false)
			-- Owner replicates: it is ours after all.
			filter:show(lock)
			expect(lock.Enabled).to.equal(true)
			expect(filter:isHidden(lock)).to.equal(false)
		end)

		it("keeps a hidden prompt hidden when the server enables it, and remembers that value", function()
			local filter = PromptFilter.new()
			local steal = prompt("StealPrompt", false)
			filter:hide(steal)
			replicate(filter, steal, true)
			expect(steal.Enabled).to.equal(false)
			filter:show(steal)
			expect(steal.Enabled).to.equal(true)
		end)

		it("restores a server-disabled prompt as disabled", function()
			local filter = PromptFilter.new()
			local steal = prompt("StealPrompt", false)
			filter:hide(steal)
			filter:show(steal)
			expect(steal.Enabled).to.equal(false)
		end)

		it("is idempotent and ignores prompts it never hid", function()
			local filter = PromptFilter.new()
			local lock = prompt("LockPrompt", true)
			filter:hide(lock)
			filter:hide(lock)
			filter:show(lock)
			expect(lock.Enabled).to.equal(true)
			filter:show(lock)
			expect(lock.Enabled).to.equal(true)

			local untouched = prompt("LockPrompt", false)
			filter:show(untouched)
			filter:onEnabledChanged(untouched)
			expect(untouched.Enabled).to.equal(false)
		end)

		it("stops tracking prompts on forget (destroyed plots)", function()
			local filter = PromptFilter.new()
			local lock = prompt("LockPrompt", true)
			filter:hide(lock)
			filter:forget(lock)
			expect(filter:isHidden(lock)).to.equal(false)
			lock.Enabled = true
			filter:onEnabledChanged(lock)
			expect(lock.Enabled).to.equal(true)
		end)
	end)
end
