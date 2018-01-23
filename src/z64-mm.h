#ifndef Z64_H
#define Z64_H
#include <stdint.h>
#include <n64.h>

#ifndef Z64_VERSION
#error no z64 version specified
#endif

#define Z64_MM10J             0x00
#define Z64_MM10U             0x01

typedef struct z64_arena      z64_arena_t;
typedef struct z64_arena_node z64_arena_node_t;

struct z64_arena
{
  z64_arena_node_t *first_node;
  void             *start;
};

struct z64_arena_node
{
  uint16_t          magic;
  uint16_t          free;
  uint32_t          size;
  z64_arena_node_t *next;
  z64_arena_node_t *prev;
#if Z64_VERSION == Z64_MM10J
  char             *filename;
  int32_t           line;
  OSId              thread_id;
  z64_arena_t      *arena;
  uint32_t          count_hi;
  uint32_t          count_lo;
  char              pad_00_[0x0008];
#endif
  char              data[];
};

typedef struct
{
  int16_t x;
  int16_t y;
  int16_t z;
} z64_xyz_t;

typedef uint16_t z64_angle_t;
typedef struct
{
  z64_angle_t x;
  z64_angle_t y;
  z64_angle_t z;
} z64_rot_t;

typedef struct
{
  /* index of z64_col_type in scene file */
  uint16_t    type;
  /* vertex indices, a and b are bitmasked for some reason */
  struct
  {
    uint16_t  unk_00_ : 3;
    uint16_t  va      : 13;
  };
  struct
  {
    uint16_t  unk_01_ : 3;
    uint16_t  vb      : 13;
  };
  uint16_t    vc;
  /* normal vector */
  z64_xyz_t   norm;
  /* plane distance from origin */
  int16_t     dist;
} z64_col_poly_t;

typedef struct
{
  struct
  {
    uint32_t  unk_00_     : 1;
    uint32_t  drop        : 1; /* link drops one unit into the floor */
    uint32_t  special     : 4;
    uint32_t  interaction : 5;
    uint32_t  unk_01_     : 3;
    uint32_t  behavior    : 5;
    uint32_t  exit        : 5;
    uint32_t  camera      : 8;
  } flags_1;                    /* 0x0000 */
  struct
  {
    uint32_t  pad_00_     : 4;
    uint32_t  wall_damage : 1;
    uint32_t  unk_00_     : 6;
    uint32_t  unk_01_     : 3;
    uint32_t  hookshot    : 1;
    uint32_t  echo        : 6;
    uint32_t  unk_02_     : 5;
    uint32_t  terrain     : 2;
    uint32_t  material    : 4;
  } flags_2;                    /* 0x0004 */
} z64_col_type_t;

typedef struct
{
  z64_xyz_t pos;
  z64_xyz_t rot;
  int16_t   fov;
  int16_t   unk_00_;
} z64_camera_params_t;

typedef struct
{
  uint16_t mode;
  uint16_t unk_01_;
  uint32_t seg_params; /* segment address of z64_camera_params_t */
} z64_camera_t;

typedef struct
{
  z64_xyz_t     pos;
  int16_t       width;
  int16_t       depth;
  struct
  {
    uint32_t    unk_00_ : 12;
    uint32_t    active  : 1;
    uint32_t    group   : 6; /* ? */
    uint32_t    unk_01_ : 5;
    uint32_t    camera  : 8;
  } flags;
} z64_col_water_t;

typedef struct
{
  z64_xyz_t         min;
  z64_xyz_t         max;
  uint16_t          n_vtx;
  z64_xyz_t        *vtx;
  uint16_t          n_poly;
  z64_col_poly_t   *poly;
  z64_col_type_t   *type;
  z64_camera_t     *camera;
  uint16_t          n_water;
  z64_col_water_t  *water;
} z64_col_hdr_t;

typedef struct
{
  uint32_t  size;
  Gfx      *buf;
  Gfx      *p;      /* command pointer */
  Gfx      *d;      /* data pointer */
} z64_gfx_buf_t;

typedef struct
{
  char          unk_00_[0x01A4];  /* 0x0000 */
  /* executed 1st */
  z64_gfx_buf_t unk_01_;          /* 0x01A4 */
  char          unk_02_[0x0004];  /* 0x01B4 */
  /* executed 5th */
  z64_gfx_buf_t unk_03_;          /* 0x01B8 */
  char          unk_04_[0x00D0];  /* 0x01C8 */
  /* executed 2nd-4th: poly_opa, poly_xlu, overlay */
  z64_gfx_buf_t overlay;          /* 0x0298 */
  z64_gfx_buf_t poly_opa;         /* 0x02A8 */
  z64_gfx_buf_t poly_xlu;         /* 0x02B8 */
  uint32_t      frame_count;      /* 0x02C8 */
} z64_gfx_t;

typedef struct
{
  union
  {
    struct
    {
      uint16_t  a  : 1;
      uint16_t  b  : 1;
      uint16_t  z  : 1;
      uint16_t  s  : 1;
      uint16_t  du : 1;
      uint16_t  dd : 1;
      uint16_t  dl : 1;
      uint16_t  dr : 1;
      uint16_t     : 2;
      uint16_t  l  : 1;
      uint16_t  r  : 1;
      uint16_t  cu : 1;
      uint16_t  cd : 1;
      uint16_t  cl : 1;
      uint16_t  cr : 1;
    };
    uint16_t    pad;
  };
  int8_t        x;
  int8_t        y;
} z64_controller_t;

typedef struct
{
  z64_controller_t  raw;
  uint16_t          unk_00_;
  z64_controller_t  raw_prev;
  uint16_t          unk_01_;
  uint16_t          pad_pressed;
  int8_t            x_diff;
  int8_t            y_diff;
  char              unk_02_[0x0002];
  uint16_t          pad_released;
  int8_t            adjusted_x;
  int8_t            adjusted_y;
  char              unk_03_[0x0002];
} z64_input_t;

/* context base */
typedef struct
{
  z64_gfx_t      *gfx;                    /* 0x0000 */
  void           *state_main;             /* 0x0004 */
  void           *state_dtor;             /* 0x0008 */
  void           *next_ctor;              /* 0x000C */
  uint32_t        next_size;              /* 0x0010 */
  z64_input_t     input[4];               /* 0x0014 */
  size_t          state_heap_size;        /* 0x0074 */
  void           *state_heap;             /* 0x0078 */
  void           *heap_start;             /* 0x007C */
  void           *heap_end;               /* 0x0080 */
  void           *state_heap_node;        /* 0x0084 */
  char            unk_00_[0x0010];        /* 0x0088 */
  int32_t         state_continue;         /* 0x0098 */
  int32_t         state_frames;           /* 0x009C */
  uint32_t        unk_01_;                /* 0x00A0 */
                                          /* 0x00A4 */
} z64_ctxt_t;

/* game context */
typedef struct
{
  z64_ctxt_t      common;                 /* 0x00000 */
  char            unk_00_[0x0078C];       /* 0x000A4 */
  z64_col_hdr_t  *col_hdr;                /* 0x00830 */
#if Z64_VERSION == Z64_MM10J
  char            unk_01_[0x166C8];       /* 0x00834 */
  uint16_t        pause_state;            /* 0x16EFC */
#elif Z64_VERSION == Z64_MM10U
  char            unk_01_[0x166E8];       /* 0x00834 */
  uint16_t        pause_state;            /* 0x16F1C */
#endif
} z64_game_t;

#if Z64_VERSION == Z64_MM10J

/* dram addresses */
#define z64_Alloc_addr                          0x80088000
#define z64_Free_addr                           0x8008827C
#define z64_game_arena_addr                     0x801F5280
#define z64_ctxt_addr                           0x803E6CF0
#define z64_brk_addr                            0x80780000

#elif Z64_VERSION == Z64_MM10U

/* dram addresses */
#define z64_Alloc_addr                          0x80087324
#define z64_Free_addr                           0x800874EC
#define z64_game_arena_addr                     0x801F5100
#define z64_ctxt_addr                           0x803E6B20
#define z64_brk_addr                            0x80780000

#endif

/* function prototypes */
typedef void *(*z64_Alloc_proc)           (z64_arena_t *arena, uint32_t size);
typedef void  (*z64_Free_proc)            (z64_arena_t *arena, void *ptr);

/* data */
#define z64_ctxt                (*(z64_ctxt_t*)       z64_ctxt_addr)
#define z64_game                (*(z64_game_t*)      &z64_ctxt)
#define z64_game_arena          (*(z64_arena_t*)      z64_game_arena_addr)

/* functions */
#define z64_Alloc               ((z64_Alloc_proc)     z64_Alloc_addr)
#define z64_Free                ((z64_Free_proc)      z64_Free_addr)

#endif
