#include <startup.h>
#include <n64.h>
#include "gu.h"
#include "input.h"
#include "z64-mm.h"

#define SETTINGS_COLVIEW_DECAL      0
#define SETTINGS_COLVIEW_SURFACE    1

struct settings
{
  _Bool col_view_xlu;
  _Bool col_view_line;
  _Bool col_view_shade;
  _Bool col_view_rd;
  int   col_view_mode;
};

__attribute__((section(".data")))
static int                  col_view_state = 0;
__attribute__((section(".data")))
static struct settings      settings =
{
  1, 0, 1, 0, SETTINGS_COLVIEW_DECAL,
};

ENTRY void _start()
{
  init_gp();

  uint16_t pad = z64_ctxt.input[0].raw.pad;
  uint16_t pp = z64_ctxt.input[0].pad_pressed;
  if (pp & BUTTON_D_UP) {
    if (col_view_state == 0)
      col_view_state = 1;
    else if (col_view_state == 2)
      col_view_state = 3;
  }
  if (pp & BUTTON_D_DOWN)
    settings.col_view_mode = !settings.col_view_mode;
  if (pp & BUTTON_D_LEFT) {
    if (pad & BUTTON_Z)
      settings.col_view_shade = !settings.col_view_shade;
    else
      settings.col_view_xlu = !settings.col_view_xlu;
  }
  if (pp & BUTTON_D_RIGHT) {
    if (pad & BUTTON_Z)
      settings.col_view_line = !settings.col_view_line;
    else
      settings.col_view_rd = !settings.col_view_rd;
  }

/*
  __attribute__((section(".data")))
  static Gfx *col_view_disp;
*/
  Gfx *const col_view_disp = (void*)z64_brk_addr;
  __attribute__((section(".data")))
  static _Bool xlu;
  /* build collision view display list */
  if (col_view_state == 1) {
    xlu = settings.col_view_xlu;
    z64_col_hdr_t *col_hdr = z64_game.col_hdr;
    size_t size = (0x10 + 0xF) + (9 + 11) * col_hdr->n_poly;
/*
    if (col_view_disp)
      z64_Free(&z64_game_arena, col_view_disp);
    col_view_disp = z64_Alloc(&z64_game_arena, sizeof(*col_view_disp) * size);
*/
    Gfx *p = col_view_disp;
    Gfx *d = col_view_disp + size;
    uint8_t alpha = xlu ? 0x80 : 0xFF;
    {
      uint32_t rm;
      uint32_t blc1;
      uint32_t blc2;
      if (xlu) {
        rm = Z_CMP | IM_RD | CVG_DST_FULL | FORCE_BL;
        blc1 = GBL_c1(G_BL_CLR_IN, G_BL_A_IN, G_BL_CLR_MEM, G_BL_1MA);
        blc2 = GBL_c2(G_BL_CLR_IN, G_BL_A_IN, G_BL_CLR_MEM, G_BL_1MA);
      }
      else {
        rm = Z_CMP | Z_UPD | IM_RD | CVG_DST_CLAMP | FORCE_BL;
        blc1 = GBL_c1(G_BL_CLR_IN, G_BL_0, G_BL_CLR_IN, G_BL_1);
        blc2 = GBL_c2(G_BL_CLR_IN, G_BL_0, G_BL_CLR_IN, G_BL_1);
      }
      if (settings.col_view_mode == SETTINGS_COLVIEW_DECAL)
        rm |= ZMODE_DEC;
      else if (xlu)
        rm |= ZMODE_XLU;
      else
        rm |= ZMODE_OPA;
      gDPPipeSync(p++);
      gDPSetRenderMode(p++, rm | blc1, rm | blc2);
      gSPTexture(p++, qu016(0.5), qu016(0.5), 0, G_TX_RENDERTILE, G_OFF);
      if (settings.col_view_shade) {
        gDPSetCycleType(p++, G_CYC_2CYCLE);
        gDPSetCombineMode(p++, G_CC_PRIMITIVE, G_CC_MODULATERGBA2);
        gSPLoadGeometryMode(p++, G_SHADE | G_LIGHTING | G_ZBUFFER | G_CULL_BACK);
      }
      else {
        gDPSetCycleType(p++, G_CYC_1CYCLE);
        gDPSetCombineMode(p++, G_CC_PRIMITIVE, G_CC_PRIMITIVE);
        gSPLoadGeometryMode(p++, G_ZBUFFER | G_CULL_BACK);
      }
      Mtx m;
      guMtxIdent(&m);
      gSPMatrix(p++, gDisplayListData(&d, m), G_MTX_MODELVIEW | G_MTX_LOAD);
    }
    for (int i = 0; i < col_hdr->n_poly; ++i) {
      z64_col_poly_t *poly = &col_hdr->poly[i];
      z64_col_type_t *type = &col_hdr->type[poly->type];
      if (type->flags_2.hookshot)
        gDPSetPrimColor(p++, 0, 0, 0x80, 0x80, 0xFF, alpha);
      else if (type->flags_1.interaction > 0x01)
        gDPSetPrimColor(p++, 0, 0, 0xC0, 0x00, 0xC0, alpha);
      else if (type->flags_1.special == 0x0C)
        gDPSetPrimColor(p++, 0, 0, 0xFF, 0x00, 0x00, alpha);
      else if (type->flags_1.exit != 0x00 || type->flags_1.special == 0x05)
        gDPSetPrimColor(p++, 0, 0, 0x00, 0xFF, 0x00, alpha);
      else if (type->flags_1.behavior != 0 || type->flags_2.wall_damage)
        gDPSetPrimColor(p++, 0, 0, 0xC0, 0xFF, 0xC0, alpha);
      else if (type->flags_2.terrain == 0x01)
        gDPSetPrimColor(p++, 0, 0, 0xFF, 0xFF, 0x80, alpha);
      else if (settings.col_view_rd)
        continue;
      else
        gDPSetPrimColor(p++, 0, 0, 0xFF, 0xFF, 0xFF, alpha);
      z64_xyz_t *va = &col_hdr->vtx[poly->va];
      z64_xyz_t *vb = &col_hdr->vtx[poly->vb];
      z64_xyz_t *vc = &col_hdr->vtx[poly->vc];
      Vtx vg[3] =
      {
        gdSPDefVtxN(va->x, va->y, va->z, 0, 0,
                    poly->norm.x / 0x100, poly->norm.y / 0x100,
                    poly->norm.z / 0x100, 0xFF),
        gdSPDefVtxN(vb->x, vb->y, vb->z, 0, 0,
                    poly->norm.x / 0x100, poly->norm.y / 0x100,
                    poly->norm.z / 0x100, 0xFF),
        gdSPDefVtxN(vc->x, vc->y, vc->z, 0, 0,
                    poly->norm.x / 0x100, poly->norm.y / 0x100,
                    poly->norm.z / 0x100, 0xFF),
      };
      gSPVertex(p++, gDisplayListData(&d, vg), 3, 0);
      gSP1Triangle(p++, 0, 1, 2, 0);
    }
    if (settings.col_view_line) {
      gDPPipeSync(p++);
      if (xlu)
        gDPSetRenderMode(p++, G_RM_AA_ZB_XLU_LINE, G_RM_AA_ZB_XLU_LINE2);
      else
        gDPSetRenderMode(p++, G_RM_AA_ZB_DEC_LINE, G_RM_AA_ZB_DEC_LINE2);
      gDPSetCycleType(p++, G_CYC_1CYCLE);
      gDPSetCombineMode(p++, G_CC_PRIMITIVE, G_CC_PRIMITIVE);
      gSPLoadGeometryMode(p++, G_ZBUFFER);
      gDPSetPrimColor(p++, 0, 0, 0x00, 0x00, 0x00, alpha);
      for (int i = 0; i < col_hdr->n_poly; ++i) {
        z64_col_poly_t *poly = &col_hdr->poly[i];
        z64_xyz_t *va = &col_hdr->vtx[poly->va];
        z64_xyz_t *vb = &col_hdr->vtx[poly->vb];
        z64_xyz_t *vc = &col_hdr->vtx[poly->vc];
        Vtx vg[3] =
        {
          gdSPDefVtxC(va->x, va->y, va->z, 0, 0, 0x00, 0x00, 0x00, 0xFF),
          gdSPDefVtxC(vb->x, vb->y, vb->z, 0, 0, 0x00, 0x00, 0x00, 0xFF),
          gdSPDefVtxC(vc->x, vc->y, vc->z, 0, 0, 0x00, 0x00, 0x00, 0xFF),
        };
        gSPVertex(p++, gDisplayListData(&d, vg), 3, 0);
        gSPLine3D(p++, 0, 1, 0);
        gSPLine3D(p++, 1, 2, 0);
        gSPLine3D(p++, 2, 0, 0);
      }
    }
    gSPEndDisplayList(p++);
    col_view_state = 2;
  }
  if (col_view_state == 2 && col_view_disp && z64_game.pause_state == 0) {
    if (xlu)
      gSPDisplayList(z64_ctxt.gfx->poly_xlu.p++, col_view_disp);
    else
      gSPDisplayList(z64_ctxt.gfx->poly_opa.p++, col_view_disp);
  }
  if (col_view_state == 3)
    col_view_state = 4;
  else if (col_view_state == 4) {
    if (col_view_disp) {
/*  
      z64_Free(&z64_game_arena, col_view_disp);
      col_view_disp = NULL;
*/
    }
    col_view_state = 0;
  }
}
