#!/usr/bin/env luajit
--Simple example script to compile the song from .fxmasm source to .fxm file and immediately play it using Ay_Emul

local function main()
	local fname = assert(arg[1], "Missing file name")
	local tmpfname = "/tmp/fxmasm_temp_file.fxm"
	local code = os.execute("./fxmasm.lua "..fname.." "..tmpfname)
	if code ~= 0 then
		os.exit()
	end
	print("Playing...")
	-- Change the path below to point to your AY Emul binary
	os.execute("~/bin/ayemul/Ay_Emul "..tmpfname)
end

main()
