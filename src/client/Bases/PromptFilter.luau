--!strict
--[[
	PromptFilter — hides ProximityPrompts on this client only, without losing the server's value.

	Why it exists: a client write to a replicated property sticks until the server changes that
	property again. A prompt hidden too early (the client boots before the plot's OwnerUserId has
	replicated, so every console looks foreign) would stay hidden forever unless it is explicitly
	restored — that is how players lost their own "Lock base" prompt. This module remembers the
	server value and restores it on `show`.

	API:
	  PromptFilter.shouldHide(promptName, isOwnPlot) -> boolean   pure rule (cosmetic only)
	  local filter = PromptFilter.new()
	  filter:hide(prompt)              keep Enabled = false locally (idempotent)
	  filter:show(prompt)              stop hiding, restore the last known server value
	  filter:onEnabledChanged(prompt)  call from prompt:GetPropertyChangedSignal("Enabled")
	  filter:isHidden(prompt) -> boolean
	  filter:forget(prompt)            drop tracking without touching the prompt (destroyed prompt)

	Signals are wired by the caller (BaseController), so this module runs headlessly.

	Limitation: while a prompt is hidden, a server change to `false` is invisible (the local value
	is already false), so `show` may restore a stale `true` — e.g. a Steal prompt on a pedestal
	that emptied meanwhile. Cosmetic only: the server validates every prompt trigger.
]]

local PromptFilter = {}
PromptFilter.__index = PromptFilter

export type PromptFilter = typeof(setmetatable(
	{} :: {
		-- Hidden prompt -> last known server value of Enabled.
		_serverEnabled: { [ProximityPrompt]: boolean },
	},
	PromptFilter
))

-- Steal on your own Starlings and Lock on someone else's console make no sense for this player.
function PromptFilter.shouldHide(promptName: string, isOwnPlot: boolean): boolean
	return (promptName == "StealPrompt" and isOwnPlot) or (promptName == "LockPrompt" and not isOwnPlot)
end

function PromptFilter.new(): PromptFilter
	return setmetatable({ _serverEnabled = {} }, PromptFilter)
end

function PromptFilter.isHidden(self: PromptFilter, prompt: ProximityPrompt): boolean
	return self._serverEnabled[prompt] ~= nil
end

function PromptFilter.hide(self: PromptFilter, prompt: ProximityPrompt)
	if self._serverEnabled[prompt] == nil then
		-- Not hidden yet: the current value is the server's.
		self._serverEnabled[prompt] = prompt.Enabled
	end
	prompt.Enabled = false
end

function PromptFilter.show(self: PromptFilter, prompt: ProximityPrompt)
	local serverEnabled = self._serverEnabled[prompt]
	if serverEnabled == nil then
		return
	end
	self._serverEnabled[prompt] = nil
	prompt.Enabled = serverEnabled
end

function PromptFilter.onEnabledChanged(self: PromptFilter, prompt: ProximityPrompt)
	if self._serverEnabled[prompt] ~= nil and prompt.Enabled then
		-- The server turned it on while we hide it: remember, and keep hiding.
		self._serverEnabled[prompt] = true
		prompt.Enabled = false
	end
end

function PromptFilter.forget(self: PromptFilter, prompt: ProximityPrompt)
	self._serverEnabled[prompt] = nil
end

return PromptFilter
