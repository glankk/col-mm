local arg = {...}
if #arg < 1 then
  print("usage: `make-rom <rom-file>`")
  return
end
local make = loadfile("patch/lua/make.lua")
for i = 1, #arg do
  print("making rom from `" .. arg[i] .. "`")
  local rom_info, rom, patched_rom = make(arg[i])
  print("saving rom")
  local rom_id = rom_info.game .. "-" .. rom_info.version .. "-" .. rom_info.region
  patched_rom:save_file("patch/col-" .. rom_id ..  ".z64")
end
print("done")
