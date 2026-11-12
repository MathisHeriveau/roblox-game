--!strict
--[[
	Cleaner — collects resources and releases them together (prevents memory leaks).

	    local cleaner = Cleaner.new()
	    cleaner:add(part.Touched:Connect(onTouched))
	    cleaner:add(gui)                       -- Instance: destroyed
	    cleaner:add(function() ... end)        -- function: called
	    cleaner:add(signalConnection)          -- anything with :disconnect()/:Disconnect()/:destroy()/:Destroy()
	    cleaner:clean()                        -- releases everything, last added first

	Every controller/service/component that connects to events should own a Cleaner.
]]

local Cleaner = {}
Cleaner.__index = Cleaner

export type Cleaner = typeof(setmetatable({} :: { _items: { any }, _cleaning: boolean }, Cleaner))

function Cleaner.new(): Cleaner
	return setmetatable({ _items = {}, _cleaning = false }, Cleaner)
end

local function release(item: any)
	local kind = typeof(item)
	if kind == "function" then
		item()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" then
			pcall(task.cancel, item)
		end
	elseif kind == "table" then
		if type(item.disconnect) == "function" then
			item:disconnect()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif type(item.destroy) == "function" then
			item:destroy()
		elseif type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.clean) == "function" then
			item:clean()
		else
			error("Cleaner: table item has no disconnect/destroy/clean method")
		end
	else
		error(`Cleaner: cannot clean value of type {kind}`)
	end
end

function Cleaner.add<T>(self: Cleaner, item: T): T
	assert(not self._cleaning, "Cleaner: cannot add items while cleaning")
	assert(item ~= nil, "Cleaner: cannot add nil")
	table.insert(self._items, item)
	return item
end

function Cleaner.clean(self: Cleaner)
	if self._cleaning then
		return
	end
	self._cleaning = true
	local items = self._items
	self._items = {}
	for index = #items, 1, -1 do
		local ok, err = pcall(release :: any, items[index])
		if not ok then
			warn(`Cleaner: failed to release item: {err}`)
		end
	end
	self._cleaning = false
end

-- Alias so a Cleaner can itself be added to another Cleaner.
Cleaner.destroy = Cleaner.clean

function Cleaner.count(self: Cleaner): number
	return #self._items
end

return Cleaner
