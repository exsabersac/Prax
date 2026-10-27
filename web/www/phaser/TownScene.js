/**
 * U4 TownScene：多地点像素地图 + 镜头 + 头顶气泡 + 程序化人物动画。
 * Menu / 叙事·tick 叠层固定于镜头（scrollFactor 0）。
 * 角色只落当前 View 同场 placeId；其它区仅地标。Session/api 零改。
 */
import { actorFill, bubbleFromView } from "./actors.js";
import {
  VIEW_W,
  VIEW_H,
  WORLD_W,
  WORLD_H,
  PLACES,
  worldSlot,
  cameraFocusFor,
  clampCamera,
} from "./map.js";
import { ensureActorTextures, SPRITE_SCALE } from "./sprites.js";

const R = 16; // 热区半径（相对缩放后精灵）

const MENU_X = 430;
const MENU_Y = 36;
const MENU_W = 198;
const LOG_X = 12;
const LOG_Y = 258;
const LOG_W = 406;
const LOG_H = 90;

const CAM_SPEED = 220;

export class TownScene extends Phaser.Scene {
  constructor() {
    super({ key: "Town" });
    /** @type {null | ((actorId: string) => void)} */
    this._onSelect = null;
    /** @type {null | ((actionId: string) => void)} */
    this._onAct = null;
    /** @type {null | (() => void)} */
    this._onWait = null;
    /** @type {Map<string, Phaser.GameObjects.Container>} */
    this._sprites = new Map();
    this._worldRoot = null;
    this._placeLabel = null;
    this._tickLabel = null;
    this._hint = null;
    this._placeId = null;
    this._menuRoot = null;
    this._logRoot = null;
    this._lastTick = null;
    this._lastLogKey = "";
    this._selectedId = null;
    /** @type {object | null} */
    this._pendingView = null;
    /** @type {object | null | undefined} */
    this._pendingMenu = undefined;
    /** @type {object | null} */
    this._lastView = null;
    /** @type {object | null} */
    this._lastMenu = null;
    this._cursors = null;
    this._wasd = null;
    this._dragging = false;
    this._dragLast = null;
    this._camReady = false;
  }

  setSelectHandler(fn) {
    this._onSelect = fn;
  }

  setActHandler(fn) {
    this._onAct = fn;
  }

  setWaitHandler(fn) {
    this._onWait = fn;
  }

  create() {
    this.cameras.main.setBackgroundColor(0x2a2a28);
    this.cameras.main.setBounds(0, 0, WORLD_W, WORLD_H);
    this.cameras.main.setRoundPixels(true);

    this._worldRoot = this.add.container(0, 0).setDepth(0);
    this._paintWorld();

    // HUD（固定于镜头）
    this._placeLabel = this.add
      .text(16, 10, "", {
        fontFamily: "monospace, PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "14px",
        color: "#fffdf8",
        backgroundColor: "#00000099",
        padding: { x: 8, y: 4 },
      })
      .setScrollFactor(0)
      .setDepth(40);

    this._tickLabel = this.add
      .text(VIEW_W / 2, 10, "", {
        fontFamily: "monospace, PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "12px",
        color: "#fffdf8",
        backgroundColor: "#00000088",
        padding: { x: 8, y: 4 },
      })
      .setOrigin(0.5, 0)
      .setScrollFactor(0)
      .setDepth(40);

    this._hint = this.add
      .text(16, VIEW_H - 8, "方向键/拖拽逛地图 · 点选居民 → 菜单 → Act", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "11px",
        color: "#fffdf8bb",
      })
      .setScrollFactor(0)
      .setDepth(40)
      .setOrigin(0, 1);

    this._menuRoot = this.add
      .container(MENU_X, MENU_Y)
      .setScrollFactor(0)
      .setDepth(50)
      .setAlpha(0);
    this._logRoot = this.add
      .container(LOG_X, LOG_Y)
      .setScrollFactor(0)
      .setDepth(50)
      .setAlpha(0);

    this._cursors = this.input.keyboard.createCursorKeys();
    this._wasd = this.input.keyboard.addKeys({
      up: Phaser.Input.Keyboard.KeyCodes.W,
      down: Phaser.Input.Keyboard.KeyCodes.S,
      left: Phaser.Input.Keyboard.KeyCodes.A,
      right: Phaser.Input.Keyboard.KeyCodes.D,
    });

    this._wireCameraDrag();

    const focus = cameraFocusFor("square");
    const c = clampCamera(focus.x, focus.y);
    this.cameras.main.setScroll(c.x, c.y);
    this._camReady = true;

    if (this._pendingView) {
      this.sync(this._pendingView);
      this._pendingView = null;
    }
    if (this._pendingMenu !== undefined) {
      this.syncMenu(this._pendingMenu);
      this._pendingMenu = undefined;
    }
  }

  _wireCameraDrag() {
    this.input.on("pointerdown", (pointer) => {
      // 点在交互物上不拖镜头（角色/按钮自带 interactive）
      if (pointer.downElement && pointer.downElement !== this.game.canvas) return;
      const hits = this.input.hitTestPointer(pointer);
      if (hits && hits.length) return;
      this._dragging = true;
      this._dragLast = { x: pointer.x, y: pointer.y };
    });
    this.input.on("pointerup", () => {
      this._dragging = false;
      this._dragLast = null;
    });
    this.input.on("pointermove", (pointer) => {
      if (!this._dragging || !pointer.isDown || !this._dragLast) return;
      const dx = pointer.x - this._dragLast.x;
      const dy = pointer.y - this._dragLast.y;
      this._dragLast = { x: pointer.x, y: pointer.y };
      const cam = this.cameras.main;
      const c = clampCamera(cam.scrollX - dx, cam.scrollY - dy);
      cam.setScroll(c.x, c.y);
    });
  }

  /** 画完整小镇：草地底 + 两地点分区 + 连接小路 + 地标 */
  _paintWorld() {
    const root = this._worldRoot;
    root.removeAll(true);

    // 世界底（深草 / 土）
    const ground = this.add.rectangle(
      WORLD_W / 2,
      WORLD_H / 2,
      WORLD_W,
      WORLD_H,
      0x3d5a3a
    );
    root.add(ground);

    // 棋盘感像素草点（程序化，无外部素材）
    const dots = this.add.graphics();
    dots.fillStyle(0x4a6b42, 0.35);
    for (let y = 8; y < WORLD_H; y += 16) {
      for (let x = 8; x < WORLD_W; x += 16) {
        if ((x + y) % 32 === 0) dots.fillRect(x, y, 2, 2);
      }
    }
    root.add(dots);

    // 连接两地的土路
    const path = this.add.graphics();
    path.fillStyle(0xc4a878, 0.95);
    path.fillRect(520, 240, 220, 36);
    path.fillStyle(0xb89560, 0.7);
    path.fillRect(520, 248, 220, 8);
    // 路边石
    path.fillStyle(0xd9d2c4, 0.8);
    for (let x = 530; x < 730; x += 28) {
      path.fillRect(x, 236, 6, 4);
      path.fillRect(x + 10, 274, 6, 4);
    }
    root.add(path);

    for (const id of Object.keys(PLACES)) {
      this._paintPlace(root, PLACES[id]);
    }

    // 世界边界细线
    const border = this.add.graphics();
    border.lineStyle(2, 0x1a1a18, 0.6);
    border.strokeRect(1, 1, WORLD_W - 2, WORLD_H - 2);
    root.add(border);
  }

  /**
   * @param {Phaser.GameObjects.Container} root
   * @param {import("./map.js").PlaceZone} z
   */
  _paintPlace(root, z) {
    // 天条
    const sky = this.add
      .rectangle(z.x + z.w / 2, z.y + 22, z.w - 8, 36, z.sky)
      .setStrokeStyle(1, z.accent, 0.4);
    root.add(sky);

    // 地面块
    const floor = this.add
      .rectangle(z.x + z.w / 2, z.y + z.h / 2 + 8, z.w - 8, z.h - 40, z.floor)
      .setStrokeStyle(3, z.accent, 1);
    root.add(floor);

    // 区内小径椭圆
    const oval = this.add.ellipse(
      z.x + z.w / 2,
      z.y + z.h / 2 + 40,
      z.w * 0.55,
      70,
      z.path,
      0.55
    );
    root.add(oval);

    // 地点名牌
    const tag = this.add
      .text(z.x + 14, z.y + 10, z.label, {
        fontFamily: "monospace, PingFang SC, sans-serif",
        fontSize: "13px",
        color: "#1c1a17",
        backgroundColor: "#fffdf8cc",
        padding: { x: 6, y: 2 },
      })
      .setDepth(2);
    root.add(tag);

    if (z.id === "square") {
      // 喷泉环 + 长椅 + 灌木
      const ring = this.add.circle(z.x + 200, z.y + 200, 42, 0x000000, 0);
      ring.setStrokeStyle(4, 0xd9d2c4, 0.55);
      const water = this.add.circle(z.x + 200, z.y + 200, 14, 0xa8c4d8, 0.85);
      const bench = this.add.rectangle(z.x + 360, z.y + 280, 56, 12, 0x6b4f2a, 0.95);
      const bushL = this.add.ellipse(z.x + 70, z.y + 320, 44, 24, 0x4a6b3c, 0.85);
      const bushR = this.add.ellipse(z.x + 430, z.y + 310, 48, 26, 0x3f5f34, 0.8);
      const lamp = this.add.rectangle(z.x + 90, z.y + 160, 6, 40, 0x4a4030, 1);
      const lampTop = this.add.circle(z.x + 90, z.y + 138, 8, 0xffe066, 0.75);
      root.add([ring, water, bench, bushL, bushR, lamp, lampTop]);
    } else {
      // 磨坊：粮袋 + 木柱 + 水车轮示意 + 木屋块
      const house = this.add
        .rectangle(z.x + 380, z.y + 160, 90, 70, 0x8a6d48, 0.95)
        .setStrokeStyle(2, 0x5c4030, 1);
      const roof = this.add.graphics();
      roof.fillStyle(0x6b3a2a, 0.95);
      roof.fillTriangle(
        z.x + 330,
        z.y + 130,
        z.x + 430,
        z.y + 130,
        z.x + 380,
        z.y + 95
      );
      const sack = this.add.ellipse(z.x + 140, z.y + 280, 52, 34, 0x8a6d48, 0.9);
      const sack2 = this.add.ellipse(z.x + 175, z.y + 300, 40, 26, 0x7a5f3c, 0.85);
      const post = this.add.rectangle(z.x + 80, z.y + 220, 14, 80, 0x5c4030, 0.95);
      // 水车轮（程序化圆环）
      const wheel = this.add.circle(z.x + 80, z.y + 170, 28, 0x000000, 0);
      wheel.setStrokeStyle(4, 0x5c4030, 0.9);
      const hub = this.add.circle(z.x + 80, z.y + 170, 6, 0x7a5f3c, 1);
      const crate = this.add.rectangle(z.x + 280, z.y + 300, 36, 28, 0x6b4f2a, 0.9);
      root.add([house, roof, sack, sack2, post, wheel, hub, crate]);
    }
  }

  update(_t, dt) {
    if (!this._camReady || !this._cursors) return;
    const cam = this.cameras.main;
    let dx = 0;
    let dy = 0;
    const k = this._cursors;
    const w = this._wasd;
    if (k.left.isDown || (w && w.left.isDown)) dx -= 1;
    if (k.right.isDown || (w && w.right.isDown)) dx += 1;
    if (k.up.isDown || (w && w.up.isDown)) dy -= 1;
    if (k.down.isDown || (w && w.down.isDown)) dy += 1;
    if (dx === 0 && dy === 0) return;
    const dist = (CAM_SPEED * dt) / 1000;
    const c = clampCamera(cam.scrollX + dx * dist, cam.scrollY + dy * dist);
    cam.setScroll(c.x, c.y);
  }

  /**
   * @param {object} view normalizeView 结果
   */
  sync(view) {
    if (!view) return;
    this._lastView = view;
    if (!this._worldRoot) {
      this._pendingView = view;
      return;
    }

    const placeId = view.locationId || "square";
    if (placeId !== this._placeId) {
      this._placeId = placeId;
      const focus = cameraFocusFor(placeId);
      const c = clampCamera(focus.x, focus.y);
      this.cameras.main.pan(c.x + VIEW_W / 2, c.y + VIEW_H / 2, 280, "Cubic.easeOut");
    }
    this._placeLabel.setText(view.locationLabel || placeId);
    const tick = view.tick != null ? String(view.tick) : "?";
    const player = view.playerId || "you";
    this._tickLabel.setText(`回合 ${tick} · ${player}`);

    if (this._lastTick !== null && this._lastTick !== tick) {
      this.tweens.killTweensOf(this._tickLabel);
      this._tickLabel.setScale(1.12);
      this.tweens.add({
        targets: this._tickLabel,
        scaleX: 1,
        scaleY: 1,
        duration: 260,
        ease: "Back.easeOut",
      });
    }
    this._lastTick = tick;

    // 仅同场角色（不伪造超 View 演员）
    const here = (view.actors || []).filter((a) => a.atPlayerLoc);
    const keep = new Set(here.map((a) => a.id));

    for (const [id, node] of this._sprites) {
      if (!keep.has(id)) {
        this._killActorTweens(node);
        node.destroy();
        this._sprites.delete(id);
      }
    }

    here.forEach((a, i) => {
      const [x, y] = worldSlot(placeId, a.id, i);
      let node = this._sprites.get(a.id);
      if (!node) {
        node = this._makeActor(a.id, a.label || a.id, x, y);
        this._sprites.set(a.id, node);
      } else if (Math.abs(node.x - x) > 0.5 || Math.abs(node.y - y) > 0.5) {
        this._playWalk(node, true);
        this.tweens.add({
          targets: node,
          x,
          y,
          duration: 280,
          ease: "Sine.easeInOut",
          onComplete: () => this._playWalk(node, false),
        });
      }
      const label = node.getData("labelText");
      if (label && label.text !== (a.label || a.id)) {
        label.setText(a.label || a.id);
      }
      this._paintSelected(node, a.id === view.selectedActorId);
      this._syncBubble(node, a, view, this._lastMenu);
    });

    this._selectedId = view.selectedActorId || null;
    this.syncLog(view);
  }

  /**
   * @param {null | { actorId?: string, actions?: Array<{id:string,label:string,kind?:string,practiceId?:string}> }} menu
   */
  syncMenu(menu) {
    this._lastMenu = menu || null;
    if (!this._menuRoot) {
      this._pendingMenu = menu;
      return;
    }
    this.tweens.killTweensOf(this._menuRoot);
    this._menuRoot.removeAll(true);

    const bg = this.add
      .rectangle(0, 0, MENU_W, 8, 0x141210, 0.9)
      .setOrigin(0, 0);
    bg.setStrokeStyle(1, 0xd9d2c4, 0.55);
    this._menuRoot.add(bg);

    const title = this.add
      .text(10, 8, "菜单", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "14px",
        color: "#efe8d8",
        fontStyle: "bold",
      })
      .setOrigin(0, 0);
    this._menuRoot.add(title);

    let y = 30;
    const actions = menu?.actions || [];
    if (!actions.length) {
      const empty = this.add
        .text(10, y, "此刻没有候选动作。", {
          fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
          fontSize: "12px",
          color: "#fffdf8aa",
          wordWrap: { width: MENU_W - 20 },
        })
        .setOrigin(0, 0);
      this._menuRoot.add(empty);
      y += 28;
    } else {
      for (const a of actions) {
        const btnH = 38;
        const row = this._makeMenuButton(
          8,
          y,
          MENU_W - 16,
          btnH,
          a.label || a.id,
          a.kind || a.practiceId || "",
          () => {
            if (this._onAct) this._onAct(a.id);
          }
        );
        this._menuRoot.add(row);
        y += btnH + 7;
      }
    }

    const wait = this._makeMenuButton(
      8,
      y,
      MENU_W - 16,
      34,
      "稍候（praxWait）",
      "",
      () => {
        if (this._onWait) this._onWait();
      },
      0x3a4a3a
    );
    this._menuRoot.add(wait);
    y += 42;

    const h = Math.max(y + 8, 72);
    bg.setDisplaySize(MENU_W, h);

    this._menuRoot.setAlpha(0);
    this._menuRoot.y = MENU_Y - 8;
    this.tweens.add({
      targets: this._menuRoot,
      alpha: 1,
      y: MENU_Y,
      duration: 200,
      ease: "Cubic.easeOut",
    });

    // 菜单更新后刷新选中角色气泡
    if (this._lastView && this._selectedId) {
      const actor = (this._lastView.actors || []).find((a) => a.id === this._selectedId);
      const node = this._sprites.get(this._selectedId);
      if (actor && node) this._syncBubble(node, actor, this._lastView, menu);
    }
  }

  /**
   * @param {object} view
   */
  syncLog(view) {
    if (!this._logRoot) return;

    const lines = (view && view.log) || [];
    const key = lines.map((l) => `${l.kind}|${l.text}`).join("\n");
    const changed = key !== this._lastLogKey;
    this._lastLogKey = key;

    this._logRoot.removeAll(true);

    const bg = this.add
      .rectangle(0, 0, LOG_W, LOG_H, 0x141210, 0.88)
      .setOrigin(0, 0);
    bg.setStrokeStyle(1, 0xd9d2c4, 0.5);
    this._logRoot.add(bg);

    const title = this.add
      .text(10, 5, "对话与回合反馈", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "12px",
        color: "#efe8d8",
        fontStyle: "bold",
      })
      .setOrigin(0, 0);
    this._logRoot.add(title);

    if (!lines.length) {
      const empty = this.add
        .text(10, 24, "还没有发生的事。", {
          fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
          fontSize: "12px",
          color: "#fffdf8aa",
        })
        .setOrigin(0, 0);
      this._logRoot.add(empty);
    } else {
      const tail = lines.slice(-3);
      let y = 22;
      for (const line of tail) {
        const kind = line.kind || "system";
        const color =
          kind === "narrative"
            ? "#c8e6d0"
            : kind === "system"
              ? "#e6dfc8"
              : "#fffdf8";
        const barColor =
          kind === "narrative" ? 0x2f6f4e : kind === "system" ? 0x8a7a4a : 0x666666;
        const bar = this.add.rectangle(6, y + 2, 3, 14, barColor, 0.95).setOrigin(0, 0);
        const t = this.add
          .text(14, y, line.text || "", {
            fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
            fontSize: "12px",
            color,
            wordWrap: { width: LOG_W - 28 },
          })
          .setOrigin(0, 0);
        this._logRoot.add(bar);
        this._logRoot.add(t);
        y += Math.min(t.height + 6, 24);
        if (y > LOG_H - 8) break;
      }
    }

    if (changed) {
      this.tweens.killTweensOf(this._logRoot);
      this._logRoot.setAlpha(0.35);
      this.tweens.add({
        targets: this._logRoot,
        alpha: 1,
        duration: 220,
        ease: "Cubic.easeOut",
      });
    } else if (this._logRoot.alpha < 1) {
      this._logRoot.setAlpha(1);
    }
  }

  _makeMenuButton(x, y, w, h, label, sub, onClick, fill = 0x2f6f4e) {
    const g = this.add.container(x, y);
    const bg = this.add.rectangle(0, 0, w, h, fill, 0.95).setOrigin(0, 0);
    bg.setStrokeStyle(1, 0xd9d2c4, 0.75);
    bg.setInteractive({ useHandCursor: true });
    bg.on("pointerover", () => {
      bg.setFillStyle(fill, 1);
      bg.setStrokeStyle(2, 0xffe066, 0.9);
      g.setScale(1.03);
    });
    bg.on("pointerout", () => {
      bg.setFillStyle(fill, 0.95);
      bg.setStrokeStyle(1, 0xd9d2c4, 0.75);
      g.setScale(1);
    });
    bg.on("pointerdown", (pointer, _lx, _ly, event) => {
      if (event && event.stopPropagation) event.stopPropagation();
      this.tweens.add({
        targets: g,
        scaleX: 0.97,
        scaleY: 0.97,
        duration: 60,
        yoyo: true,
        onComplete: () => onClick(),
      });
    });
    const title = this.add
      .text(8, sub ? 5 : h / 2, label, {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "13px",
        color: "#fffdf8",
        wordWrap: { width: w - 16 },
      })
      .setOrigin(0, sub ? 0 : 0.5);
    g.add(bg);
    g.add(title);
    if (sub) {
      const kind = this.add
        .text(8, 20, sub, {
          fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
          fontSize: "10px",
          color: "#d9d2c4",
        })
        .setOrigin(0, 0);
      g.add(kind);
    }
    return g;
  }

  _makeActor(id, label, x, y) {
    const fill = actorFill(id);
    const tex = ensureActorTextures(this, id, fill);

    const shadow = this.add.ellipse(0, 22, 22, 8, 0x000000, 0.3);
    const body = this.add.sprite(0, 0, tex.idle);
    body.setScale(SPRITE_SCALE);
    body.setData("idleKey", tex.idle);
    body.setData("walkKey", tex.walk);

    const ring = this.add.circle(0, 4, R + 6, 0x000000, 0);
    ring.setStrokeStyle(2, 0xffe066, 0);
    ring.setVisible(false);

    // 头顶气泡
    const bubbleBg = this.add
      .rectangle(0, -36, 8, 16, 0xfffdf8, 0.95)
      .setStrokeStyle(1, 0x1c1a17, 0.55)
      .setVisible(false);
    const bubbleText = this.add
      .text(0, -36, "", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "10px",
        color: "#1c1a17",
        padding: { x: 2, y: 1 },
      })
      .setOrigin(0.5, 0.5)
      .setVisible(false);

    const name = this.add
      .text(0, 28, label, {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "11px",
        color: "#1c1a17",
        backgroundColor: "#fffdf8dd",
        padding: { x: 4, y: 1 },
      })
      .setOrigin(0.5, 0);

    const hit = this.add.circle(0, 4, R + 8, 0xffffff, 0.001);
    hit.setInteractive({ useHandCursor: true });

    const node = this.add.container(x, y, [
      shadow,
      ring,
      body,
      bubbleBg,
      bubbleText,
      name,
      hit,
    ]);
    node.setSize((R + 8) * 2, (R + 8) * 2);
    node.setData("body", body);
    node.setData("ring", ring);
    node.setData("labelText", name);
    node.setData("bubbleBg", bubbleBg);
    node.setData("bubbleText", bubbleText);
    node.setData("actorId", id);
    node.setData("walking", false);
    node.setDepth(10);

    hit.on("pointerover", () => {
      if (id === this._selectedId) return;
      this.tweens.add({
        targets: node,
        scaleX: 1.06,
        scaleY: 1.06,
        duration: 90,
      });
    });
    hit.on("pointerout", () => {
      if (id === this._selectedId) return;
      this.tweens.add({
        targets: node,
        scaleX: 1,
        scaleY: 1,
        duration: 90,
      });
    });
    hit.on("pointerdown", (pointer, _lx, _ly, event) => {
      if (event && event.stopPropagation) event.stopPropagation();
      this.tweens.add({
        targets: node,
        scaleX: 0.92,
        scaleY: 0.92,
        duration: 70,
        yoyo: true,
        ease: "Quad.easeOut",
      });
      ring.setVisible(true);
      ring.setStrokeStyle(2, 0xffe066, 1);
      ring.setScale(1);
      ring.setAlpha(1);
      this.tweens.add({
        targets: ring,
        scaleX: 1.35,
        scaleY: 1.35,
        alpha: 0,
        duration: 260,
        onComplete: () => {
          ring.setScale(1);
          ring.setAlpha(1);
          if (id !== this._selectedId) {
            ring.setVisible(false);
            ring.setStrokeStyle(2, 0xffe066, 0);
          }
        },
      });
      if (this._onSelect) this._onSelect(id);
    });

    // idle 呼吸 + 双帧切换（程序化 walk/idle 纹理）
    const phase = (id.charCodeAt(0) % 7) * 90;
    this.tweens.add({
      targets: [body, shadow],
      y: "-=2",
      duration: 850 + phase,
      yoyo: true,
      repeat: -1,
      ease: "Sine.easeInOut",
      delay: phase,
    });
    // 轻微 idle 帧闪动（像呼吸脚步）
    this.time.addEvent({
      delay: 700 + phase,
      loop: true,
      callback: () => {
        if (node.getData("walking")) return;
        const b = node.getData("body");
        if (!b) return;
        const idle = b.getData("idleKey");
        const walk = b.getData("walkKey");
        b.setTexture(b.texture.key === idle ? walk : idle);
      },
    });

    return node;
  }

  _playWalk(node, walking) {
    node.setData("walking", !!walking);
    const body = node.getData("body");
    if (!body) return;
    if (walking) {
      body.setTexture(body.getData("walkKey"));
    } else {
      body.setTexture(body.getData("idleKey"));
    }
  }

  _syncBubble(node, actor, view, menu) {
    const bg = node.getData("bubbleBg");
    const tx = node.getData("bubbleText");
    if (!bg || !tx) return;
    const text = bubbleFromView(actor, view, menu);
    if (!text) {
      bg.setVisible(false);
      tx.setVisible(false);
      return;
    }
    tx.setText(text);
    const w = Math.max(tx.width + 10, 24);
    bg.setSize(w, 16);
    bg.setDisplaySize(w, 16);
    bg.setVisible(true);
    tx.setVisible(true);
  }

  _killActorTweens(node) {
    this.tweens.killTweensOf(node);
    const ring = node.getData("ring");
    const body = node.getData("body");
    if (ring) this.tweens.killTweensOf(ring);
    if (body) this.tweens.killTweensOf(body);
  }

  _paintSelected(node, selected) {
    const ring = node.getData("ring");
    if (selected) {
      if (ring) {
        ring.setVisible(true);
        ring.setStrokeStyle(2, 0xffe066, 0.9);
        ring.setScale(1);
        ring.setAlpha(1);
        this.tweens.killTweensOf(ring);
        this.tweens.add({
          targets: ring,
          scaleX: 1.15,
          scaleY: 1.15,
          duration: 500,
          yoyo: true,
          repeat: -1,
          ease: "Sine.easeInOut",
        });
      }
      if (Math.abs(node.scaleX - 1.08) > 0.02) {
        this.tweens.add({
          targets: node,
          scaleX: 1.08,
          scaleY: 1.08,
          duration: 110,
        });
      }
    } else {
      if (ring) {
        this.tweens.killTweensOf(ring);
        ring.setVisible(false);
        ring.setStrokeStyle(2, 0xffe066, 0);
        ring.setScale(1);
        ring.setAlpha(1);
      }
      if (Math.abs(node.scaleX - 1) > 0.02) {
        this.tweens.add({
          targets: node,
          scaleX: 1,
          scaleY: 1,
          duration: 110,
        });
      }
    }
  }
}

export const TOWN_SIZE = { width: VIEW_W, height: VIEW_H };
