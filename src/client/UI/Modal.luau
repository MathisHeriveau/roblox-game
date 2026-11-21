--!strict
--[[
	Modal — at most one modal window (shop or a menu panel) is open at a time. Opening one closes
	the previous one, so panels never stack on the same DisplayOrder.

	A window calls `Modal.opened(id, close)` when it opens and `Modal.closed(id)` when it closes.
]]

local Modal = {}

local currentId: string? = nil
local currentClose: (() -> ())? = nil

function Modal.opened(id: string, close: () -> ())
	if currentId ~= nil and currentId ~= id then
		local previous = currentClose
		currentId, currentClose = nil, nil
		if previous then
			previous()
		end
	end
	currentId, currentClose = id, close
end

function Modal.closed(id: string)
	if currentId == id then
		currentId, currentClose = nil, nil
	end
end

function Modal.current(): string?
	return currentId
end

function Modal.closeAll()
	local close = currentClose
	currentId, currentClose = nil, nil
	if close then
		close()
	end
end

return table.freeze(Modal)
