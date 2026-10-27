/**
 * U9：程序化像素人物（自研几何帧，非 GA/CuteRPG）。
 * U11：部分角色改用 Blender 烘图集（assets/u11/{id}-sheet.png）；其余仍几何回退。
 * 逻辑稿 16×24，2× 烘焙成 32×48 纹理；idle 呼吸起伏 + walk 迈步更可感。
 * idle 4 帧 + walk 4 帧 × 三朝向（下/侧/上）；左朝向用 flipX。禁商用素材。
 */

const LOGICAL_W = 16;
const LOGICAL_H = 24;
/** 2× 烘焙倍率 */
const BAKE = 2;
export const FRAME_W = LOGICAL_W * BAKE;
export const FRAME_H = LOGICAL_H * BAKE;
const COLS = 4;
const ROWS = 3; // down / side / up

/**
 * U11：已预载 Blender 烘图集的角色内部 id（展示层替换，不改 Session/世界）。
 * 纹理键：u11-actor-{id}-sheet（BootScene 预载）。
 */
export const BAKED_ACTOR_IDS = new Set(["you"]);

/** @typedef {'down'|'side'|'up'} FaceRow */

/**
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} ox
 * @param {number} oy
 * @param {number} fill
 * @param {FaceRow} face
 * @param {number} frame 0–3
 * @param {'idle'|'walk'} mode
 */
function paintFrameLogical(ctx, ox, oy, fill, face, frame, mode) {
  const hair = ((fill >> 1) & 0x7f7f7f) | 0x202020;
  const pants = 0x2a2a28;
  const shoe = 0x1a1a18;
  const skin = 0xffe0bd;
  const f = frame % 4;

  const hex = (n) => "#" + (n >>> 0).toString(16).padStart(6, "0");
  const rect = (x, y, w, h, c) => {
    ctx.fillStyle = hex(c);
    ctx.fillRect(ox + x, oy + y, w, h);
  };

  // U9：idle 呼吸起伏（头身整体 bob）；walk 保持迈步
  const breath = mode === "idle" ? [0, -1, 0, 1][f] : 0;

  // 头 / 发 / 脸
  if (face === "up") {
    rect(5, 0 + breath, 6, 7, hair);
    rect(6, 5 + breath, 4, 2, skin);
  } else if (face === "side") {
    rect(6, 1 + breath, 6, 6, skin);
    rect(5, 0 + breath, 6, 3, hair);
    rect(10, 3 + breath, 2, 2, 0x1c1a17);
  } else {
    rect(5, 1 + breath, 6, 6, skin);
    rect(5, 0 + breath, 6, 2, hair);
    rect(6, 3 + breath, 1, 1, 0x1c1a17);
    rect(9, 3 + breath, 1, 1, 0x1c1a17);
  }

  // 身
  if (face === "side") rect(5, 7 + breath, 7, 9, fill);
  else rect(4, 7 + breath, 8, 9, fill);

  // 手臂
  if (mode === "idle") {
    const sway = f === 0 || f === 1 ? 0 : f === 2 ? 1 : -1;
    if (face === "side") {
      rect(3, 8 + sway + breath, 2, 6, skin);
      rect(12, 9 - sway + breath, 2, 5, skin);
    } else if (face === "up") {
      rect(2, 8 + Math.abs(sway) + breath, 2, 6, skin);
      rect(12, 8 + Math.abs(sway) + breath, 2, 6, skin);
    } else {
      rect(2, 8 + sway + breath, 2, 6, skin);
      rect(12, 8 - sway + breath, 2, 6, skin);
    }
  } else {
    const phase = f % 4;
    const leftUp = phase === 0 || phase === 3;
    if (face === "side") {
      rect(leftUp ? 12 : 11, leftUp ? 7 : 10, 2, 5, skin);
      rect(3, leftUp ? 10 : 7, 2, 5, skin);
    } else {
      rect(1, leftUp ? 7 : 10, 2, leftUp ? 6 : 5, skin);
      rect(13, leftUp ? 10 : 7, 2, leftUp ? 5 : 6, skin);
    }
  }

  // 腿 / 鞋
  if (mode === "idle") {
    const lean = f === 0 ? 0 : f === 1 ? 0 : f === 2 ? -1 : 1;
    rect(5 + lean, 16, 3, 7, pants);
    rect(9 + lean, 16, 3, 7, pants);
    rect(4 + lean, 22, 4, 2, shoe);
    rect(9 + lean, 22, 4, 2, shoe);
  } else if (face === "side") {
    const sideCycle = [
      { bx: 6, by: 16, bh: 7, fx: 8, fy: 16, fh: 7 },
      { bx: 5, by: 16, bh: 7, fx: 9, fy: 15, fh: 8 },
      { bx: 6, by: 16, bh: 7, fx: 8, fy: 16, fh: 7 },
      { bx: 4, by: 15, bh: 8, fx: 9, fy: 16, fh: 7 },
    ][f];
    rect(sideCycle.bx, sideCycle.by, 3, sideCycle.bh, pants);
    rect(sideCycle.fx, sideCycle.fy, 3, sideCycle.fh, pants);
    rect(sideCycle.bx - 1, 22, 4, 2, shoe);
    rect(sideCycle.fx, 22, 4, 2, shoe);
  } else {
    const cycle = [
      { lx: 5, ly: 16, lh: 7, rx: 9, ry: 16, rh: 7 },
      { lx: 3, ly: 16, lh: 7, rx: 10, ry: 15, rh: 8 },
      { lx: 5, ly: 16, lh: 7, rx: 9, ry: 16, rh: 7 },
      { lx: 4, ly: 15, lh: 8, rx: 11, ry: 16, rh: 7 },
    ][f];
    rect(cycle.lx, cycle.ly, 3, cycle.lh, pants);
    rect(cycle.rx, cycle.ry, 3, cycle.rh, pants);
    rect(cycle.lx - 1, 22, 4, 2, shoe);
    rect(cycle.rx, 22, 4, 2, shoe);
  }
}

/**
 * 逻辑帧 nearest 放大 BAKE 倍写入 sheet。
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} ox sheet 原点
 * @param {number} oy
 * @param {number} fill
 * @param {FaceRow} face
 * @param {number} frame
 * @param {'idle'|'walk'} mode
 */
function paintFrameBaked(ctx, ox, oy, fill, face, frame, mode) {
  const tmp = document.createElement("canvas");
  tmp.width = LOGICAL_W;
  tmp.height = LOGICAL_H;
  const tctx = tmp.getContext("2d");
  tctx.imageSmoothingEnabled = false;
  paintFrameLogical(tctx, 0, 0, fill, face, frame, mode);
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(tmp, 0, 0, LOGICAL_W, LOGICAL_H, ox, oy, FRAME_W, FRAME_H);
}

/**
 * U11：用已预载的 Blender 图集注册与几何精灵同名的 animKey。
 * @param {Phaser.Scene} scene
 * @param {string} actorId
 * @returns {{ sheet: string, w: number, h: number } | null}
 */
function ensureBakedActorTextures(scene, actorId) {
  const sheetKey = `u11-actor-${actorId}-sheet`;
  if (!scene.textures.exists(sheetKey)) return null;

  const tex = scene.textures.get(sheetKey);
  tex.setFilter(Phaser.Textures.FilterMode.NEAREST);

  const faces = /** @type {FaceRow[]} */ (["down", "side", "up"]);
  const faceIdx = { down: 0, side: 1, up: 2 };
  for (const face of faces) {
    const idleKey = animKey(actorId, "idle", face);
    const walkKey = animKey(actorId, "walk", face);
    if (!scene.anims.exists(idleKey)) {
      const base = faceIdx[face] * COLS;
      scene.anims.create({
        key: idleKey,
        frames: [0, 1, 2, 3].map((i) => ({ key: sheetKey, frame: base + i })),
        frameRate: 4,
        repeat: -1,
      });
    }
    if (!scene.anims.exists(walkKey)) {
      const base = (ROWS + faceIdx[face]) * COLS;
      scene.anims.create({
        key: walkKey,
        frames: [0, 1, 2, 3].map((i) => ({ key: sheetKey, frame: base + i })),
        frameRate: 9,
        repeat: -1,
      });
    }
  }
  return { sheet: sheetKey, w: FRAME_W, h: FRAME_H };
}

/**
 * @param {Phaser.Scene} scene
 * @param {string} actorId
 * @param {number} fill
 * @returns {{ sheet: string, w: number, h: number }}
 */
export function ensureActorTextures(scene, actorId, fill) {
  // U11：优先 Blender 烘图（可感异于几何）；缺失则几何回退
  if (BAKED_ACTOR_IDS.has(actorId)) {
    const baked = ensureBakedActorTextures(scene, actorId);
    if (baked) return baked;
  }

  const sheetKey = `u9-actor-${actorId}-sheet`;
  const faces = /** @type {FaceRow[]} */ (["down", "side", "up"]);

  if (!scene.textures.exists(sheetKey)) {
    const canvas = document.createElement("canvas");
    canvas.width = FRAME_W * COLS;
    canvas.height = FRAME_H * ROWS * 2; // idle rows 0–2, walk rows 3–5
    const ctx = canvas.getContext("2d");
    ctx.imageSmoothingEnabled = false;

    faces.forEach((face, row) => {
      for (let col = 0; col < COLS; col++) {
        paintFrameBaked(ctx, col * FRAME_W, row * FRAME_H, fill, face, col, "idle");
        paintFrameBaked(
          ctx,
          col * FRAME_W,
          (row + ROWS) * FRAME_H,
          fill,
          face,
          col,
          "walk"
        );
      }
    });

    scene.textures.addCanvas(sheetKey, canvas);
    const tex = scene.textures.get(sheetKey);
    tex.setFilter(Phaser.Textures.FilterMode.NEAREST);
    for (let row = 0; row < ROWS * 2; row++) {
      for (let col = 0; col < COLS; col++) {
        const idx = row * COLS + col;
        tex.add(idx, 0, col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H);
      }
    }
  }

  const faceIdx = { down: 0, side: 1, up: 2 };
  for (const face of faces) {
    const idleKey = animKey(actorId, "idle", face);
    const walkKey = animKey(actorId, "walk", face);
    if (!scene.anims.exists(idleKey)) {
      const base = faceIdx[face] * COLS;
      scene.anims.create({
        key: idleKey,
        frames: [0, 1, 2, 3].map((i) => ({ key: sheetKey, frame: base + i })),
        frameRate: 4,
        repeat: -1,
      });
    }
    if (!scene.anims.exists(walkKey)) {
      const base = (ROWS + faceIdx[face]) * COLS;
      scene.anims.create({
        key: walkKey,
        frames: [0, 1, 2, 3].map((i) => ({ key: sheetKey, frame: base + i })),
        frameRate: 9,
        repeat: -1,
      });
    }
  }

  return { sheet: sheetKey, w: FRAME_W, h: FRAME_H };
}

/**
 * @param {string} actorId
 * @param {'idle'|'walk'} mode
 * @param {FaceRow} face
 */
export function animKey(actorId, mode, face) {
  return `u9-${actorId}-${mode}-${face}`;
}

/**
 * @param {number} dx
 * @param {number} dy
 * @returns {{ face: FaceRow, flipX: boolean }}
 */
export function facingFromDelta(dx, dy) {
  if (Math.abs(dx) > Math.abs(dy)) {
    return { face: "side", flipX: dx < 0 };
  }
  if (dy < 0) return { face: "up", flipX: false };
  return { face: "down", flipX: false };
}

/** 2× 已烘焙进纹理，显示倍率 1（屏上与 U5 的 16×24@scale2 同大） */
export const SPRITE_SCALE = 1;
