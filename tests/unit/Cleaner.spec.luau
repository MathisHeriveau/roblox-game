--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cleaner = require(ReplicatedStorage.Shared.Utils.Cleaner)

return function()
	describe("Cleaner", function()
		it("releases items in reverse order of addition", function()
			local cleaner = Cleaner.new()
			local order = {}
			cleaner:add(function()
				table.insert(order, 1)
			end)
			cleaner:add(function()
				table.insert(order, 2)
			end)
			cleaner:clean()
			expect(order[1]).to.equal(2)
			expect(order[2]).to.equal(1)
			expect(cleaner:count()).to.equal(0)
		end)

		it("destroys Instances", function()
			local cleaner = Cleaner.new()
			local container = Instance.new("Folder")
			local owned = Instance.new("Folder")
			owned.Parent = container
			cleaner:add(owned)
			cleaner:clean()
			-- Observed through the surviving parent: reading a destroyed Instance is runtime-specific.
			expect(#container:GetChildren()).to.equal(0)
			container:Destroy()
		end)

		it("calls disconnect/destroy on table resources and nested cleaners", function()
			local cleaner = Cleaner.new()
			local nested = Cleaner.new()
			local disconnected, destroyed, nestedCleaned = false, false, false
			cleaner:add({
				disconnect = function()
					disconnected = true
				end,
			})
			cleaner:add({
				Destroy = function()
					destroyed = true
				end,
			})
			nested:add(function()
				nestedCleaned = true
			end)
			cleaner:add(nested)
			cleaner:clean()
			expect(disconnected).to.equal(true)
			expect(destroyed).to.equal(true)
			expect(nestedCleaned).to.equal(true)
		end)

		it("keeps releasing remaining items when one fails", function()
			local cleaner = Cleaner.new()
			local released = false
			cleaner:add(function()
				released = true
			end)
			cleaner:add(function()
				error("boom")
			end)
			cleaner:clean()
			expect(released).to.equal(true)
		end)

		it("is reusable after clean()", function()
			local cleaner = Cleaner.new()
			local count = 0
			cleaner:add(function()
				count += 1
			end)
			cleaner:clean()
			cleaner:clean()
			cleaner:add(function()
				count += 1
			end)
			cleaner:clean()
			expect(count).to.equal(2)
		end)
	end)
end
