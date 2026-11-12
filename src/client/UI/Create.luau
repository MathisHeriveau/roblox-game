--!strict
--[[
	Create — declarative Instance construction for programmatic UI (and anything else).

	    local label = Create("TextLabel", {
	        Name = "Title",
	        Text = "Hello",
	        Size = UDim2.fromScale(1, 0.2),
	    }, {
	        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
	    })

	Properties are applied before children are parented; `Parent` (if given) is applied last so
	the finished tree replicates/renders in one step.
]]

local function Create(className: string, properties: { [string]: any }?, children: { any }?): Instance
	local instance = Instance.new(className)
	local parent: Instance? = nil

	if properties then
		for key, value in properties do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end

	if children then
		for index, child in children do
			assert(typeof(child) == "Instance", `Create: child #{index} is not an Instance`)
			child.Parent = instance
		end
	end

	if parent then
		instance.Parent = parent
	end
	return instance
end

return Create
