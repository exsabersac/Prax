/**
 * U1–U3：placeId→像素站位与角色色（纯前端装饰，不回写世界）。
 * U2：站位避开右侧 Menu 与底部叙事条。
 * U3：站位更疏、比例可读；场景装饰色。
 */

export const PLACE_FLOOR = {
  square: 0x6f9260,
  mill: 0xb08a5c,
};

export const PLACE_ACCENT = {
  square: 0x4e6b42,
  mill: 0x7a5f3c,
};

/** 场景浅景 / 深景装饰色 */
export const PLACE_SKY = {
  square: 0x8eb8d4,
  mill: 0xc4a882,
};

export const PLACE_PATH = {
  square: 0x9aaf7a,
  mill: 0xc4a878,
};

export const ACTOR_FILL = {
  you: 0x2f6f4e,
  bob: 0x3d5a80,
  carol: 0x9b5de5,
  dana: 0xe07a3d,
  eve: 0xc44569,
  gale: 0x457b9d,
};

/** 各地点固定站位（640×360）；U3 拉开间距，避开 Menu(x≳420) 与 Log(y≳250) */
const SLOTS = {
  square: {
    you: [200, 200],
    bob: [95, 155],
    carol: [305, 155],
    dana: [130, 88],
    eve: [270, 88],
    gale: [200, 118],
  },
  mill: {
    you: [200, 200],
    bob: [100, 150],
    carol: [300, 150],
    dana: [140, 85],
    eve: [260, 85],
    gale: [200, 115],
  },
};

const FALLBACK_RING = [
  [200, 165],
  [105, 140],
  [295, 140],
  [140, 205],
  [260, 205],
  [200, 95],
];

export function actorFill(id) {
  return ACTOR_FILL[id] || 0x666666;
}

export function floorColor(placeId) {
  return PLACE_FLOOR[placeId] || 0x6a7a6a;
}

export function accentColor(placeId) {
  return PLACE_ACCENT[placeId] || 0x555555;
}

export function skyColor(placeId) {
  return PLACE_SKY[placeId] || 0x90a0b0;
}

export function pathColor(placeId) {
  return PLACE_PATH[placeId] || 0x8a9a7a;
}

/** @returns {[number, number]} */
export function slotFor(placeId, actorId, index = 0) {
  const map = SLOTS[placeId] || SLOTS.square;
  if (map[actorId]) return map[actorId];
  return FALLBACK_RING[index % FALLBACK_RING.length];
}
