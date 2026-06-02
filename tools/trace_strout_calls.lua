-- Trace the two INIT-time STROUT calls in the split DW-BASIC payload.
--
-- Intended launch shape:
--   ../mame/drwrt400 drwrt400 -bios v2_1 -debug -debugger none \
--     -autoboot_script tools/trace_strout_calls.lua ...
--
-- The script installs breakpoints before pressing ENTER on the prepared
-- ROM CARD menu, then logs the full CPU state just before each CALL STROUT.

local trace_path = os.getenv("DWBASIC_STROUT_TRACE") or "/tmp/dwbasic-strout-trace.log"
local enter_delay_frames = tonumber(os.getenv("DWBASIC_STROUT_TRACE_ENTER_DELAY") or "30")
local enter_hold_frames = tonumber(os.getenv("DWBASIC_STROUT_TRACE_ENTER_HOLD") or "8")
local stop_on_second = (os.getenv("DWBASIC_STROUT_TRACE_STOP_ON_SECOND") or "0") ~= "0"

local COD_SEG = tonumber(os.getenv("DWBASIC_STROUT_TRACE_COD_SEG") or "0")
local addr_mode = os.getenv("DWBASIC_STROUT_TRACE_ADDR_MODE") or "physical"
local FIRST_STROUT_CALL_IP = tonumber(os.getenv("DWBASIC_STROUT_TRACE_FIRST_IP") or "0x37CD")
local SECOND_STROUT_CALL_IP = tonumber(os.getenv("DWBASIC_STROUT_TRACE_SECOND_IP") or "0x37D3")
local LOADER_SEG = tonumber(os.getenv("DWBASIC_STROUT_TRACE_LOADER_SEG") or "0x0A4F")
local LOADER_TRANSFER_IP = tonumber(os.getenv("DWBASIC_STROUT_TRACE_LOADER_TRANSFER_IP") or "0x0140")
local LOADER_ENTRY_SEG_OFF = tonumber(os.getenv("DWBASIC_STROUT_TRACE_ENTRY_SEG_OFF") or "0x05BF")

local cpu = nil
local installed = false
local strout_breakpoints_installed = false
local frame_count = 0
local pressed_enter = false
local released_enter = false
local enter_frames_left = 0
local enter_field = nil
local trace_file = nil
local consolelog = nil
local consolelast = 0
local breakpoint_handlers = {}
local loader_transfer_breakpoint = nil

local function open_trace()
	if not trace_file then
		local err
		trace_file, err = io.open(trace_path, "w")
		if not trace_file then
			error("trace open failed: " .. tostring(err) .. " path=" .. trace_path)
		end
	end
	return trace_file
end

local function log_line(line)
	open_trace():write(line .. "\n")
	open_trace():flush()
	emu.print_error(line)
end

local function find_cpu()
	if cpu then
		return cpu
	end

	local candidates = { ":v20hl", "v20hl", ":maincpu", "maincpu", ":cpu", "cpu" }
	for _, tag in ipairs(candidates) do
		local device = manager.machine.devices[tag]
		if device and device.state and device.spaces and device.spaces["program"] then
			cpu = device
			return cpu
		end
	end

	for _, device in pairs(manager.machine.devices) do
		if device.state and device.spaces and device.spaces["program"] then
			cpu = device
			return cpu
		end
	end

	return nil
end

local function state_value(name)
	local item = find_cpu().state[name]
	if not item then
		return nil
	end
	return tonumber(item.value)
end

local function fmt(name)
	local value = state_value(name)
	if value == nil then
		return name .. "=????"
	end
	return string.format("%s=%04X", name, value & 0xffff)
end

local function cpu_state_line(label)
	local parts = {
		label,
		fmt("PS"),
		fmt("PC"),
		fmt("DS0"),
		fmt("DS1"),
		fmt("SS"),
		fmt("SP"),
		fmt("AW"),
		fmt("BW"),
		fmt("CW"),
		fmt("DW"),
		fmt("IX"),
		fmt("IY"),
		fmt("PSW"),
	}
	return table.concat(parts, " ")
end

local function linear_address(segment, offset)
	return ((segment << 4) + offset) & 0xfffff
end

local function read_u16(address)
	local space = find_cpu().spaces["program"]
	local lo = space:read_u8(address)
	local hi = space:read_u8(address + 1)
	return lo | (hi << 8)
end

local function read_u8(address)
	return find_cpu().spaces["program"]:read_u8(address)
end

local function cursor_state()
	local ds = state_value("DS0")
	if not ds then
		return "CSRY=?? CSRX=??"
	end

	local base = linear_address(ds, 0)
	return string.format(
		"CSRY=%02X CSRX=%02X",
		read_u8(base + 0x155f),
		read_u8(base + 0x1560)
	)
end

local function devtable_state()
	local ds = state_value("DS0")
	local cs = state_value("PS")
	if not ds or not cs then
		return "devtable=??"
	end
	local ds_base = linear_address(ds, 0)
	local cs_base = linear_address(cs, 0)

	local ptrfil  = read_u16(ds_base + 0x1048)
	local devtbl  = read_u16(ds_base + 0x1054)
	local devptr  = read_u16(ds_base + 0x1056)
	local iojump  = read_u16(ds_base + 0x1060)
	local lstchr  = read_u8(ds_base + 0x1032)
	local escflg  = read_u8(ds_base + 0x151F)
	local f_cret  = read_u8(ds_base + 0x1527)
	local f_edit  = read_u8(ds_base + 0x1529)

	local devptr_target = 0
	if devptr ~= 0 then
		devptr_target = read_u16(cs_base + devptr)
	end

	return string.format(
		"PTRFIL=%04X DEVTBL=%04X DEVPTR=%04X IOJUMP=%04X LSTCHR=%02X ESCFLG=%02X F_CRET=%02X F_EDIT=%02X DEVPTR->%04X",
		ptrfil, devtbl, devptr, iojump, lstchr, escflg, f_cret, f_edit, devptr_target
	)
end

local function set_breakpoint(offset, segment, handler)
	local device = find_cpu()
	local bp
	local address
	local condition = nil

	if addr_mode == "ip" then
		address = offset
		condition = string.format("ps==%04X", segment)
		bp = device.debug:bpset(address, condition, "")
	else
		address = linear_address(segment, offset)
		bp = device.debug:bpset(address, "", "")
	end

	breakpoint_handlers[bp] = handler
	return bp, address, condition
end

local function install_strout_breakpoints(segment)
	if strout_breakpoints_installed then
		return
	end

	local first_bp, first_addr, first_cond = set_breakpoint(FIRST_STROUT_CALL_IP, segment, function()
		log_line(cpu_state_line("first_strout") .. " " .. cursor_state() .. " " .. devtable_state())
		manager.machine.debugger.execution_state = "run"
	end)
	local deep_trace_installed = false

	local second_bp, second_addr, second_cond = set_breakpoint(SECOND_STROUT_CALL_IP, segment, function()
		log_line(cpu_state_line("second_strout") .. " " .. cursor_state() .. " " .. devtable_state())
		if not deep_trace_installed then
			deep_trace_installed = true
			local outdo_ip    = 0x1F86
			local scnsot_ip   = 0x2938
			local scnout_ip   = 0x850B
			local scrout_ip   = 0x9E1C
			local scnpos_ip   = 0x84AA
			local setcsr_ip   = 0x28C1
			local prtmap_ip   = 0xA806

			local function deep_handler(label)
				return function()
					log_line(cpu_state_line(label) .. " " .. cursor_state())
					manager.machine.debugger.execution_state = "run"
				end
			end

			set_breakpoint(outdo_ip,  segment, deep_handler("deep_OUTDO"))
			set_breakpoint(scnsot_ip, segment, deep_handler("deep_SCNSOT"))
			set_breakpoint(scnout_ip, segment, deep_handler("deep_SCNOUT"))
			set_breakpoint(scrout_ip, segment, deep_handler("deep_SCROUT"))
			set_breakpoint(scnpos_ip, segment, deep_handler("deep_SCNPOS"))
			set_breakpoint(prtmap_ip, segment, deep_handler("deep_PRTMAP"))
			log_line("installed_deep_trace_breakpoints")
		end
		if stop_on_second then
			manager.machine.debugger.execution_state = "stop"
		else
			manager.machine.debugger.execution_state = "run"
		end
	end)
	strout_breakpoints_installed = true

	log_line(string.format(
		"installed_strout_breakpoints mode=%s CS=%04X first_bp=%d first=%05X first_cond=%s second_bp=%d second=%05X second_cond=%s trace=%s",
		addr_mode,
		segment,
		first_bp,
		first_addr,
		first_cond or "",
		second_bp,
		second_addr,
		second_cond or "",
		trace_path
	))
end

local function loader_transfer()
	local entry_segment_addr = linear_address(LOADER_SEG, LOADER_ENTRY_SEG_OFF)
	local segment = read_u16(entry_segment_addr)
	log_line(string.format(
		"loader_transfer %s entry_segment_addr=%05X entry_segment=%04X",
		cpu_state_line("loader_transfer_state") .. " " .. cursor_state(),
		entry_segment_addr,
		segment
	))
	if loader_transfer_breakpoint then
		find_cpu().debug:bpclear(loader_transfer_breakpoint)
		breakpoint_handlers[loader_transfer_breakpoint] = nil
		loader_transfer_breakpoint = nil
	end
	if segment ~= 0 then
		install_strout_breakpoints(segment)
	end
	manager.machine.debugger.execution_state = "run"
end

local function poll_debugger_console()
	if not consolelog then
		if manager.machine.debugger then
			consolelog = manager.machine.debugger.consolelog
			consolelast = #consolelog
		end
		return
	end

	local current = #consolelog
	if current <= consolelast then
		return
	end

	for i = consolelast + 1, current do
		local msg = consolelog[i]
		if msg and msg:find("Stopped at", 1, true) then
			local point = tonumber(msg:match("Stopped at breakpoint ([0-9]+)"))
			if point then
				local handler = breakpoint_handlers[point]
				if handler then
					handler()
				end
			end
		end
	end
	consolelast = current
end

local function install_breakpoints()
	local device = find_cpu()
	if not device or not device.debug then
		return false
	end

	device.debug:bpclear()
	breakpoint_handlers = {}
	strout_breakpoints_installed = false

	if COD_SEG ~= 0 then
		install_strout_breakpoints(COD_SEG)
	else
		local transfer_addr
		local transfer_cond
		loader_transfer_breakpoint, transfer_addr, transfer_cond = set_breakpoint(
			LOADER_TRANSFER_IP,
			LOADER_SEG,
			loader_transfer
		)
		log_line(string.format(
			"installed_loader_transfer_breakpoint mode=%s bp=%d loader=%04X:%04X address=%05X cond=%s trace=%s",
			addr_mode,
			loader_transfer_breakpoint,
			LOADER_SEG,
			LOADER_TRANSFER_IP,
			transfer_addr,
			transfer_cond or "",
			trace_path
		))
	end

	return true
end

local function find_enter_field()
	if enter_field then
		return enter_field
	end
	local ports = manager.machine.ioport.ports
	local row0 = ports[":ROW0"] or ports["ROW0"]
	if not row0 then
		return nil
	end
	enter_field = row0:field(0x10)
	return enter_field
end

local function press_enter_once()
	local field = find_enter_field()
	if not field then
		log_line("missing_enter_field")
		return
	end

	if not pressed_enter then
		enter_frames_left = enter_hold_frames
		pressed_enter = true
		log_line("pressed_enter")
	end

	if enter_frames_left > 0 then
		field:set_value(1)
		enter_frames_left = enter_frames_left - 1
	elseif not released_enter then
		field:clear_value()
		released_enter = true
		log_line("released_enter")
	end
end

local function on_frame()
	if not installed then
		installed = install_breakpoints()
		return
	end

	frame_count = frame_count + 1
	if frame_count >= enter_delay_frames and not released_enter then
		press_enter_once()
	end
end

emu.register_frame_done(on_frame)
emu.register_periodic(poll_debugger_console)
emu.add_machine_stop_notifier(function()
	log_line(string.format("machine_stop frame_count=%d installed=%s strout_bp=%s",
		frame_count, tostring(installed), tostring(strout_breakpoints_installed)))
	if trace_file then
		trace_file:close()
		trace_file = nil
	end
end)
