/**
 * U4：多地点像素风世界地图（纯前端装饰）。
 * placeId → 静态像素区；不回写 Session / 世界。
 * 角色只落「当前 View 同场」区；其它区仅地标/空区，不伪造超 View 演员。
 */

export const VIEW_W = 640;
export const VIEW_H = 360;

/** 世界大于视口，镜头可逛开 */
export const WORLD_W = 1280;
export const WORLD_H = 560;

/**
 * @typedef {{ id: string, label: string, x: number, y: number, w: number, h: number,
 *   floor: number, accent: number, sky: number, path: number }} PlaceZone
 */

/** @type {Record<string, PlaceZone>} */
export const PLACES = {
  square: {
    id: "square",
    label: "广场",
    x: 48,
    y: 48,
    w: 520,
    h: 440,
    floor: 0x6f9260,
    accent: 0x4e6b42,
    sky: 0x8eb8d4,
    path: 0x9aaf7a,
  },
  mill: {
    id: "mill",
    label: "磨坊",
    x: 700,
    y: 48,
    w: 520,
    h: 440,
    floor: 0xb08a5c,
    accent: 0x7a5f3c,
    sky: 0xc4a882,
    path: 0xc4a878,
  },
};

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

/** 世界坐标站位（仅用于当前 View 同场角色） */
export function worldSlot(placeId, actorId, index = 0) {
  const z = placeZone(placeId);
  const cx = z.x + z.w / 2;
  const cy = z.y + z.h / 2 + 12;
  const map = LOCAL_SLOTS[placeId] || LOCAL_SLOTS.square;
  const off = map[actorId] || FALLBACK[index % FALLBACK.length];
  return [Math.round(cx + off[0]), Math.round(cy + off[1])];
}

/** 镜头初始对准该地点中心 */
export function cameraFocusFor(placeId) {
  const z = placeZone(placeId);
  return {
    x: Math.round(z.x + z.w / 2 - VIEW_W / 2),
    y: Math.round(z.y + z.h / 2 - VIEW_H / 2),
  };
}

export function clampCamera(scrollX, scrollY) {
  const maxX = Math.max(0, WORLD_W - VIEW_W);
  const maxY = Math.max(0, WORLD_H - VIEW_H);
  return {
    x: Math.max(0, Math.min(maxX, scrollX)),
    y: Math.max(0, Math.min(maxY, scrollY)),
  };
}
