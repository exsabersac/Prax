/**
 * U9/U12：多地点像素风世界地图（纯前端装饰）。
 * placeId → 静态像素区；不回写 Session / 世界。
 * 角色只落「当前 View 同场」区；其它区仅地标/空区，不伪造超 View 演员。
 * 地点集合仍：广场 / 磨坊 + 装饰性小桥（不扩世界契约）。
 * U12：路径脊柱/路标可读再精修；仍不新增世界契约地点。
 */

export const VIEW_W = 640;
export const VIEW_H = 360;

/** 世界大于视口，镜头可逛开 */
export const WORLD_W = 1400;
export const WORLD_H = 640;

/**
 * @typedef {{ id: string, label: string, x: number, y: number, w: number, h: number,
 *   floor: number, accent: number, sky: number, path: number, decorative?: boolean }} PlaceZone
 */

/** @type {Record<string, PlaceZone>} */
export const PLACES = {
  square: {
    id: "square",
    label: "广场",
    x: 40,
    y: 56,
    w: 500,
    h: 420,
    floor: 0x6f9260,
    accent: 0x4e6b42,
    sky: 0x8eb8d4,
    path: 0x9aaf7a,
  },
  mill: {
    id: "mill",
    label: "磨坊",
    x: 700,
    y: 56,
    w: 500,
    h: 420,
    floor: 0xb08a5c,
    accent: 0x7a5f3c,
    sky: 0xc4a882,
    path: 0xc4a878,
  },
  /** 装饰性第三区：不进世界契约，仅镜头可逛 / 地标可读 */
  bridge: {
    id: "bridge",
    label: "小桥",
    x: 520,
    y: 460,
    w: 360,
    h: 150,
    floor: 0x5a7a6a,
    accent: 0x3d5a4e,
    sky: 0x7aa8b8,
    path: 0x8a9a7a,
    decorative: true,
  },
};

/** U9/U12：装饰路径脊柱（世界坐标，仅画用地标/层次，不扩地点集合） */
export const PATH_SPINE = [
  // 广场环路
  { x: 120, y: 250, w: 320, h: 14 },
  { x: 260, y: 160, w: 14, h: 200 },
  // 广场→磨坊主干
  { x: 500, y: 230, w: 240, h: 40 },
  // 主干→小桥
  { x: 660, y: 268, w: 36, h: 210 },
  // U12：主干向磨坊延伸一段（仍装饰，不新地点）
  { x: 720, y: 236, w: 90, h: 28 },
];

/**
 * U12：装饰路标（中文指向，不扩世界契约地点 id）
 * @type {Array<{ x:number, y:number, label:string, dir?:'e'|'s'|'w'|'n' }>}
 */
export const SIGNPOSTS = [
  { x: 488, y: 200, label: "→ 磨坊", dir: "e" },
  { x: 678, y: 300, label: "↓ 小桥", dir: "s" },
  { x: 730, y: 210, label: "← 广场", dir: "w" },
];

/** 区内相对站位（相对 zone 中心） */
const LOCAL_SLOTS = {
  square: {
    you: [0, 48],
    bob: [-120, -16],
    carol: [120, -16],
    dana: [-72, -96],
    eve: [72, -96],
    gale: [0, -48],
  },
  mill: {
    you: [0, 48],
    bob: [-108, -12],
    carol: [108, -12],
    dana: [-64, -88],
    eve: [64, -88],
    gale: [0, -44],
  },
};

const FALLBACK = [
  [0, 24],
  [-96, -8],
  [96, -8],
  [-56, 72],
  [56, 72],
  [0, -72],
];

export function placeZone(placeId) {
  return PLACES[placeId] || PLACES.square;
}

/** 镜头中心落在哪块像素区（用于 HUD 画面标签） */
export function placeZoneAt(worldX, worldY) {
  // 先匹配非装饰区，再装饰区
  const ordered = Object.values(PLACES).sort(
    (a, b) => Number(!!a.decorative) - Number(!!b.decorative)
  );
  for (const z of ordered) {
    if (
      worldX >= z.x &&
      worldX <= z.x + z.w &&
      worldY >= z.y &&
      worldY <= z.y + z.h
    ) {
      return z;
    }
  }
  return null;
}

/** 世界坐标站位（仅用于当前 View 同场角色；装饰区无槽） */
export function worldSlot(placeId, actorId, index = 0) {
  const z = placeZone(placeId);
  const cx = z.x + z.w / 2;
  const cy = z.y + z.h / 2 + 12;
  const map = LOCAL_SLOTS[placeId] || LOCAL_SLOTS.square;
  const off = map[actorId] || FALLBACK[index % FALLBACK.length];
  return [Math.round(cx + off[0]), Math.round(cy + off[1])];
}

/** 镜头初始对准该地点中心；viewW/viewH 随 U7 逻辑尺寸 */
export function cameraFocusFor(placeId, viewW = VIEW_W, viewH = VIEW_H) {
  const z = placeZone(placeId);
  const vw = viewW > 0 ? viewW : VIEW_W;
  const vh = viewH > 0 ? viewH : VIEW_H;
  return {
    x: Math.round(z.x + z.w / 2 - vw / 2),
    y: Math.round(z.y + z.h / 2 - vh / 2),
  };
}

/** 镜头 scroll clamp；view 尺寸随布局变时传入当前逻辑宽高 */
export function clampCamera(scrollX, scrollY, viewW = VIEW_W, viewH = VIEW_H) {
  const vw = viewW > 0 ? viewW : VIEW_W;
  const vh = viewH > 0 ? viewH : VIEW_H;
  const maxX = Math.max(0, WORLD_W - vw);
  const maxY = Math.max(0, WORLD_H - vh);
  return {
    x: Math.max(0, Math.min(maxX, scrollX)),
    y: Math.max(0, Math.min(maxY, scrollY)),
  };
}
