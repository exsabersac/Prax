/**
 * U1：placeId→像素站位与角色色（纯前端装饰，不回写世界）。
 */

export const PLACE_FLOOR = {
  square: 0x7a9e6a,
  mill: 0xb8956a,
};

export const PLACE_ACCENT = {
  square: 0x5f7f52,
  mill: 0x8a6d48,
};

export const ACTOR_FILL = {
  you: 0x2f6f4e,
  bob: 0x3d5a80,
  carol: 0x9b5de5,
  dana: 0xe07a3d,
  eve: 0xc44569,
  gale: 0x457b9d,
};

/** 各地点固定站位（像素，相对 640×360 场景）；缺省时按索引扇开 */
const SLOTS = {
  square: {
    you: [320, 260],
    bob: [160, 180],
    carol: [480, 180],
    dana: [220, 120],
    eve: [420, 120],
    gale: [320, 140],
  },
  mill: {
    you: [320, 250],
    bob: [180, 160],
    carol: [460, 160],
    dana: [240, 100],
    eve: [400, 100],
    gale: [320, 130],
  },
};

const FALLBACK_RING = [
  [320, 200],
  [200, 160],
  [440, 160],
  [240, 260],
  [400, 260],
  [320, 100],
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

/** @returns {[number, number]} */
export function slotFor(placeId, actorId, index = 0) {
  const map = SLOTS[placeId] || SLOTS.square;
  if (map[actorId]) return map[actorId];
  return FALLBACK_RING[index % FALLBACK_RING.length];
}
