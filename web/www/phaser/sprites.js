/**
 * U4：程序化像素人物（自研几何帧，非 GA/CuteRPG 素材）。
 * 生成 idle / walk 两帧纹理，供 TownScene 播放。
 */

const FRAME_W = 16;
const FRAME_H = 24;

/**
 * 在 Graphics 上画一帧小人（像素块）。
 * @param {Phaser.GameObjects.Graphics} g
 * @param {number} fill 身体主色
 * @param {0|1} frame 0=idle 1=walk（腿错位）
 */
function paintFrame(g, fill, frame) {
  g.clear();
  // 头
  g.fillStyle(0xffe0bd, 1);
  g.fillRect(5, 1, 6, 6);
  // 发/帽沿
  const hair = ((fill >> 1) & 0x7f7f7f) | 0x202020;
  g.fillStyle(hair, 1);
  g.fillRect(5, 0, 6, 2);
  // 身
  g.fillStyle(fill, 1);
  g.fillRect(4, 7, 8, 9);
  // 手臂
  g.fillStyle(0xffe0bd, 1);
  if (frame === 0) {
    g.fillRect(2, 8, 2, 6);
    g.fillRect(12, 8, 2, 6);
  } else {
    g.fillRect(1, 9, 2, 5);
    g.fillRect(13, 7, 2, 6);
  }
  // 腿
  g.fillStyle(0x2a2a28, 1);
  if (frame === 0) {
    g.fillRect(5, 16, 3, 7);
    g.fillRect(9, 16, 3, 7);
  } else {
    g.fillRect(4, 16, 3, 7);
    g.fillRect(10, 15, 3, 8);
  }
  // 鞋
  g.fillStyle(0x1a1a18, 1);
  if (frame === 0) {
    g.fillRect(4, 22, 4, 2);
    g.fillRect(9, 22, 4, 2);
  } else {
    g.fillRect(3, 22, 4, 2);
    g.fillRect(10, 22, 4, 2);
  }
}

/**
 * 为角色生成 idle/walk 纹理键（幂等）。
 * @param {Phaser.Scene} scene
 * @param {string} actorId
 * @param {number} fill
 * @returns {{ idle: string, walk: string, w: number, h: number }}
 */
export function ensureActorTextures(scene, actorId, fill) {
  const idleKey = `u4-actor-${actorId}-idle`;
  const walkKey = `u4-actor-${actorId}-walk`;
  if (!scene.textures.exists(idleKey)) {
    const g = scene.make.graphics({ x: 0, y: 0, add: false });
    paintFrame(g, fill, 0);
    g.generateTexture(idleKey, FRAME_W, FRAME_H);
    g.destroy();
  }
  if (!scene.textures.exists(walkKey)) {
    const g = scene.make.graphics({ x: 0, y: 0, add: false });
    paintFrame(g, fill, 1);
    g.generateTexture(walkKey, FRAME_W, FRAME_H);
    g.destroy();
  }
  return { idle: idleKey, walk: walkKey, w: FRAME_W, h: FRAME_H };
}

export const SPRITE_SCALE = 2; // 16×24 → 显示 32×48，整数倍锐化
