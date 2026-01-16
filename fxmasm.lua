#!/usr/bin/env luajit
-- FXM AY file disassembler / assembler
-- fuka@fuxoft.cz
-- [[[[*<= Version '2.1.8+D20260115T224847' =>*]]]]

_G.debug = function(...) print(...) end

-- Comment out the following line to show debug info
_G.debug = function() end

local opcodes = {
	[0x80] = {"JUMP", 3},
	[0x81] = {"CALL", 3},
	[0x82] = {"LOOP", 2},
	[0x83] = {"NEXT", 1},
	[0x84] = {"NOISE", 2},
	[0x85] = {"TYPE", 2},
	[0x87] = {"ENV", 3},
	[0x88] = {"TR", 2},
	[0x89] = {"RET", 1},
	[0x86] = {"VIB", 3},
	[0x8a] = {"LEG+", 1},
	[0x8b] = {"LEG-", 1},
	[0x8c] = {"EXTERNAL_CALL", 3},
	[0x8d] = {"NOISE+", 2},
	[0x8e] = {"TR+", 2},
}

local vibrato_opcodes = {
	[0x82] = "TONE",
	[0x83] = "FREQ",
	[0x84] = "XOR",
}

local function hexword(num)
	assert(num >=0 and num <= 65535)
	return string.format("0x%04x", num)
end

local function hexbyte(num)
	assert(num >=0 and num <= 255)
	return string.format("0x%02x", num)
end

local function signedbyte(num)
	assert(num >=0 and num <= 255)
	if num >= 128 then
		num = num - 256
	end
	return tostring(num)
end

local function valid_address(addr)
	local real = addr - OFFSET + 7
	return (real >= 1 and real <= #FILE)
end

local function peek(addr)
	local off = OFFSET or 6
	local real = addr - off + 7
	if not (real >= 1 and real <= #FILE) then
		error ("Attempt to peek from invalid address "..hexword(addr))
	end
	local byte = assert(FILE:byte(real,real))
	return byte
end

local function dpeek(addr)
	return peek(addr) + 256*peek(addr+1)
end

local function load_song(filename)
	assert(#filename > 0)
	local fd = assert(io.open(filename))
	local str = assert(fd:read("*a"))
	fd:close()
	_G.FILE = str
	assert(FILE:match("^FXSM"), "File does not begin with FXSM")
	local addr = dpeek(4)
	_G.OFFSET = addr
	print("-- File name: "..filename)
	print("-- offset = "..hexword(OFFSET))
	_G.LABELS = {}
	for i = 1, 3 do
		local addr = dpeek(OFFSET + 2*i - 2)
		print("-- voice"..i.." = "..hexword(addr))
		LABELS[addr] = "voice"..i
	end
end

local function print_it(output)
	local result = {}
	local buffer = {}
	local function add(str)
		table.insert(result, str)
	end
	local function flush()
		if next(buffer) then
			add(table.concat(buffer, " "))
			add("\n")
		end
		buffer = {}
	end
	for _i, item in ipairs(output) do
		local label = LABELS[item.addr]
		if label then
			flush()
			add ("\n"..label..":\n")
		end
		if item.typ == "line" then
			flush()
			add(item.string.."\n")
		else
			table.insert(buffer, item.string)
		end
	end
	flush()
	print(table.concat(result))
end

local function disasm(fname)
	load_song(fname)
	local addr = OFFSET + 6
	--assert (LABELS[OFFSET + 6] == "voice1")

	_G.MODES = {}

	local function parse_mode(addr, mode)
		while true do
			local m0 = MODES[addr]
			if m0 then
				--assert(m0 == mode, "Mode mismatch at #"..hexword(addr)..": "..m0.."/"..mode)
				return
			end
			MODES[addr] = mode
			debug("parse mode", hexword(addr), mode, hexbyte(peek(addr)))

			if mode == "melody" then
				local byt1 = peek(addr)
				if byt1 < 128 then --note
					addr = addr + 2
				else
					local opcode = opcodes[peek(addr)]
					if not opcode then
						error("Invalid opcode #"..hexbyte(peek(addr)).." at #"..hexword(addr))
					end
					local str = opcode[1]
					local oplen = opcode[2]
					debug("opcode",str,oplen)
					if str == "CALL" or str == "JUMP" then
						parse_mode(dpeek(addr+1), "melody")
						if str == "JUMP" then
							return
						end
					elseif str == "RET" then
						return
					elseif str == "VIB" then
						parse_mode(dpeek(addr+1), "vibrato")
					elseif str == "ENV" then
						parse_mode(dpeek(addr+1), "envelope")
					end
					addr = addr + oplen
				end
			elseif mode == "envelope" then
				local byt1 = peek(addr)
				if byt1 > 0x80 then
					debug("In deep shit at #"..hexword(addr))
					MODES[addr] = nil
					parse_mode(addr, "melody")
					return -- Oops, we have ran into some deep shit. Give up. Required for Red Dawns's 222 duration envelope without final JUMP
				elseif byt1 == 0x80 then
					parse_mode(dpeek(addr + 1), "envelope")
					return
				elseif byt1 >= 50 then
					addr = addr + 1
				else
					local byt2 = peek(addr + 1)
					if (byt2 == 0 or byt2 == 255) and peek(addr + 2) ~= 0x80 then -- We are not 100% sure if this is the end of envelope or not. Have to check the disassembled source manually
						return
					end
					addr = addr + 2
				end
			elseif mode == "vibrato" then
				local byt1 = peek(addr)
				if byt1 == 0x80 then
					parse_mode(dpeek(addr + 1), "vibrato")
					return
				else
					addr = addr + 1
				end
			else
				error("Invalid mode: "..mode.." at #"..hexword(addr))
			end
		end
	end

	for addr, label in pairs(LABELS) do
		assert(label:match("^voice"))
		parse_mode(addr, "melody")
	end

	local output = {}
	local function add(thing)
		assert(thing.typ, "No type")
		thing.addr = addr
		table.insert(output, thing)
		debug("Add:", thing.string,"at", hexword(addr))
	end
	local function add_string(str)
		assert(str)
		add{typ="string", string=str}
	end
	local function add_line(str)
		add{typ="line", string=str}
	end

	local lastmode = "melody"

	repeat
		local label = LABELS[addr]
--[[		if label then
			if label:match("^mel") or label:match("^voice") then
				mode = "melody"
			elseif label:match("^vib") then
				mode = "vibrato"
			else
				assert(label:match("^env"), "Non-recognized label: "..label)
				mode = "envelope"
			end
		end]]
		local mode = MODES[addr]
		if not mode then
			mode = "unknown"
			debug("Unknown mode, setting "..mode)
		end
		lastmode = mode
		debug("Mode:", mode)
		if mode == "melody" then
			local byt1 = peek(addr)
			debug("parsing #"..hexword(addr)..": #"..hexbyte(byt1))
			if byt1 < 128 then --note
				local len = peek(addr + 1)
				add_string(byt1 .. ","..len)
				addr = addr + 2
			else --opcode
				local opcode = opcodes[byt1]
				if not opcode then
					error("Invalid opcode: "..hexbyte(byt1).. " at #"..hexword(addr))
				end
				local oplen = assert(opcode[2])
				local str = assert(opcode[1])
				local item = {addr = addr, typ = "string"}
				if oplen == 3 then
					if str == "CALL" or str == "JUMP" then
						local a = dpeek(addr + 1)
						local label = LABELS[a]
						if not label then
							label = "mel_"..hexword(a)
							LABELS[a] = label
						end
						str = str .. " " .. label
					elseif str == "ENV" then
						local a = dpeek(addr + 1)
						local label = "env_"..hexword(a)
						LABELS[a] = label
						str = str .. " " .. label
					elseif str == "VIB" then
						local a = dpeek(addr + 1)
						local label = "vib_"..hexword(a)
						LABELS[a] = label
						str = str .. " " .. label
					else
						assert (str == "EXTERNAL_CALL")
						str = str .. " dummy_external_" .. hexword(dpeek (addr + 1))
					end
				elseif oplen == 2 then
					str = str .. " " .. signedbyte(peek(addr+1))
				end
				item.string = str
				add(item)
				addr = addr + oplen
			end
		elseif mode == "envelope" then
			local byt1 = peek(addr)
			if byt1 == 0x80 then
				local a = dpeek(addr + 1)
				local label = "env_"..hexword(a)
				LABELS[a] = label
				add_string("JUMP "..label)
				addr = addr + 3
			elseif byt1 >= 50 then
				add_string(tostring(byt1))
				addr = addr + 1
			else
				add_string(byt1..","..peek(addr+1))
				addr = addr + 2
			end
		elseif mode == "vibrato" then
			local byt1 = peek(addr)
			if byt1 == 0x80 then
				local a = dpeek(addr + 1)
				local label = LABELS[a]
				local label = "vib_"..hexword(a)
				LABELS[a] = label
				add_string("JUMP "..label)
				addr = addr + 3
			else
				local txt = vibrato_opcodes[byt1]
				if txt then
					add_string(txt)
				else
					add_string(signedbyte(byt1))
				end
				addr = addr + 1
			end
		else
			--error("Invalid mode: "..mode.. " at #"..hexword(addr))
			debug("mode", tostring(mode))
			add_line("-- Unexpected byte #"..hexbyte(peek(addr)).." at #"..hexword(addr))
			addr = addr + 1
		end
	until not valid_address(addr)
	add_line("-- End at #"..hexword(addr - 1))
	print_it(output)
end

local function load_source(filename)
	assert(#filename > 0)
	local fd = assert(io.open(filename), "Cannot open .fxmasm source file: "..filename)
	local str = assert(fd:read("*a"))
	fd:close()
	return str
end

local function valid_byte(num)
	if num < -128 or num > 255 then
		return false
	end
	if num < 0 then
		num = num + 256
	end
	return num
end

local function word_to_chars(wrd)
	assert(wrd >= 0 and wrd <= 0xffff)
	return string.char (bit.band(wrd, 0xff)) .. string.char(bit.rshift(wrd, 8))
end

local function asm(args)
	local in_fname = assert(args.input_filename)
	local srctxt = load_source(in_fname)
	local lines = {}
	for line in (srctxt.."\n"):gmatch("(.-)\n") do
		table.insert(lines, line)
	end
	--print(#lines, "lines")
	
	_G.LABELS = {}
	local parsed = {}

	for k,v in pairs(opcodes) do
		if type(v) == "table" then
			opcodes[v[1]] = k
		end
	end
	for k,v in pairs(vibrato_opcodes) do
		opcodes[v] = k
	end

	local tokens = {}

	local function error_line(str, nline)
		error(str.." at line "..nline.." of source file")
	end

	for nline, line in ipairs(lines) do
		line = line:match("^%s*(.-)%s*$")
		if not line:match("^%-%-") then --not a comment
			line = line:gsub("%s+", " ")
			for token in (line.." "):gmatch("(.-) ") do
				if #token > 0 then
					table.insert(tokens, {token=token, line = nline})
					debug("line", nline, "token", token)
				end
			end
		end
	end

	-- start_addr is the address of the actual music data. The datablock (three doublebyte voice pointers)
	-- is right before it, at address start_addr - 6
	local start_addr = 0x8006
	if args.raw then
		start_addr = assert(args.address) + 6
	end
	local addr = start_addr
	for i, item in ipairs(tokens) do
		local nline = assert(item.line)
		local token = assert(item.token)
		local label = token:match("^(.+):$")
		if label then
			if LABELS[label] then
				error_line("Attempt to redefine label '"..label.."'", nline)
			end
			LABELS[label] = addr
			debug("Label", label, hexword(addr))
		else
			local num1, num2 = token:match("^(.+),(.+)$")
			if num2 then -- xx,yy
				num1, num2 = tonumber(num1), tonumber(num2)
				if not (num1 and num2) then
					error_line("Invalid double byte: "..token, nline)
				end
				table.insert(parsed, {line = nline, two_bytes = {num1, num2}})
				addr = addr + 2
			elseif opcodes[token] then
				local byt = assert(opcodes[token])
				table.insert(parsed, {line = nline, byte = byt})
				addr = addr + 1
			else
				local byt = tonumber(token)
				if type(byt) == "number" then
					table.insert(parsed, {line = nline, byte = byt})
					addr = addr + 1	
				else	--it's label reference
					local label = token
					table.insert(parsed, {line = nline, label = label})
					addr = addr + 2
				end
			end
		end
	end


	local result = {"FXSM", word_to_chars(start_addr - 6)}
	if args.raw then
		result = {}
	end

	local function add(str)
		table.insert(result, str)
	end

	for i = 1, 3 do
		local label = "voice"..i
		local addr = assert(LABELS[label], "Required label '"..label.."' is undefined")
		add(word_to_chars(addr))
	end

	local addr = start_addr
	for i, item in ipairs(parsed) do
		if item.byte then
			local byt = valid_byte(item.byte)
			if not byt then
				error_line("Invalid byte "..item.byte, item.line)
			end
			add(string.char(byt))
		elseif item.two_bytes then
			local two = item.two_bytes
			local byt1, byt2 = valid_byte(two[1]), valid_byte(two[2])
			if not byt1 then
				error_line("Invalid first byte of a pair: "..two[1], item.line)
			end
			if not byt2 then
				error_line("Invalid second byte of a pair: "..two[2], item.line)
			end
			add(string.char(byt1))
			add(string.char(byt2))
		else --must be label reference
			local label = assert(item.label)
			local a = LABELS[label]
			if not a then
				error_line("Undefined label "..label, item.line)
			end
			add(word_to_chars(a))
		end
	end
	local fname = assert(args.output_filename, "Missing output filename (argument 3).")
	print("Compiled OK")
	print("Datablock (3 voice pointers) starts at: 0x"..hexword(start_addr-6))
	print("Actual music data starts at: 0x"..hexword(start_addr))
	local str = table.concat(result)
	print("File size: "..#str.." bytes")
	local fd = assert(io.open(fname, "w"))
	fd:write(str)
	fd:close()
	print("Written to "..fname)
end

local function main()

	local directive = assert(arg[1], "No directive provided. Accepted values: decompile, compile, compile_raw")
	local fname = assert(arg[2], "No filename (argument 2) provided.")
	local outfname = arg[3]
	if directive == "decompile" then
		disasm (fname)
	elseif directive == "compile" then
		asm{raw = false, address = 0x8000, input_filename = fname, output_filename = outfname}
	elseif directive == "compile_raw" then
		local address = assert(arg[4], "No raw compilation address provided (argument 4).")
		address = assert(tonumber(address), "Invalid compilation address: "..address)
		asm{raw = true, address = address, input_filename = fname, output_filename = outfname}
	else
		error("Invalid directive: "..directive)
	end
end

main()