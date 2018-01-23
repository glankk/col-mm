
-- data structure helpers
function k0_to_phys(addr)
  return bit.band(addr, 0x1FFFFFFF)
end

function sobj(struct, addr, ref)
  local object = {_addr = addr, _ref = ref}
  setmetatable(object, {__index = struct})
  return object
end

function deref(object)
  if type(object._ref) ~= "number" or object._ref <= 0 then
    error("object is not a reference")
  end
  return sobj(getmetatable(object).__index, mainmemory.read_u32_be(k0_to_phys(object._addr)), object._ref - 1)
end

function sind(object, index)
  if object._ref ~= nil and object._ref ~= 0 then
    error("object is not a value")
  end
  return sobj(getmetatable(object).__index, object._addr + object._size * index, object._ref)
end

function sref(object, ...)
  local memb = {...}
  for i = 1, #memb do
    local n = memb[i]
    if type(n) == "function" then
      object = n(object)
    elseif type(n) == "number" or type(n) == "integer" then
      object = sind(object, n)
    elseif type(n) == "string" then
      if object._ref ~= nil and object._ref ~= 0 then
        error("object is not a value")
      end
      local m = object[n]
      if m == nil then
        error("object has no member named `" .. n .. "`")
      end
      local struct = m[1]
      local off = m[2]
      local ref = m[3] or 0
      local addr = object._addr + off
      object = sobj(struct, addr, ref)
    else
      error("invalid object reference type `" .. type(n) .. "`")
    end
  end
  return object
end

function bitfield_t(nbytes, bits, shift)
  local getfunc
  local setfunc
  if nbytes == 1 then
    getfunc = mainmemory.read_u8
    setfunc = mainmemory.write_u8
  elseif nbytes == 2 then
    getfunc = mainmemory.read_u16_be
    setfunc = mainmemory.write_u16_be
  elseif nbytes == 4 then
    getfunc = mainmemory.read_u32_be
    setfunc = mainmemory.write_u32_be
  else
    error("invalid bit field size")
  end
  local bitmask = bit.lshift(1, bits) - 1
  return {
    _size = nbytes,
    _get = function(this)
      return bit.band(bit.rshift(getfunc(k0_to_phys(this._addr)), shift), bitmask)
    end,
    _set = function(this, value)
      value = bit.lshift(bit.band(bitmask, value), shift)
      memvalue = bit.band(bit.bnot(bit.lshift(bitmask, shift)), getfunc(k0_to_phys(this._addr)))
      value = bit.bor(value, memvalue)
      setfunc(k0_to_phys(this._addr), value)
      return bit.band(bit.rshift(value, shift), bitmask)
    end,
  }
end

local mp_t =
{
  _size = 4,
  _get = function(this)
    return this._addr
  end,
  _set = function(this, value)
    this._addr = value
    return this._addr
  end,
}

local s8_t =
{
  _size = 1,
  _get = function(this)
    return mainmemory.read_s8(k0_to_phys(this._addr))
  end,
  _set = function(this, value)
    mainmemory.write_s8(k0_to_phys(this._addr), value)
    return value
  end,
}

local u8_t =
{
  _size = 1,
  _get = function(this)
    return mainmemory.read_u8(k0_to_phys(this._addr))
  end,
  _set = function(this, value)
    mainmemory.write_u8(k0_to_phys(this._addr), value)
    return value
  end,
}

local s16_t =
{
  _size = 2,
  _get = function(this)
    return mainmemory.read_s16_be(k0_to_phys(this._addr))
  end,
  _set = function(this, value)
    mainmemory.write_s16_be(k0_to_phys(this._addr), value)
    return value
  end,
}

local u16_t =
{
  _size = 2,
  _get = function(this)
    return mainmemory.read_u16_be(k0_to_phys(this._addr))
  end,
  _set = function(this, value)
    mainmemory.write_u16_be(k0_to_phys(this._addr), value)
    return value
  end,
}

local u32_t =
{
  _size = 4,
  _get = function(this)
    return mainmemory.read_u32_be(k0_to_phys(this._addr))
  end,
  _set = function(this, value)
    mainmemory.write_u32_be(k0_to_phys(this._addr), value)
    return value
  end,
}


-- addresses
local addresses
if mainmemory.read_u32_be(0x000EBBB8) == 0x0C021A75 then
  addresses =
  {
    hook        = 0x800EBBB8,
    ctxt        = 0x803E6CF0,
    brk         = 0x80780000,
    pause_state = 0x16EFC
  }
elseif mainmemory.read_u32_be(0x000EA048) == 0x0C021819 then
  addresses =
  {
    hook        = 0x800EA048,
    ctxt        = 0x803E6B20,
    brk         = 0x80780000,
    pause_state = 0x16F1C
  }
else
  error("unrecognized game")
end


-- data structure definitions
-- member = {struct, offset, [ref]}
local Mtx =
{
  _size         = 0x0040,
  i             = {s16_t, 0x0000},
  f             = {u16_t, 0x0020},
}

local Vtx_tn =
{
  _size         = 0x0010,
  ob            = {s16_t, 0x0000},
  flag          = {s16_t, 0x0006},
  tc            = {s16_t, 0x0008},
  n             = {s8_t,  0x000C},
  a             = {u8_t,  0x000F},
}

local z64_gfx_buf_t =
{
  p             = {u32_t, 0x0008},
}

local z64_gfx_t =
{
  poly_opa      = {z64_gfx_buf_t, 0x02A8},
  poly_xlu      = {z64_gfx_buf_t, 0x02B8},
}

local z64_input_t =
{
  pad_pressed   = {u16_t, 0x000C},
}

local z64_ctxt =
{
  _addr         = addresses.ctxt,
  gfx           = {z64_gfx_t,   0x0000, 1},
  input         = {z64_input_t, 0x0014},
}

local z64_xyz_t = 
{
  _size         = 0x0006,
  x             = {s16_t, 0x0000},
  y             = {s16_t, 0x0002},
  z             = {s16_t, 0x0004},
}

local z64_col_poly_t =
{
  _size         = 0x0010,
  type          = {u16_t,                 0x0000},
  va            = {bitfield_t(2, 13, 0),  0x0002},
  vb            = {bitfield_t(2, 13, 0),  0x0004},
  vc            = {u16_t,                 0x0006},
  norm          = {z64_xyz_t,             0x0008},
}

local z64_col_type_t =
{
  _size       = 0x0008,
  unk_00_     = {bitfield_t(4, 1, 31),  0x0000},
  drop        = {bitfield_t(4, 1, 30),  0x0000},
  special     = {bitfield_t(4, 4, 26),  0x0000},
  interaction = {bitfield_t(4, 5, 21),  0x0000},
  unk_01_     = {bitfield_t(4, 3, 18),  0x0000},
  behavior    = {bitfield_t(4, 5, 13),  0x0000},
  exit        = {bitfield_t(4, 5, 8),   0x0000},
  camera      = {bitfield_t(4, 8, 0),   0x0000},
  pad_00_     = {bitfield_t(4, 4, 28),  0x0004},
  wall_damage = {bitfield_t(4, 1, 27),  0x0004},
  unk_00_     = {bitfield_t(4, 6, 21),  0x0004},
  unk_01_     = {bitfield_t(4, 3, 18),  0x0004},
  hookshot    = {bitfield_t(4, 1, 17),  0x0004},
  echo        = {bitfield_t(4, 6, 11),  0x0004},
  unk_02_     = {bitfield_t(4, 5, 6),   0x0004},
  terrain     = {bitfield_t(4, 2, 4),   0x0004},
  material    = {bitfield_t(4, 4, 0),   0x0004},
}

local z64_col_hdr_t = 
{
  vtx           = {z64_xyz_t,       0x0010, 1},
  n_poly        = {u16_t,           0x0014},
  poly          = {z64_col_poly_t,  0x0018, 1},
  type          = {z64_col_type_t,  0x001C, 1},
}

local z64_game =
{
  _addr         = addresses.ctxt,
  col_hdr       = {z64_col_hdr_t, 0x00830, 1},
  pause_state   = {u16_t,         addresses.pause_state},
}

-- defines
local BUTTON_D_RIGHT            = 0x0100
local BUTTON_D_LEFT             = 0x0200
local BUTTON_D_DOWN             = 0x0400
local BUTTON_D_UP               = 0x0800
local SETTINGS_COLVIEW_DECAL    = 0
local SETTINGS_COLVIEW_SURFACE  = 1

-- locals
local col_view_state  = 0
local col_view_disp   = addresses.brk
local xlu
local settings =
{
  col_view_xlu  = true,
  col_view_rd   = false,
  col_view_mode = SETTINGS_COLVIEW_DECAL,
}

-- code
function bitfield(...)
  local arg = {...}
  local result = 0
  for i = 1, #arg do
    local field = arg[i]
    local value = field[1]
    local bits = field[2]
    local shift = field[3]
    local part = bit.lshift(bit.band(value, bit.lshift(1, bits) - 1), shift)
    result = bit.bor(result, part)
  end
  return result
end

function gfx_cmd(p, hi, lo)
  a = p:_get()
  mainmemory.write_u32_be(k0_to_phys(a), hi)
  a = a + 4
  mainmemory.write_u32_be(k0_to_phys(a), lo)
  a = a + 4
  p:_set(a)
  return p
end

function gDPPipeSync(p)
  local hi = bitfield({0xE7, 8, 24})
  return gfx_cmd(p, hi, 0)
end

function gDPSetPrimColor(p, m, l, r, g, b, a)
  local hi = bitfield({0xFA, 8, 24}, {m, 8, 8}, {l, 8, 0})
  local lo = bitfield({r, 8, 24}, {g, 8, 16}, {b, 8, 8}, {a, 8, 0})
  return gfx_cmd(p, hi, lo)
end

function gDPSetCycleType(p, cc)
  local hi = bitfield({0xE3, 8, 24}, {20, 8, 8}, {1, 8, 0})
  return gfx_cmd(p, hi, cc)
end

function gDPSetRenderMode(p, mode1, mode2)
  local hi = bitfield({0xE2, 8, 24}, {0, 8, 8}, {28, 8, 0})
  return gfx_cmd(p, hi, bit.bor(mode1, mode2))
end

function gSP1Triangle(p, v0, v1, v2, flag)
  local v = {v0, v1, v2}
  local hi = bitfield({0x05, 8, 24},
                      {v[1 + (0 + flag) % 3] * 2, 8, 16}, 
                      {v[1 + (1 + flag) % 3] * 2, 8, 8}, 
                      {v[1 + (2 + flag) % 3] * 2, 8, 0})
  return gfx_cmd(p, hi, 0)
end

function gSPDisplayList(p, dl)
  local hi = bitfield({0xDE, 8, 24})
  return gfx_cmd(p, hi, dl)
end

function gSPEndDisplayList(p)
  local hi = bitfield({0xDF, 8, 24})
  return gfx_cmd(p, hi, 0)
end

function gSPLoadGeometryMode(p, mode)
  local hi = bitfield({0xD9, 8, 24})
  return gfx_cmd(p, hi, mode)
end

function gSPMatrix(p, matrix, param)
  local hi = bitfield({0xDA, 8, 24}, {7, 5, 19}, {bit.bxor(param, 1), 8, 0})
  return gfx_cmd(p, hi, matrix)
end

function gSPTexture(p, sc, tc, level, tile, on)
  local hi = bitfield({0xD7, 8, 24}, {level, 3, 11}, {tile, 3, 8}, {on, 7, 1})
  local lo = bitfield({sc, 16, 16}, {tc, 16, 0})
  return gfx_cmd(p, hi, lo)
end

function gSPVertex(p, v, n, v0)
  local hi = bitfield({0x01, 8, 24}, {n, 8, 12}, {v0 + n, 7, 1})
  return gfx_cmd(p, hi, v)
end

function gDPSetCombine(p, modehi, modelo)
  local hi = bitfield({0xFC, 8, 24}, {modehi, 24, 0})
  return gfx_cmd(p, hi, modelo)
end

function gDisplayListAlloc(d, size)
  local a = d:_get()
  a = a - math.floor((size + 7) / 8) * 8
  d:_set(a)
  return a
end

function guMtxIdent(mtx)
  for n = 0, 15 do
    local i = sref(mtx, "i", n)
    local f = sref(mtx, "f", n)
    if n % 5 == 0 then
      i:_set(1)
    else
      i:_set(0)
    end
    f:_set(0)
  end
end

function main_hook()
  local pp = sref(z64_ctxt, "input", "pad_pressed"):_get()
  if bit.band(pp, BUTTON_D_UP) == BUTTON_D_UP then
    if col_view_state == 0 then
      col_view_state = 1
    elseif col_view_state == 2 then
      col_view_state = 3
    end
  end
  if bit.band(pp, BUTTON_D_DOWN) == BUTTON_D_DOWN then
    settings.col_view_mode = 1 - settings.col_view_mode
  end
  if bit.band(pp, BUTTON_D_LEFT) == BUTTON_D_LEFT then
    settings.col_view_xlu = not settings.col_view_xlu
  end
  if bit.band(pp, BUTTON_D_RIGHT) == BUTTON_D_RIGHT then
    settings.col_view_rd = not settings.col_view_rd
  end

  -- build collision view display list
  if col_view_state == 1 then
    xlu = settings.col_view_xlu
    local col_hdr = sref(z64_game, "col_hdr", deref)
    local n_poly = sref(col_hdr, "n_poly"):_get()
    local size = 0x10 + 9 * n_poly
    local p = sobj(mp_t, col_view_disp)
    local d = sobj(mp_t, col_view_disp + 8 * size)
    gDPPipeSync(p)
    gDPSetCycleType(p, 0x00100000) -- G_CYC_2CYCLE
    local rm
    local blc1
    local blc2
    local alpha
    if xlu then
      rm = 0x00004250 -- Z_CMP | IM_RD | CVG_DST_FULL | FORCE_BL
      blc1 = 0x00400000 -- GBL_c1(G_BL_CLR_IN, G_BL_A_IN, G_BL_CLR_MEM, G_BL_1MA)
      blc2 = 0x00100000 -- GBL_c2(G_BL_CLR_IN, G_BL_A_IN, G_BL_CLR_MEM, G_BL_1MA)
      alpha = 0x80
    else
      rm = 0x00004070 -- Z_CMP | Z_UPD | IM_RD | CVG_DST_CLAMP | FORCE_BL
      blc1 = 0x0C080000 -- GBL_c1(G_BL_CLR_IN, G_BL_0, G_BL_CLR_IN, G_BL_1)
      blc2 = 0x03020000 -- GBL_c2(G_BL_CLR_IN, G_BL_0, G_BL_CLR_IN, G_BL_1)
      alpha = 0xFF
    end
    if settings.col_view_mode == SETTINGS_COLVIEW_DECAL then
      rm = bit.bor(rm, 0x00000C00) -- ZMODE_DEC
    elseif xlu then
      rm = bit.bor(rm, 0x00000800) -- ZMODE_XLU
    else
      rm = bit.bor(rm, 0x00000000) -- ZMODE_OPA
    end
    gDPSetRenderMode(p, bit.bor(rm, blc1), bit.bor(rm, blc2))
    gDPSetCombine(p, 0x00FFFE04, 0xFF11F7FF) -- G_CC_MODE(G_CC_PRIMITIVE, G_CC_MODULATERGBA2)
    gSPTexture(p,
               0x8000, -- qu016(0.5)
               0x8000, -- qu016(0.5)
               0,
               0, -- G_TX_RENDERTILE
               0) -- G_OFF
    gSPLoadGeometryMode(p, 0x00020405) -- G_SHADE | G_LIGHTING | G_ZBUFFER | G_CULL_BACK
    local mtx = sobj(Mtx, gDisplayListAlloc(d, Mtx._size))
    guMtxIdent(mtx)
    gSPMatrix(p, mtx._addr, 0x00000002) -- G_MTX_MODELVIEW | G_MTX_LOAD
    for i = 0, n_poly - 1 do
      local poly = sref(col_hdr, "poly", deref, i)
      local type = sref(col_hdr, "type", deref, sref(poly, "type"):_get())
      local skip = false
      if sref(type, "hookshot"):_get() == 1 then
        gDPSetPrimColor(p, 0, 0, 0x80, 0x80, 0xFF, alpha)
      elseif sref(type, "interaction"):_get() > 0x01 then
        gDPSetPrimColor(p, 0, 0, 0xC0, 0x00, 0xC0, alpha)
      elseif sref(type, "special"):_get() == 0x0C then
        gDPSetPrimColor(p, 0, 0, 0xFF, 0x00, 0x00, alpha)
      elseif sref(type, "exit"):_get() ~= 0x00 or sref(type, "special"):_get() == 0x05 then
        gDPSetPrimColor(p, 0, 0, 0x00, 0xFF, 0x00, alpha)
      elseif sref(type, "behavior"):_get() ~= 0 or sref(type, "wall_damage"):_get() == 1 then
        gDPSetPrimColor(p, 0, 0, 0xC0, 0xFF, 0xC0, alpha)
      elseif sref(type, "terrain"):_get() == 0x01 then
        gDPSetPrimColor(p, 0, 0, 0xFF, 0xFF, 0x80, alpha)
      elseif settings.col_view_rd then
        skip = true
      else
        gDPSetPrimColor(p, 0, 0, 0xFF, 0xFF, 0xFF, alpha)
      end
      if not skip then
        local norm = sref(poly, "norm")
        local nx = sref(norm, "x"):_get() / 0x100
        local ny = sref(norm, "y"):_get() / 0x100
        local nz = sref(norm, "z"):_get() / 0x100
        local vtx = sref(col_hdr, "vtx", deref)
        local v = {sref(vtx, sref(poly, "va"):_get()),
                   sref(vtx, sref(poly, "vb"):_get()),
                   sref(vtx, sref(poly, "vc"):_get())}
        local vg = sobj(Vtx_tn, gDisplayListAlloc(d, Vtx_tn._size * 3))
        for i = 0, 2 do
          local vn = sind(vg, i)
          sref(vn, "ob", 0):_set(sref(v[1 + i], "x"):_get())
          sref(vn, "ob", 1):_set(sref(v[1 + i], "y"):_get())
          sref(vn, "ob", 2):_set(sref(v[1 + i], "z"):_get())
          sref(vn, "n", 0):_set(nx)
          sref(vn, "n", 1):_set(ny)
          sref(vn, "n", 2):_set(nz)
          sref(vn, "a", 0):_set(0xFF)
        end
        gSPVertex(p, vg._addr, 3, 0)
        gSP1Triangle(p, 0, 1, 2, 0)
      end
    end
    gSPEndDisplayList(p)
    col_view_state = 2
  end
  local pause_state = sref(z64_game, "pause_state"):_get()
  if col_view_state == 2 and col_view_disp ~= 0 and pause_state == 0 then
    local p
    if xlu then
      p = sref(z64_ctxt, "gfx", deref, "poly_xlu", "p")
    else
      p = sref(z64_ctxt, "gfx", deref, "poly_opa", "p")
    end
    gSPDisplayList(p, col_view_disp)
  end
  if col_view_state == 3 then
    col_view_state = 0
  end
end

event.onmemoryexecute(main_hook, addresses.hook)
