--!strict
--[[
	Notifier — sends toast notifications to clients (Remotes.Notify). Server-only helper.

	Styles understood by the client: "info", "success", "warning", "error", "coins", "pickup",
	"rarity" (pass `rarity` to colour the toast with that rarity).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local ServerNet = require(ServerScriptService.Server.Systems.ServerNet)

export type Style = "info" | "success" | "warning" | "error" | "coins" | "pickup" | "rarity"

local Notifier = {}

function Notifier.send(player: Player, text: string, style: Style, rarity: number?)
	ServerNet.fireClient("Notify", player, { text = text, style = style, rarity = rarity })
end

function Notifier.broadcast(text: string, style: Style, rarity: number?)
	ServerNet.fireAllClients("Notify", { text = text, style = style, rarity = rarity })
end

return table.freeze(Notifier)
