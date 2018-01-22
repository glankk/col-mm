rom_table =
{
  [0x0D33E1DB]  = {
                    game        = "mm",
                    version     = "1.0",
                    region      = "j",
                    code_ind    = 28,
                    code_ram    = 0x800A76A0,
                    gz_address  = 0x801CC630,
                  },
  [0xB428D8A7]  = {
                    game        = "mm",
                    version     = "1.0",
                    region      = "u",
                    code_ind    = 31,
                    code_ram    = 0x800A5AC0,
                    gz_address  = 0x801D1E80,
                  },
}
setmetatable(rom_table, {__index = function(t)
  io.write("unrecognized rom. select an action;\n  0. quit\n")
  local keys = {}
  for k,v in pairs(t) do
    keys[#keys + 1] = k
    io.write(string.format("  %d. treat as `%s`\n", #keys, v.game .. "-" .. v.version .. "-" .. v.region))
  end
  local n = io.read("n")
  local k = keys[n]
  if k == nil then
    error("operation aborted", 0)
  end
  return t[k]
end})
