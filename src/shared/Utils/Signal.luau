--!strict
--[[
	Signal — minimal pure-Luau event emitter for in-process communication between modules.

	Use it for server→server or client→client events. For client↔server communication use the
	Net layer (RemoteEvents) instead. Handlers run synchronously, in connection order; a handler
	that errors does not prevent the others from running.
]]

export type Connection = {
	connected: boolean,
	disconnect: (self: Connection) -> (),
}

local Signal = {}
Signal.__index = Signal

type Handler<T...> = (T...) -> ()

type ConnectionImpl = {
	connected: boolean,
	disconnect: (self: ConnectionImpl) -> (),
	_handler: (...any) -> (),
}

export type Signal<T...> = {
	connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	fire: (self: Signal<T...>, T...) -> (),
	disconnectAll: (self: Signal<T...>) -> (),
}

local function disconnect(self: ConnectionImpl)
	self.connected = false
end

function Signal.new<T...>(): Signal<T...>
	local connections: { ConnectionImpl } = {}
	local signal = {}

	function signal.connect(_self: any, handler: Handler<T...>): Connection
		local connection: ConnectionImpl = {
			connected = true,
			disconnect = disconnect,
			_handler = handler :: any,
		}
		table.insert(connections, connection)
		return connection :: any
	end

	function signal.once(self: any, handler: Handler<T...>): Connection
		local connection: Connection
		connection = signal.connect(self, function(...: T...)
			connection:disconnect()
			handler(...)
		end)
		return connection
	end

	function signal.fire(_self: any, ...: T...)
		-- Snapshot so handlers may connect/disconnect while firing.
		local snapshot = table.clone(connections)
		for _, connection in snapshot do
			if connection.connected then
				local ok, err = pcall(connection._handler :: any, ...)
				if not ok then
					warn(`Signal handler errored: {err}`)
				end
			end
		end
		-- Compact disconnected connections.
		for index = #connections, 1, -1 do
			if not connections[index].connected then
				table.remove(connections, index)
			end
		end
	end

	function signal.disconnectAll(_self: any)
		for _, connection in connections do
			connection.connected = false
		end
		table.clear(connections)
	end

	return signal :: any
end

return Signal
