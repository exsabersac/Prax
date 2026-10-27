/**
 * U1/U2：placeId→像素站位与角色色（纯前端装饰，不回写世界）。
 * U2：站位避开右侧 Menu 叠层（x≲410）与底部叙事条（y≲230）。
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
    you: [210, 210],
    bob: [110, 150],
    carol: [310, 150],
    dana: [150, 95],
    eve: [270, 95],
    gale: [210, 120],
  },
  mill: {
    you: [210, 210],
    bob: [120, 145],
    carol: [300, 145],
    dana: [160, 90],
    eve: [260, 90],
    gale: [210, 115],
  },
};

const FALLBACK_RING = [
  [210, 170],
  [120, 140],
  [300, 140],
  [150, 210],
  [270, 210],
  [210, 95],
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
