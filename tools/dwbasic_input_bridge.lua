-- Drive the DreamWriter keyboard matrix from framed commands on a Unix stream socket.

local socket_path = os.getenv("DWBASIC_INPUT_SOCKET") or "/tmp/dwbasic-input.sock"
local hold_frames = tonumber(os.getenv("DWBASIC_INPUT_HOLD_FRAMES") or "2")
local gap_frames = tonumber(os.getenv("DWBASIC_INPUT_GAP_FRAMES") or "1")
local shift_lead_frames = tonumber(os.getenv("DWBASIC_INPUT_SHIFT_LEAD_FRAMES") or "1")
local shift_trail_frames = tonumber(os.getenv("DWBASIC_INPUT_SHIFT_TRAIL_FRAMES") or "1")

local ports = nil
local socket = nil
local buffer = ""
local queue = {}
local active = {}
local step = nil
local step_frames = 0
local program_space = nil

local function get_program_space()
	if not program_space then
		local cpu = manager.machine.devices[":v20hl"] or manager.machine.devices["v20hl"]
		if not cpu then
			error("missing v20hl CPU device")
		end
		program_space = cpu.spaces["program"]
		if not program_space then
			error("missing v20hl program space")
		end
	end
	return program_space
end

local function read_hex(start_address, length)
	local space = get_program_space()
	local values = {}
	for offset = 0, length - 1 do
		values[#values + 1] = string.format("%02X", space:read_u8(start_address + offset))
	end
	return table.concat(values)
end

local function read_u8(address)
	return get_program_space():read_u8(address)
end

local function kbd_state_line()
	return string.format(
		"OK KBD raw=%s deb=%s sticky=%s flags=%s repeat=%s queue=%02X/%02X events=%s",
		read_hex(0x6d06, 0x0a),
		read_hex(0x6d10, 0x14),
		read_hex(0x6d24, 0x04),
		read_hex(0x6eae, 0x07),
		read_hex(0x70e8, 0x02),
		read_u8(0x70e2),
		read_u8(0x70e3),
		read_hex(0x70a6, 0x3c)
	)
end

local function get_port(name)
	local result = manager.machine.ioport.ports[":" .. name] or manager.machine.ioport.ports[name]
	if not result then
		error("missing input port " .. name)
	end
	return result
end

local function get_field(port_name, mask)
	local result = get_port(port_name):field(mask)
	if not result then
		error(string.format("missing input field %s:%02x", port_name, mask))
	end
	return result
end

local function init_ports()
	if ports then
		return
	end

	ports = {
		lshift = get_field("ROW0", 0x01),
		enter = get_field("ROW0", 0x10),
		left = get_field("ROW0", 0x08),
		can = get_field("ROW1", 0x04),
		insert = get_field("ROW6", 0x04),
		right = get_field("ROW6", 0x08),
		down = get_field("ROW6", 0x02),
		orgn = get_field("ROW7", 0x04),
		up = get_field("ROW7", 0x08),
		wp = get_field("ROW7", 0x10),
		backspace = get_field("ROW9", 0x04),
		keys = {
			["3"] = get_field("ROW3", 0x01),
			["2"] = get_field("ROW3", 0x02),
			q = get_field("ROW3", 0x04),
			w = get_field("ROW3", 0x08),
			e = get_field("ROW3", 0x10),
			s = get_field("ROW3", 0x40),
			d = get_field("ROW3", 0x80),
			["4"] = get_field("ROW4", 0x01),
			z = get_field("ROW4", 0x04),
			x = get_field("ROW4", 0x08),
			a = get_field("ROW4", 0x10),
			r = get_field("ROW4", 0x40),
			f = get_field("ROW4", 0x80),
			b = get_field("ROW5", 0x04),
			v = get_field("ROW5", 0x08),
			t = get_field("ROW5", 0x10),
			y = get_field("ROW5", 0x20),
			g = get_field("ROW5", 0x40),
			c = get_field("ROW5", 0x80),
			["1"] = get_field("ROW2", 0x04),
			[" "] = get_field("ROW1", 0x08),
			["5"] = get_field("ROW1", 0x40),
			["`"] = get_field("ROW1", 0x02),
			["6"] = get_field("ROW6", 0x01),
			["\\"] = get_field("ROW6", 0x10),
			["/"] = get_field("ROW6", 0x20),
			h = get_field("ROW6", 0x40),
			n = get_field("ROW6", 0x80),
			["="] = get_field("ROW7", 0x01),
			["7"] = get_field("ROW7", 0x02),
			u = get_field("ROW7", 0x20),
			m = get_field("ROW7", 0x40),
			k = get_field("ROW7", 0x80),
			["8"] = get_field("ROW8", 0x01),
			["-"] = get_field("ROW8", 0x02),
			["]"] = get_field("ROW8", 0x04),
			["["] = get_field("ROW8", 0x08),
			["'"] = get_field("ROW8", 0x10),
			i = get_field("ROW8", 0x20),
			j = get_field("ROW8", 0x40),
			[","] = get_field("ROW8", 0x80),
			["0"] = get_field("ROW9", 0x01),
			["9"] = get_field("ROW9", 0x02),
			p = get_field("ROW9", 0x08),
			[";"] = get_field("ROW9", 0x10),
			l = get_field("ROW9", 0x20),
			o = get_field("ROW9", 0x40),
			["."] = get_field("ROW9", 0x80),
		},
	}
	ports.named = {
		["return"] = ports.enter,
		["enter"] = ports.enter,
		["left"] = ports.left,
		["right"] = ports.right,
		["up"] = ports.up,
		["down"] = ports.down,
		["insert"] = ports.insert,
		["backspace"] = ports.backspace,
		["back_space"] = ports.backspace,
		["can"] = ports.can,
		["esc"] = ports.can,
		["escape"] = ports.can,
		["page_down"] = ports.wp,
		["pagedown"] = ports.wp,
		["pgdn"] = ports.wp,
		["wp"] = ports.wp,
		["page_up"] = ports.orgn,
		["pageup"] = ports.orgn,
		["pgup"] = ports.orgn,
		["orgn"] = ports.orgn,
	}
end

local shifted_chars = {
	["!"] = "1",
	["\""] = "'",
	["@"] = "2",
	["#"] = "3",
	["$"] = "4",
	["%"] = "5",
	["^"] = "6",
	["&"] = "7",
	["("] = "9",
	[")"] = "0",
	["*"] = "8",
	["+"] = "=",
	[":"] = ";",
	["<"] = ",",
	[">"] = ".",
	["?"] = "/",
	["_"] = "-",
	["{"] = "[",
	["}"] = "]",
	["|"] = "\\",
	["~"] = "`",
}

local function hex_to_string(hex)
	return (hex:gsub("..", function(pair)
		return string.char(tonumber(pair, 16))
	end))
end

local function enqueue_key(char)
	init_ports()
	if char == "\r" or char == "\n" then
		table.insert(queue, { fields = { ports.enter }, frames = hold_frames })
		table.insert(queue, { fields = {}, frames = gap_frames })
		return true
	end

	local shift = false
	local key = char
	if char:match("%u") then
		shift = true
		key = char:lower()
	elseif shifted_chars[char] then
		shift = true
		key = shifted_chars[char]
	end

	local field = ports.keys[key]
	if not field then
		emu.print_error("dwbasic input bridge: unsupported character " .. string.format("%q", char))
		return false
	end

	local fields = {}
	if shift then
		table.insert(queue, { fields = { ports.lshift }, frames = shift_lead_frames })
		table.insert(fields, ports.lshift)
	end
	table.insert(fields, field)
	table.insert(queue, { fields = fields, frames = hold_frames })
	if shift then
		table.insert(queue, { fields = { ports.lshift }, frames = shift_trail_frames })
	end
	table.insert(queue, { fields = {}, frames = gap_frames })
	return true
end

local function enqueue_named_key(name)
	init_ports()
	if #name == 1 then
		return enqueue_key(name)
	end

	local key = name:lower()
	local field = ports.named[key]
	if not field then
		return false
	end
	table.insert(queue, { fields = { field }, frames = hold_frames })
	table.insert(queue, { fields = {}, frames = gap_frames })
	return true
end

local function enqueue_text(text, add_return)
	for i = 1, #text do
		enqueue_key(text:sub(i, i))
	end
	if add_return then
		enqueue_key("\r")
	end
end

local function handle_line(line)
	local command, payload = line:match("^(%S+)%s*(.*)$")
	if command == "TEXT" then
		enqueue_text(hex_to_string(payload), true)
		socket:write("OK TEXT " .. tostring(#queue) .. "\n")
	elseif command == "TYPE" then
		enqueue_text(hex_to_string(payload), false)
		socket:write("OK TYPE " .. tostring(#queue) .. "\n")
	elseif command == "KEY" then
		if enqueue_named_key(payload) then
			socket:write("OK KEY " .. tostring(#queue) .. "\n")
		else
			socket:write("ERR unsupported key " .. payload .. "\n")
		end
	elseif command == "KBDSTATE" then
		socket:write(kbd_state_line() .. "\n")
	elseif command == "SNAP" then
		manager.machine.video:snapshot()
		socket:write("OK SNAP\n")
	elseif command and command ~= "" then
		local message = "unknown command " .. command
		emu.print_error("dwbasic input bridge: " .. message)
		socket:write("ERR " .. message .. "\n")
	end
end

local function read_commands()
	if not socket then
		socket = emu.file("rwc")
		local err = socket:open("domain." .. socket_path)
		if err then
			emu.print_error("dwbasic input bridge: socket open failed: " .. tostring(err))
			socket = nil
		end
		return
	end

	while true do
		local chunk = socket:read(4096)
		if not chunk or #chunk == 0 then
			return
		end
		buffer = buffer .. chunk
		while true do
			local newline = buffer:find("\n", 1, true)
			if not newline then
				break
			end
			local line = buffer:sub(1, newline - 1):gsub("\r$", "")
			buffer = buffer:sub(newline + 1)
			local ok, err = pcall(handle_line, line)
			if not ok then
				emu.print_error("dwbasic input bridge: " .. tostring(err))
				socket:write("ERR " .. tostring(err) .. "\n")
			end
		end
	end
end

local function clear_active()
	for _, field in ipairs(active) do
		field:clear_value()
	end
	active = {}
end

local function apply_step(next_step)
	clear_active()
	active = next_step.fields
	for _, field in ipairs(active) do
		field:set_value(1)
	end
	step = next_step
	step_frames = next_step.frames
end

local function process_frame()
	read_commands()

	if step then
		for _, field in ipairs(active) do
			field:set_value(1)
		end
		step_frames = step_frames - 1
		if step_frames > 0 then
			return
		end
		clear_active()
		step = nil
	end

	if #queue > 0 then
		apply_step(table.remove(queue, 1))
	end
end

emu.register_frame_done(process_frame)
emu.add_machine_stop_notifier(clear_active)
