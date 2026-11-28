--!strict
--[[
	MenuController — the round icon buttons of the style sheet (left column under the coins, 3 x 2,
	UI/HudLayout) and their panels:

	  ⚙️ Settings   local toggles (sounds, effects, guide beam)
	  📊 Stats      lifetime progression from PlayerState
	  🎁 Gifts      7-day daily reward streak, CLAIM sends the ClaimDaily intent ("!" when ready)
	  🐾 Index      the 12 Starlings (6 rarities x shiny) as 3D models; silhouettes until found
	  🏆 Top        this server's raiders ranked by rebirths, level and coins (leaderstats)
	  📅 Events     live countdowns: meteor shower, comet, daily gift, raids

	Display only: rows come from MenuViews (pure) fed by server-sent state and replicated values;
	the server decides every reward. One modal at a time (UI/Modal).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClientNet = require(ReplicatedStorage.Shared.Net.ClientNet)
local Create = require(script.Parent.Parent.UI.Create)
local Format = require(ReplicatedStorage.Shared.Game.Format)
local HudLayout = require(script.Parent.Parent.UI.HudLayout)
local Layers = require(script.Parent.Parent.UI.Layers)
local MenuViews = require(script.Parent.Parent.Menu.MenuViews)
local Panel = require(script.Parent.Parent.UI.Components.Panel)
local PillButton = require(script.Parent.Parent.UI.Components.PillButton)
local PlayerStateTypes = require(ReplicatedStorage.Shared.Types.PlayerState)
local RoundButton = require(script.Parent.Parent.UI.Components.RoundButton)
local Settings = require(script.Parent.Parent.Settings)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local StarlingBuilder = require(ReplicatedStorage.Shared.Game.StarlingBuilder)
local StateController = require(script.Parent.StateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local TitleController = require(script.Parent.TitleController)

type PlayerState = PlayerStateTypes.PlayerState

local MenuController = {
	name = "MenuController",
}

type Entry = {
	panel: Panel.Panel,
	button: RoundButton.RoundButton,
	-- Redraws the panel; called on open, on state changes and every second while open.
	render: () -> (),
}

local railGui: ScreenGui
local railScale: UIScale
local entries: { [string]: Entry } = {}
local order: { string } = {}
local claimBusy = false

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function list(container: Instance, padding: number, horizontal: boolean?)
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, padding),
	}).Parent =
		container
end

local function dailyView(state: PlayerState): MenuViews.DailyView
	return MenuViews.daily(state.dailyNextClaimAt, state.dailyNextDay, state.incomePerSecond, serverNow())
end

--------------------------------------------------------------------------------------------------
-- 🐾 Starling Index
--------------------------------------------------------------------------------------------------

type IndexCard = {
	viewport: ViewportFrame,
	-- Soft glow behind undiscovered silhouettes (black on the dark card would vanish).
	spot: Frame,
	title: TextLabel,
	income: TextLabel,
	frame: Frame,
	stroke: UIStroke,
}

local function starlingViewport(rarity: number, shiny: boolean): ViewportFrame
	local viewport = Create("ViewportFrame", {
		Name = "Model",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 100),
		Ambient = Color3.fromRGB(200, 196, 220),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.3, -1, 0.5),
	}) :: ViewportFrame
	local model = StarlingBuilder.build(rarity, shiny, CFrame.new())
	-- Not a world Starling: keep AmbientController from animating it.
	CollectionService:RemoveTag(model, StarlingBuilder.TAG)
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	local center, size = model:GetBoundingBox()
	local distance = (size.Magnitude / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 0.92
	-- The Starling faces -Z: look at it from the front, slightly above and to the side.
	camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(0.18, 0.22, -1).Unit * distance, center.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

local function buildIndex(): Entry
	local panel = Panel.new("StarlingIndex", "STARLING INDEX", Vector2.new(820, 520))
	list(panel.body, 10)
	local summary = Panel.text({
		Name = "Summary",
		LayoutOrder = 1,
		Size = UDim2.new(1, -8, 0, 30),
		TextColor3 = Theme.Color.TextDim,
	})
	summary.Parent = panel.body

	local grid = Create("Frame", {
		Name = "Grid",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(116, 160),
			CellPadding = UDim2.fromOffset(10, 10),
			FillDirectionMaxCells = 6,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame
	grid.Parent = panel.body

	local cards: { [string]: IndexCard } = {}
	for position, entry in MenuViews.index({}).entries do
		local viewport = starlingViewport(entry.rarity, entry.shiny)
		local title = Panel.text({
			Name = "Title",
			Position = UDim2.fromOffset(4, 102),
			Size = UDim2.new(1, -8, 0, 24),
			Font = Theme.Font.Title,
		})
		local income = Panel.text({
			Name = "Income",
			Position = UDim2.fromOffset(4, 128),
			Size = UDim2.new(1, -8, 0, 20),
		}, 1.5)
		local spot = Create("Frame", {
			Name = "Spot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 50),
			Size = UDim2.fromOffset(84, 84),
			BackgroundColor3 = Theme.Color.Purple,
			BackgroundTransparency = 0.55,
			ZIndex = 0,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Create("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new(0, 0.6),
			}),
		}) :: Frame
		local frame = Create("Frame", {
			Name = entry.key,
			LayoutOrder = position,
			BackgroundColor3 = Theme.Color.PanelDark,
		}, { spot :: Instance, viewport, title, income }) :: Frame
		Theme.corner(frame, 16)
		local stroke = Theme.border(frame, 3)
		if entry.shiny then
			local tag = Panel.text({
				Name = "Shiny",
				Position = UDim2.fromOffset(84, 4),
				Size = UDim2.fromOffset(28, 28),
				Text = "✨",
			}, 0)
			tag.Parent = frame
		end
		frame.Parent = grid
		cards[entry.key] =
			{ viewport = viewport, spot = spot, title = title, income = income, frame = frame, stroke = stroke }
	end

	local function render()
		local state = StateController.get()
		local view = MenuViews.index(if state then state.discovered else {})
		summary.Text =
			`🐾 {view.count} / {view.size} discovered  •  +{view.bonusPercent}% income forever  •  Deliver new kinds of shards to fill it!`
		for _, entry in view.entries do
			local card = cards[entry.key]
			card.spot.Visible = not entry.discovered
			if entry.discovered then
				card.viewport.ImageColor3 = Color3.new(1, 1, 1)
				card.viewport.ImageTransparency = 0
				card.title.Text = entry.name
				card.title.TextColor3 = entry.color
				card.income.Text = `💰 +{Format.compact(entry.income)}/s`
				card.income.TextColor3 = Theme.Color.Income
				card.stroke.Color = entry.color
				card.frame.BackgroundColor3 = Theme.Color.PanelDark:Lerp(entry.color, 0.22)
			else
				-- Silhouette: the shape (and accessory) is a hint, not the colours.
				card.viewport.ImageColor3 = Color3.new(0, 0, 0)
				card.viewport.ImageTransparency = 0.1
				card.title.Text = "???"
				card.title.TextColor3 = Theme.Color.TextDim
				card.income.Text = if entry.shiny then "Find a shiny!" else "Not found yet"
				card.income.TextColor3 = Theme.Color.TextDim
				card.stroke.Color = Theme.Color.Outline
				card.frame.BackgroundColor3 = Theme.Color.PanelDark
			end
		end
	end

	return {
		panel = panel,
		button = RoundButton.new("Index", "🐾", "INDEX", Theme.Color.Purple, Theme.Color.PurpleDark),
		render = render,
	}
end

--------------------------------------------------------------------------------------------------
-- 🎁 Daily gifts
--------------------------------------------------------------------------------------------------

local function buildDaily(): Entry
	local panel = Panel.new("DailyGifts", "DAILY GIFTS", Vector2.new(820, 440))
	list(panel.body, 14)

	local row = Create("Frame", {
		Name = "Days",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 168),
	}) :: Frame
	list(row, 8, true)
	row.Parent = panel.body

	type DayCard = { frame: Frame, stroke: UIStroke, gradient: UIGradient, reward: TextLabel, check: TextLabel }
	local dayCards: { DayCard } = {}
	for day = 1, 7 do
		local icon = Panel.text({
			Name = "Icon",
			Position = UDim2.fromOffset(16, 36),
			Size = UDim2.fromOffset(68, 64),
			Text = if day == 7 then "👑" else "🎁",
		}, 0)
		local title = Panel.text({
			Name = "Day",
			Position = UDim2.fromOffset(6, 8),
			Size = UDim2.new(1, -12, 0, 26),
			Font = Theme.Font.Title,
			Text = `DAY {day}`,
		})
		local reward = Panel.text({
			Name = "Reward",
			Position = UDim2.fromOffset(6, 108),
			Size = UDim2.new(1, -12, 0, 24),
			TextColor3 = Theme.Color.Gold,
		})
		local check = Panel.text({
			Name = "Check",
			Visible = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(70, 70),
			Font = Theme.Font.Title,
			Text = "✔",
			TextColor3 = Theme.Color.Green,
		}, 3)
		local frame = Create("Frame", {
			Name = `Day{day}`,
			LayoutOrder = day,
			Size = UDim2.fromOffset(100, 150),
			BackgroundColor3 = Color3.new(1, 1, 1),
		}, { icon :: Instance, title, reward, check }) :: Frame
		Theme.corner(frame, 16)
		local stroke = Theme.border(frame, 3)
		local gradient = Theme.gradient(frame, Theme.Color.Panel, Theme.Color.PanelDark)
		frame.Parent = row
		table.insert(dayCards, { frame = frame, stroke = stroke, gradient = gradient, reward = reward, check = check })
	end

	local claim = PillButton.new("🎁", "CLAIM!", Theme.Color.Green, Theme.Color.GreenDark, Vector2.new(320, 72))
	claim.root.LayoutOrder = 2
	claim.root.Parent = panel.body
	local message = Panel.text({
		Name = "Message",
		LayoutOrder = 3,
		Size = UDim2.new(1, -8, 0, 26),
		Text = "Come back every day: the streak grows to day 7 (triple reward). Missing a day resets it.",
		TextColor3 = Theme.Color.TextDim,
	})
	message.Parent = panel.body

	local function render()
		local state = StateController.get()
		if state == nil then
			return
		end
		local view = dailyView(state)
		for index, info in view.days do
			local card = dayCards[index]
			card.reward.Text = `💰 {Format.compact(info.reward)}`
			card.check.Visible = info.status == "claimed"
			-- Gold text on the gold "next" card would blend in.
			card.reward.TextColor3 = if info.status == "next" then Theme.Color.Text else Theme.Color.Gold
			if info.status == "next" then
				card.gradient.Color = ColorSequence.new(Theme.Color.Gold, Theme.Color.GoldDark)
				card.stroke.Color = Color3.new(1, 1, 1)
				card.stroke.Thickness = 4
			else
				card.gradient.Color = ColorSequence.new(Theme.Color.Panel, Theme.Color.PanelDark)
				card.stroke.Color = Theme.Color.Outline
				card.stroke.Thickness = 3
			end
		end
		if view.ready then
			claim.setColors(Theme.Color.Green, Theme.Color.GreenDark)
			claim.setText(`CLAIM DAY {view.nextDay}!`)
		else
			claim.setColors(Theme.Color.Grey, Theme.Color.GreyDark)
			claim.setText(`NEXT IN {Format.duration(view.waitSeconds)}`)
		end
	end

	claim.root.Activated:Connect(function()
		local state = StateController.get()
		if claimBusy or state == nil or not dailyView(state).ready then
			return
		end
		claimBusy = true
		Sfx.play(Sfx.CLICK, 0.5)
		local ok, result = ClientNet.invoke("ClaimDaily")
		claimBusy = false
		if ok and type(result) == "table" and type(result.message) == "string" then
			message.Text = result.message
			message.TextColor3 = if result.ok then Theme.Color.Gold else Theme.Color.Red
		else
			message.Text = "The gift box is stuck, try again in a moment."
			message.TextColor3 = Theme.Color.Red
		end
		render()
	end)

	return {
		panel = panel,
		button = RoundButton.new("Gifts", "🎁", "GIFTS", Theme.Color.Gold, Theme.Color.GoldDark),
		render = render,
	}
end

--------------------------------------------------------------------------------------------------
-- 📊 Stats
--------------------------------------------------------------------------------------------------

local function statRow(row: MenuViews.StatRow, position: number): Frame
	local card = Panel.card(44, position)
	Panel.text({
		Name = "Icon",
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.fromOffset(32, 32),
		Text = row.icon,
	}, 0).Parent =
		card
	Panel.text({
		Name = "Label",
		Position = UDim2.fromOffset(52, 9),
		Size = UDim2.new(0.6, -52, 0, 26),
		Text = row.label,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent =
		card
	Panel.text({
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.new(0.4, -14, 0, 28),
		Font = Theme.Font.Title,
		Text = row.value,
		TextColor3 = Theme.Color.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
	}).Parent =
		card
	return card
end

local function buildStats(): Entry
	local panel = Panel.new("Stats", "MY STATS", Vector2.new(560, 620))
	list(panel.body, 8)
	local function render()
		local state = StateController.get()
		if state == nil then
			return
		end
		clear(panel.body)
		for index, row in MenuViews.stats(state) do
			statRow(row, index).Parent = panel.body
		end
	end
	return {
		panel = panel,
		button = RoundButton.new("Stats", "📊", "STATS", Theme.Color.Blue, Theme.Color.BlueDark),
		render = render,
	}
end

--------------------------------------------------------------------------------------------------
-- 🏆 Leaderboard (this server)
--------------------------------------------------------------------------------------------------

local function leaderstat(player: Player, name: string): number
	local folder = player:FindFirstChild("leaderstats")
	local holder = folder and folder:FindFirstChild(name)
	if holder and holder:IsA("IntValue") then
		return holder.Value
	end
	return 0
end

local function buildLeaderboard(): Entry
	local panel = Panel.new("Leaderboard", "TOP RAIDERS", Vector2.new(640, 560))
	list(panel.body, 8)
	local function render()
		local inputs: { MenuViews.LeaderInput } = {}
		for _, player in Players:GetPlayers() do
			table.insert(inputs, {
				name = player.DisplayName,
				coins = leaderstat(player, "Coins"),
				level = leaderstat(player, "Level"),
				rebirths = leaderstat(player, "Rebirths"),
				isLocal = player == Players.LocalPlayer,
			})
		end
		clear(panel.body)
		Panel.text({
			Name = "Hint",
			LayoutOrder = 0,
			Size = UDim2.new(1, -8, 0, 24),
			Text = "This server, ranked by rebirths, then level, then coins",
			TextColor3 = Theme.Color.TextDim,
		}).Parent =
			panel.body
		for _, row in MenuViews.leaderboard(inputs) do
			local card = Panel.card(52, row.rank)
			if row.isLocal then
				card.BackgroundColor3 = Theme.Color.PanelDark:Lerp(Theme.Color.Gold, 0.25)
			end
			Panel.text({
				Name = "Medal",
				Position = UDim2.fromOffset(8, 6),
				Size = UDim2.fromOffset(46, 40),
				Font = Theme.Font.Title,
				Text = row.medal,
			}).Parent =
				card
			Panel.text({
				Name = "Name",
				Position = UDim2.fromOffset(62, 12),
				Size = UDim2.new(0.45, -62, 0, 28),
				-- DisplayName is already filtered by Roblox; never RichText.
				Text = if row.isLocal then `{row.name} (you)` else row.name,
				TextColor3 = if row.isLocal then Theme.Color.Gold else Theme.Color.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
			}).Parent =
				card
			Panel.text({
				Name = "Score",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 12),
				Size = UDim2.new(0.55, -14, 0, 28),
				Text = `🌟 {row.rebirths}   ⭐ {row.level}   💰 {Format.compact(row.coins)}`,
				TextXAlignment = Enum.TextXAlignment.Right,
			}).Parent =
				card
			card.Parent = panel.body
		end
	end
	return {
		panel = panel,
		button = RoundButton.new("Top", "🏆", "TOP", Theme.Color.Navy, Theme.Color.NavyDark),
		render = render,
	}
end

--------------------------------------------------------------------------------------------------
-- 📅 Events
--------------------------------------------------------------------------------------------------

local function secondsUntil(attribute: string): number?
	local at = Workspace:GetAttribute(attribute)
	if type(at) ~= "number" then
		return nil
	end
	return at - serverNow()
end

local function buildEvents(): Entry
	local panel = Panel.new("Events", "EVENTS", Vector2.new(680, 560))
	list(panel.body, 10)
	local function render()
		local state = StateController.get()
		if state == nil then
			return
		end
		local zone = Workspace:GetAttribute("CometZone")
		local rows = MenuViews.events(
			secondsUntil("NextMeteorAt"),
			secondsUntil("NextCometAt"),
			if type(zone) == "string" then zone else nil,
			dailyView(state)
		)
		clear(panel.body)
		for index, row in rows do
			local card = Panel.card(96, index)
			Panel.text({
				Name = "Icon",
				Position = UDim2.fromOffset(12, 18),
				Size = UDim2.fromOffset(60, 60),
				Text = row.icon,
			}, 0).Parent =
				card
			Panel.text({
				Name = "Title",
				Position = UDim2.fromOffset(84, 10),
				Size = UDim2.new(0.62, -84, 0, 30),
				Font = Theme.Font.Title,
				Text = row.title,
				TextColor3 = Theme.Color.Gold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}).Parent =
				card
			Panel.text({
				Name = "Detail",
				Position = UDim2.fromOffset(84, 44),
				Size = UDim2.new(0.68, -84, 0, 42),
				Text = row.detail,
				TextColor3 = Theme.Color.TextDim,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}, 1).Parent =
				card
			local status = Panel.text({
				Name = "Status",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(170, 46),
				BackgroundTransparency = 0,
				BackgroundColor3 = if row.seconds ~= nil and row.seconds > 0
					then Theme.Color.Navy
					else Theme.Color.GreenDark,
				Font = Theme.Font.Title,
				Text = row.status,
			})
			Theme.corner(status, 14)
			Theme.border(status, 2)
			Theme.padding(status, 8)
			status.Parent = card
			card.Parent = panel.body
		end
	end
	return {
		panel = panel,
		button = RoundButton.new("Events", "📅", "EVENTS", Theme.Color.Blue, Theme.Color.BlueDark),
		render = render,
	}
end

--------------------------------------------------------------------------------------------------
-- ⚙️ Settings
--------------------------------------------------------------------------------------------------

local function buildSettings(): Entry
	local panel = Panel.new("Settings", "SETTINGS", Vector2.new(600, 400))
	list(panel.body, 10)
	type Toggle = { key: Settings.Key, button: TextButton, gradient: UIGradient }
	local toggles: { Toggle } = {}
	for index, info in Settings.LABELS do
		local card = Panel.card(64, index)
		local label = Panel.text({
			Name = "Label",
			Position = UDim2.fromOffset(16, 16),
			Size = UDim2.new(1, -170, 0, 32),
			Text = info.label,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		-- Same size on every row: short labels would otherwise scale up to fill the height.
		Create("UITextSizeConstraint", { MaxTextSize = 20 }).Parent = label
		label.Parent = card
		local button = Create("TextButton", {
			Name = "Toggle",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(120, 46),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Font = Theme.Font.Title,
			TextColor3 = Theme.Color.Text,
			TextScaled = true,
		}) :: TextButton
		Theme.corner(button, 14)
		Theme.border(button, 3)
		Theme.textOutline(button, 2)
		Theme.padding(button, 8)
		local gradient = Theme.gradient(button, Theme.Color.Green, Theme.Color.GreenDark)
		button.Activated:Connect(function()
			Settings.toggle(info.key)
			Sfx.play(Sfx.CLICK, 0.4)
		end)
		button.Parent = card
		card.Parent = panel.body
		table.insert(toggles, { key = info.key, button = button, gradient = gradient })
	end
	local function render()
		for _, toggle in toggles do
			local on = Settings.get(toggle.key)
			toggle.button.Text = if on then "ON" else "OFF"
			toggle.gradient.Color = if on
				then ColorSequence.new(Theme.Color.Green, Theme.Color.GreenDark)
				else ColorSequence.new(Theme.Color.Grey, Theme.Color.GreyDark)
		end
	end
	Settings.changed:connect(function()
		render()
	end)
	return {
		panel = panel,
		button = RoundButton.new("Settings", "⚙️", "SETTINGS", Theme.Color.Navy, Theme.Color.NavyDark),
		render = render,
	}
end

--------------------------------------------------------------------------------------------------

local function refreshBadges()
	local state = StateController.get()
	local gifts = entries.Gifts
	if gifts then
		gifts.button.setBadge(state ~= nil and dailyView(state).ready)
	end
end

local function toggle(id: string)
	local entry = entries[id]
	Sfx.play(Sfx.CLICK, 0.4)
	if entry.panel.isOpen() then
		entry.panel.close()
	else
		entry.render()
		entry.panel.open()
	end
end

function MenuController.isAnyOpen(): boolean
	for _, entry in entries do
		if entry.panel.isOpen() then
			return true
		end
	end
	return false
end

function MenuController.init(_self: any)
	-- Grid order follows the style sheet: ⚙️ 📊 🎁 / 🐾 🏆 📅.
	local built = {
		{ id = "Settings", entry = buildSettings() },
		{ id = "Stats", entry = buildStats() },
		{ id = "Gifts", entry = buildDaily() },
		{ id = "Index", entry = buildIndex() },
		{ id = "Top", entry = buildLeaderboard() },
		{ id = "Events", entry = buildEvents() },
	}
	railScale = Instance.new("UIScale")
	local rail = Create("Frame", {
		Name = "Rail",
		BackgroundTransparency = 1,
		Position = HudLayout.railPosition(),
		Size = UDim2.fromOffset(3 * 70 + 2 * 6, HudLayout.RAIL_HEIGHT),
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(70, 82),
			CellPadding = UDim2.fromOffset(6, 6),
			FillDirectionMaxCells = 3,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame
	for index, item in built do
		local id = item.id
		entries[id] = item.entry
		table.insert(order, id)
		item.entry.button.root.LayoutOrder = index
		item.entry.button.root.Parent = rail
		item.entry.button.button.Activated:Connect(function()
			toggle(id)
		end)
		Panel.connect(item.entry.panel)
	end
	railGui = Create("ScreenGui", {
		Name = "Menu",
		ResetOnSpawn = false,
		DisplayOrder = Layers.Hud,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	}, { railScale :: Instance, rail }) :: ScreenGui
	TitleController.hideWhileShowing(railGui)

	StateController.changed:connect(function()
		refreshBadges()
		for _, id in order do
			local entry = entries[id]
			if entry.panel.isOpen() then
				entry.render()
			end
		end
	end)
end

function MenuController.start(_self: any)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	railGui.Parent = playerGui
	for _, id in order do
		entries[id].panel.gui.Parent = playerGui
	end
	local camera = Workspace.CurrentCamera
	if camera then
		local function rescale()
			local value = Theme.scaleFor(camera.ViewportSize)
			railScale.Scale = value
			for _, entry in entries do
				local frame = entry.panel.gui:FindFirstChild("Panel")
				local panelScale = frame and frame:FindFirstChild("Scale")
				if panelScale and panelScale:IsA("UIScale") then
					panelScale.Scale = value
				end
			end
		end
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		rescale()
	end

	-- Countdowns (daily gift, events, leaderboard values) tick while a panel is open.
	while true do
		refreshBadges()
		for _, id in { "Gifts", "Events", "Top" } do
			local entry = entries[id]
			if entry.panel.isOpen() then
				entry.render()
			end
		end
		task.wait(1)
	end
end

return MenuController
