require("patch/lua/rom_table")
local arg = {...}
local rom = gru.n64rom_load(arg[1])
local rom_info = rom_table[rom:crc32()]
local rom_id = rom_info.game .. "-" .. rom_info.version .. "-" .. rom_info.region
print("rom is " .. rom_id)
print("building dependencies")
local make = os.getenv("MAKE")
if make == nil or make == "" then
  make = "make"
end
local _,_,make_result = os.execute(make .. " gz-" .. rom_id)
if make_result ~= 0 then
  error("failed to build gz", 0)
end
print("loading file system")
local fs = gru.z64fs_load_blob(rom)
print("patching code file")
local code_file = fs:get(rom_info.code_ind)
local gz = gru.blob_load("bin/" .. rom_id .. "/gz.bin")
code_file:write(rom_info.gz_address - rom_info.code_ram, gz)
local main_hook = gru.gsc_load(rom_id .. "/main_hook.gsc")
main_hook:shift(-rom_info.code_ram)
main_hook:apply_be(code_file)
fs:replace(rom_info.code_ind, code_file, fs:compressed(rom_info.code_ind))
print("reassembling rom")
local patched_rom = fs:assemble_rom()
patched_rom:crc_update()
return rom_info, rom, patched_rom
