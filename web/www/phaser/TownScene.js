/**
 * U7 TownScene：叠 U6 抗糊 + U5 表现；逻辑尺寸随布局（scale.js computeLayout）。
 * Menu / 叙事·tick 叠层固定于镜头（scrollFactor 0）；屏坐标命中随逻辑尺寸重算，与 world scroll 解耦。
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
  placeZoneAt,
} from "./map.js";
import {
  ensureActorTextures,
  SPRITE_SCALE,
  animKey,
  facingFromDelta,
} from "./sprites.js";

const R = 16;

/** 设计参考（640×360）下的默认 HUD；实际由 _computeHud(viewW,viewH) 随布局重算 */
const MENU_Y0 = 28;
const MENU_W0 = 204;
const LOG_X0 = 12;
const LOG_H0 = 118;

const CAM_SPEED = 240;

function computeHud(viewW, viewH) {
  const vw = Math.max(2, viewW | 0);
  const vh = Math.max(2, viewH | 0);
  const menuW = Math.min(MENU_W0, Math.max(148, Math.floor(vw * 0.3)));
  const menuX = Math.max(8, vw - menuW - 12);
  const menuY = MENU_Y0;
  const logH = Math.min(LOG_H0, Math.max(72, Math.floor(vh * 0.28)));
  const logW = Math.min(400, Math.max(160, menuX - 24));
  const logX = LOG_X0;
  const logY = Math.max(100, vh - logH - 28);
  const hintY = Math.max(24, vh - 14);
  return { vw, vh, menuX, menuY, menuW, logX, logY, logW, logH, hintY };
}


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
    this._camBadge = null;
    this._placeId = null;
    this._menuRoot = null;
    this._logRoot = null;
    /** @type {Phaser.GameObjects.GameObject[]} */
    this._menuHits = [];
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
    this._selectPulse = null;
    this._viewLabel = "";
    this._viewW = VIEW_W;
    this._viewH = VIEW_H;
    this._hud = computeHud(VIEW_W, VIEW_H);
    this._layoutKey = "";
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

  /**
   * U7：逻辑尺寸 / HUD / 镜头 size 随布局重算。
   * 保留镜头中心与选中；不碰 Session；菜单命中随新逻辑尺寸重建。
   * @param {{ gameW:number, gameH:number, cssW?:number, cssH?:number, dpr?:number, designScale?:number, cssZoom?:number }} layout
   */
  applyLayout(layout) {
    if (!layout) return;
    const gameW = Math.max(2, Math.round(layout.gameW || layout.cssW || this._viewW));
    const gameH = Math.max(2, Math.round(layout.gameH || layout.cssH || this._viewH));
    const key = `${gameW}x${gameH}@${layout.dpr || 1}`;
    const sizeChanged = gameW !== this._viewW || gameH !== this._viewH;
    if (!sizeChanged && key === this._layoutKey && this._camReady) {
      this._updateCamBadge();
      return;
    }
    this._layoutKey = key;

    const cam = this.cameras && this.cameras.main;
    let cx = this._viewW / 2;
    let cy = this._viewH / 2;
    if (cam && this._camReady) {
      cx = cam.scrollX + this._viewW / 2;
      cy = cam.scrollY + this._viewH / 2;
    }

    this._viewW = gameW;
    this._viewH = gameH;
    this._hud = computeHud(gameW, gameH);

    if (cam) {
      if (typeof cam.setSize === "function") cam.setSize(gameW, gameH);
      if (this._camReady) {
        const c = clampCamera(cx - gameW / 2, cy - gameH / 2, gameW, gameH);
        cam.setScroll(c.x, c.y);
      }
    }

    this._relayoutHudChrome();
    // 菜单命中随逻辑尺寸重算（保留当前 menu 内容；quiet 避免 resize 闪入场）
    if (this._menuRoot && this._lastMenu) {
      this.syncMenu(this._lastMenu, { quiet: true });
    } else if (this._menuRoot) {
      this._menuRoot.setPosition(this._hud.menuX, this._hud.menuY);
    }
    if (this._logRoot && this._lastView) {
      this.syncLog(this._lastView);
    } else if (this._logRoot) {
      this._logRoot.setPosition(this._hud.logX, this._hud.logY);
    }
    this._updateCamBadge();
  }

  /** 仅搬 HUD 铬件位置/宽度，不重建菜单内容 */
  _relayoutHudChrome() {
    const h = this._hud;
    if (!h) return;
    if (this._tickLabel) this._tickLabel.setPosition(h.vw / 2, 10);
    if (this._camBadge) this._camBadge.setPosition(h.menuX - 8, 10);
    if (this._hint) this._hint.setPosition(16, h.hintY);
    if (this._selectPulse && typeof this._selectPulse.setSize === "function") {
      this._selectPulse.setSize(h.vw, 3);
    } else if (this._selectPulse) {
      this._selectPulse.width = h.vw;
    }
    if (this._menuRoot) this._menuRoot.setPosition(h.menuX, h.menuY);
    if (this._logRoot) this._logRoot.setPosition(h.logX, h.logY);
  }

  create() {
    this.cameras.main.setBackgroundColor(0x2a2a28);
    this.cameras.main.setBounds(0, 0, WORLD_W, WORLD_H);
    this.cameras.main.setRoundPixels(true);

    this._worldRoot = this.add.container(0, 0).setDepth(0);
    this._paintWorld();

    // HUD（固定于镜头；全部 scrollFactor 0）
    this._placeLabel = this.add
      .text(16, 10, "", {
        fontFamily: "monospace, PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "13px",
        color: "#fffdf8",
        backgroundColor: "#000000aa",
        padding: { x: 8, y: 4 },
      })
      .setScrollFactor(0)
      .setDepth(40);

    const hud0 = this._hud;
    this._tickLabel = this.add
      .text(hud0.vw / 2, 10, "", {
        fontFamily: "monospace, PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "12px",
        color: "#fffdf8",
        backgroundColor: "#00000099",
        padding: { x: 8, y: 4 },
      })
      .setOrigin(0.5, 0)
      .setScrollFactor(0)
      .setDepth(40);

    // 镜头徽章放菜单左侧，避免被盖住
    this._camBadge = this.add
      .text(hud0.menuX - 8, 10, "", {
        fontFamily: "monospace, PingFang SC, sans-serif",
        fontSize: "10px",
        color: "#ffe066",
        backgroundColor: "#00000088",
        padding: { x: 6, y: 3 },
      })
      .setOrigin(1, 0)
      .setScrollFactor(0)
      .setDepth(40)
      .setAlpha(0.9);

    this._hint = this.add
      .text(16, hud0.hintY, "方向键/拖拽逛地图 · 点选居民 → 菜单 → Act", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "11px",
        color: "#fffdf8bb",
        backgroundColor: "#00000066",
        padding: { x: 6, y: 2 },
      })
      .setScrollFactor(0)
      .setDepth(55)
      .setOrigin(0, 0);

    this._menuRoot = this.add
      .container(hud0.menuX, hud0.menuY)
      .setScrollFactor(0)
      .setDepth(50)
      .setAlpha(0);
    this._pinHud(this._menuRoot);

    this._logRoot = this.add
      .container(hud0.logX, hud0.logY)
      .setScrollFactor(0)
      .setDepth(50)
      .setAlpha(0);
    this._pinHud(this._logRoot);

    this._selectPulse = this.add
      .rectangle(0, 0, hud0.vw, 3, 0xffe066, 0)
      .setScrollFactor(0)
      .setDepth(45)
      .setOrigin(0, 0);

    this._cursors = this.input.keyboard.createCursorKeys();
    this._wasd = this.input.keyboard.addKeys({
      up: Phaser.Input.Keyboard.KeyCodes.W,
      down: Phaser.Input.Keyboard.KeyCodes.S,
      left: Phaser.Input.Keyboard.KeyCodes.A,
      right: Phaser.Input.Keyboard.KeyCodes.D,
    });

    this._wireCameraDrag();

    this.cameras.main.setSize(this._viewW, this._viewH);
    const focus = cameraFocusFor("square", this._viewW, this._viewH);
    const c = clampCamera(focus.x, focus.y, this._viewW, this._viewH);
    this.cameras.main.setScroll(c.x, c.y);
    this._camReady = true;
    this._updateCamBadge();

    if (this._pendingView) {
      this.sync(this._pendingView);
      this._pendingView = null;
    }
    if (this._pendingMenu !== undefined) {
      this.syncMenu(this._pendingMenu);
      this._pendingMenu = undefined;
    }
  }

  /** 递归钉死 HUD 的 scrollFactor，避免子节点命中跟镜头 scroll 错位 */
  _pinHud(go) {
    if (!go) return;
    if (typeof go.setScrollFactor === "function") go.setScrollFactor(0);
    if (Array.isArray(go.list)) {
      for (const child of go.list) this._pinHud(child);
    }
  }

  _wireCameraDrag() {
    this.input.on("pointerdown", (pointer) => {
      if (pointer.downElement && pointer.downElement !== this.game.canvas) return;
      // 优先：屏坐标菜单按钮（与 camera scroll 完全解耦）
      if (this._tryMenuClick(pointer)) return;
      // 屏坐标：点在菜单/日志上不启动拖拽
      if (this._pointerOnHud(pointer)) return;
      this._dragging = true;
      this._dragLast = { x: pointer.x, y: pointer.y };
    });
    this.input.on("pointerup", () => {
      this._dragging = false;
      this._dragLast = null;
    });
    this.input.on("pointermove", (pointer) => {
      this._hoverMenu(pointer);
      if (!this._dragging || !pointer.isDown || !this._dragLast) return;
      const dx = pointer.x - this._dragLast.x;
      const dy = pointer.y - this._dragLast.y;
      this._dragLast = { x: pointer.x, y: pointer.y };
      const cam = this.cameras.main;
      const c = clampCamera(cam.scrollX - dx, cam.scrollY - dy, this._viewW, this._viewH);
      cam.setScroll(c.x, c.y);
      this._updateCamBadge();
    });
  }

  _hoverMenu(pointer) {
    const hits = this._menuHits || [];
    if (!this._menuRoot) return;
    const rootX = this._menuRoot.x;
    const rootY = this._menuRoot.y;
    let any = false;
    for (const rec of hits) {
      const sx = rootX + rec.x;
      const sy = rootY + rec.y;
      const over =
        pointer.x >= sx &&
        pointer.x <= sx + rec.w &&
        pointer.y >= sy &&
        pointer.y <= sy + rec.h;
      if (!rec.bg) continue;
      if (over) {
        any = true;
        rec.bg.setFillStyle(rec.fill, 1);
        rec.bg.setStrokeStyle(2, 0xffe066, 0.9);
        if (rec.g) rec.g.setScale(1.02);
      } else {
        rec.bg.setFillStyle(rec.fill, 0.95);
        rec.bg.setStrokeStyle(1, 0xd9d2c4, 0.75);
        if (rec.g) rec.g.setScale(1);
      }
    }
    if (this.game && this.game.canvas) {
      this.game.canvas.style.cursor = any ? "pointer" : "";
    }
  }

  /** 屏坐标判断是否点在菜单/日志面板上 */
  _pointerOnHud(pointer) {
    const x = pointer.x;
    const y = pointer.y;
    const hud = this._hud || computeHud(this._viewW, this._viewH);
    if (this._menuRoot && this._menuRoot.alpha > 0.05) {
      const h = this._menuRoot.getData("panelH") || 120;
      const mx = this._menuRoot.x;
      const my = this._menuRoot.y;
      const mw = hud.menuW;
      if (x >= mx && x <= mx + mw && y >= my && y <= my + h) {
        return true;
      }
    }
    if (this._logRoot && this._logRoot.alpha > 0.05) {
      const lx = this._logRoot.x;
      const ly = this._logRoot.y;
      if (x >= lx && x <= lx + hud.logW && y >= ly && y <= ly + hud.logH) {
        return true;
      }
    }
    return false;
  }

  /**
   * 屏坐标点选菜单按钮。返回 true 表示已消费事件。
   * @param {Phaser.Input.Pointer} pointer
   */
  _tryMenuClick(pointer) {
    if (!this._menuRoot || this._menuRoot.alpha < 0.05) return false;
    const hits = this._menuHits || [];
    const rootX = this._menuRoot.x;
    const rootY = this._menuRoot.y;
    for (let i = hits.length - 1; i >= 0; i--) {
      const rec = hits[i];
      const sx = rootX + rec.x;
      const sy = rootY + rec.y;
      if (
        pointer.x >= sx &&
        pointer.x <= sx + rec.w &&
        pointer.y >= sy &&
        pointer.y <= sy + rec.h
      ) {
        if (rec.g) {
          this.tweens.add({
            targets: rec.g,
            scaleX: 0.97,
            scaleY: 0.97,
            duration: 60,
            yoyo: true,
            onComplete: () => {
              if (rec.onClick) rec.onClick();
            },
          });
        } else if (rec.onClick) {
          rec.onClick();
        }
        return true;
      }
    }
    return false;
  }

  _updateCamBadge() {
    if (!this._camBadge || !this._camReady) return;
    const cam = this.cameras.main;
    const vw = this._viewW || VIEW_W;
    const vh = this._viewH || VIEW_H;
    const maxX = Math.max(1, WORLD_W - vw);
    const maxY = Math.max(1, WORLD_H - vh);
    const px = Math.round((cam.scrollX / maxX) * 100);
    const py = Math.round((cam.scrollY / maxY) * 100);
    const lay =
      (this.game && (this.game.__u7Layout || this.game.__u6Scale)) ||
      (typeof window !== "undefined" &&
        (window.__praxU7Layout || window.__praxU6Scale)) ||
      null;
    let scaleTag = "";
    if (lay) {
      const dprBit = lay.dpr && lay.dpr !== 1 ? `@${Number(lay.dpr).toFixed(2)}dpr` : "";
      scaleTag = ` · ${vw}×${vh}${dprBit}`;
    }
    this._camBadge.setText(`镜头 ${px}%,${py}%${scaleTag}`);
    this._refreshPlaceLabel();
  }

  /** 所在地跟 View；画面区跟镜头中心，避免平移后仍只写「广场」 */
  _refreshPlaceLabel() {
    if (!this._placeLabel || !this._camReady) return;
    const cam = this.cameras.main;
    const cx = cam.scrollX + (this._viewW || VIEW_W) / 2;
    const cy = cam.scrollY + (this._viewH || VIEW_H) / 2;
    const focus = placeZoneAt(cx, cy);
    const hereLabel =
      this._viewLabel ||
      (this._placeId && PLACES[this._placeId] && PLACES[this._placeId].label) ||
      this._placeId ||
      "";
    if (focus && this._placeId && focus.id !== this._placeId) {
      this._placeLabel.setText(`所在 ${hereLabel} · 画面 ${focus.label}`);
    } else if (focus && (!this._placeId || focus.id === this._placeId)) {
      this._placeLabel.setText(hereLabel || focus.label);
    } else {
      this._placeLabel.setText(hereLabel || "");
    }
  }

  _resetCameraToPlace(placeId, animate) {
    const focus = cameraFocusFor(placeId || "square", this._viewW, this._viewH);
    const c = clampCamera(focus.x, focus.y, this._viewW, this._viewH);
    if (animate) {
      this.cameras.main.pan(
        c.x + this._viewW / 2,
        c.y + this._viewH / 2,
        280,
        "Cubic.easeOut"
      );
      this.time.delayedCall(300, () => this._updateCamBadge());
    } else {
      this.cameras.main.setScroll(c.x, c.y);
      this._updateCamBadge();
    }
  }

  /** 画完整小镇：多层底 + 路径 + 三区地标 */
  _paintWorld() {
    const root = this._worldRoot;
    root.removeAll(true);

    const ground = this.add.rectangle(
      WORLD_W / 2,
      WORLD_H / 2,
      WORLD_W,
      WORLD_H,
      0x355535
    );
    root.add(ground);

    const dots = this.add.graphics();
    for (let y = 4; y < WORLD_H; y += 12) {
      for (let x = 4; x < WORLD_W; x += 12) {
        const n = (x * 17 + y * 31) % 7;
        if (n === 0) {
          dots.fillStyle(0x4a6b42, 0.45);
          dots.fillRect(x, y, 2, 2);
        } else if (n === 3) {
          dots.fillStyle(0x2e4a2e, 0.35);
          dots.fillRect(x, y, 3, 2);
        } else if (n === 5) {
          dots.fillStyle(0x6a8050, 0.25);
          dots.fillRect(x + 1, y, 2, 2);
        }
      }
    }
    root.add(dots);

    const path = this.add.graphics();
    path.fillStyle(0xc4a878, 0.95);
    path.fillRect(500, 230, 240, 40);
    path.fillStyle(0xb89560, 0.75);
    path.fillRect(500, 242, 240, 10);
    path.fillStyle(0xc4a878, 0.9);
    path.fillRect(660, 268, 36, 210);
    path.fillStyle(0xb89560, 0.65);
    path.fillRect(668, 268, 10, 210);
    path.fillStyle(0xd9d2c4, 0.85);
    for (let x = 510; x < 730; x += 24) {
      path.fillRect(x, 226, 5, 4);
      path.fillRect(x + 8, 268, 5, 4);
    }
    for (let y = 280; y < 470; y += 28) {
      path.fillRect(656, y, 4, 5);
      path.fillRect(694, y + 6, 4, 5);
    }
    // 广场内环路
    path.fillStyle(0xb8a878, 0.55);
    path.fillRect(120, 250, 320, 14);
    path.fillRect(260, 160, 14, 200);
    root.add(path);

    for (const id of Object.keys(PLACES)) {
      this._paintPlace(root, PLACES[id]);
    }

    // 区间散景：树丛 / 栅栏柱，填空
    const props = this.add.graphics();
    const trees = [
      [30, 100],
      [60, 400],
      [480, 90],
      [520, 380],
      [680, 500],
      [900, 480],
      [1280, 120],
      [1320, 400],
      [200, 520],
      [1100, 90],
    ];
    for (const [tx, ty] of trees) {
      props.fillStyle(0x2d4a28, 0.85);
      props.fillRect(tx + 5, ty + 14, 6, 12);
      props.fillStyle(0x3f6b38, 0.9);
      props.fillRect(tx, ty, 16, 14);
      props.fillStyle(0x4a7a40, 0.7);
      props.fillRect(tx + 3, ty - 4, 10, 8);
    }
    root.add(props);

    const border = this.add.graphics();
    border.lineStyle(2, 0x1a1a18, 0.55);
    border.strokeRect(1, 1, WORLD_W - 2, WORLD_H - 2);
    root.add(border);
  }

  /**
   * @param {Phaser.GameObjects.Container} root
   * @param {import("./map.js").PlaceZone} z
   */
  _paintPlace(root, z) {
    const sky = this.add
      .rectangle(z.x + z.w / 2, z.y + 18, z.w - 6, 32, z.sky)
      .setStrokeStyle(1, z.accent, 0.45);
    root.add(sky);

    const clouds = this.add.graphics();
    clouds.fillStyle(0xffffff, 0.22);
    clouds.fillRect(z.x + 40, z.y + 10, 28, 8);
    clouds.fillRect(z.x + z.w - 90, z.y + 14, 36, 7);
    root.add(clouds);

    const floor = this.add
      .rectangle(z.x + z.w / 2, z.y + z.h / 2 + 6, z.w - 6, z.h - 36, z.floor)
      .setStrokeStyle(3, z.accent, 1);
    root.add(floor);

    const oval = this.add.ellipse(
      z.x + z.w / 2,
      z.y + z.h / 2 + 36,
      Math.min(z.w * 0.55, 280),
      Math.min(70, z.h * 0.35),
      z.path,
      0.55
    );
    root.add(oval);

    const tagBg = z.decorative ? "#fffdf8aa" : "#fffdf8dd";
    const tag = this.add
      .text(z.x + 12, z.y + 8, z.decorative ? `${z.label} · 装饰` : z.label, {
        fontFamily: "monospace, PingFang SC, sans-serif",
        fontSize: z.decorative ? "11px" : "13px",
        color: "#1c1a17",
        backgroundColor: tagBg,
        padding: { x: 6, y: 2 },
      })
      .setDepth(2);
    root.add(tag);

    if (z.id === "square") {
      const ring = this.add.circle(z.x + 200, z.y + 200, 44, 0x000000, 0);
      ring.setStrokeStyle(4, 0xd9d2c4, 0.6);
      const water = this.add.circle(z.x + 200, z.y + 200, 16, 0xa8c4d8, 0.9);
      const spout = this.add.rectangle(z.x + 200, z.y + 188, 4, 18, 0xc8dff0, 0.7);
      const bench = this.add.rectangle(z.x + 360, z.y + 280, 56, 12, 0x6b4f2a, 0.95);
      const bench2 = this.add.rectangle(z.x + 120, z.y + 300, 48, 10, 0x6b4f2a, 0.9);
      const bushL = this.add.ellipse(z.x + 70, z.y + 320, 44, 24, 0x4a6b3c, 0.85);
      const bushR = this.add.ellipse(z.x + 430, z.y + 310, 48, 26, 0x3f5f34, 0.8);
      const lamp = this.add.rectangle(z.x + 90, z.y + 160, 6, 40, 0x4a4030, 1);
      const lampTop = this.add.circle(z.x + 90, z.y + 138, 8, 0xffe066, 0.8);
      const bed = this.add.rectangle(z.x + 280, z.y + 140, 50, 18, 0x5a3a4a, 0.7);
      const flower = this.add.circle(z.x + 270, z.y + 136, 4, 0xe07a9a, 0.95);
      const flower2 = this.add.circle(z.x + 290, z.y + 140, 4, 0xffe066, 0.9);
      const stall = this.add
        .rectangle(z.x + 400, z.y + 160, 54, 36, 0xc4a878, 0.9)
        .setStrokeStyle(1, 0x5c4030, 0.8);
      const stallRoof = this.add.rectangle(z.x + 400, z.y + 140, 60, 10, 0xb03a3a, 0.9);
      const notice = this.add.rectangle(z.x + 160, z.y + 120, 28, 36, 0xd9d2c4, 0.9);
      root.add([
        ring,
        water,
        spout,
        bench,
        bench2,
        bushL,
        bushR,
        lamp,
        lampTop,
        bed,
        flower,
        flower2,
        stall,
        stallRoof,
        notice,
      ]);
    } else if (z.id === "mill") {
      const house = this.add
        .rectangle(z.x + 380, z.y + 160, 96, 74, 0x8a6d48, 0.95)
        .setStrokeStyle(2, 0x5c4030, 1);
      const roof = this.add.graphics();
      roof.fillStyle(0x6b3a2a, 0.95);
      roof.fillTriangle(
        z.x + 326,
        z.y + 128,
        z.x + 434,
        z.y + 128,
        z.x + 380,
        z.y + 90
      );
      const door = this.add.rectangle(z.x + 380, z.y + 178, 18, 28, 0x3a2a18, 0.95);
      const win = this.add.rectangle(z.x + 355, z.y + 150, 14, 12, 0xc4dff0, 0.85);
      const sack = this.add.ellipse(z.x + 140, z.y + 280, 52, 34, 0x8a6d48, 0.9);
      const sack2 = this.add.ellipse(z.x + 175, z.y + 300, 40, 26, 0x7a5f3c, 0.85);
      const post = this.add.rectangle(z.x + 80, z.y + 220, 14, 80, 0x5c4030, 0.95);
      const wheel = this.add.circle(z.x + 80, z.y + 170, 30, 0x000000, 0);
      wheel.setStrokeStyle(4, 0x5c4030, 0.9);
      const hub = this.add.circle(z.x + 80, z.y + 170, 6, 0x7a5f3c, 1);
      const spoke = this.add.rectangle(z.x + 80, z.y + 170, 52, 3, 0x5c4030, 0.7);
      const crate = this.add.rectangle(z.x + 280, z.y + 300, 36, 28, 0x6b4f2a, 0.9);
      const fence = this.add.graphics();
      fence.lineStyle(2, 0x5c4030, 0.7);
      fence.strokeRect(z.x + 240, z.y + 250, 100, 40);
      const silo = this.add.rectangle(z.x + 450, z.y + 280, 36, 70, 0x8a8a78, 0.9);
      const siloTop = this.add.ellipse(z.x + 450, z.y + 244, 40, 16, 0x6a6a5a, 0.9);
      const cart = this.add.rectangle(z.x + 200, z.y + 200, 48, 22, 0x6b4f2a, 0.85);
      const wheelL = this.add.circle(z.x + 188, z.y + 214, 8, 0x3a2a18, 0.9);
      const wheelR = this.add.circle(z.x + 220, z.y + 214, 8, 0x3a2a18, 0.9);
      root.add([
        house,
        roof,
        door,
        win,
        sack,
        sack2,
        post,
        wheel,
        hub,
        spoke,
        crate,
        fence,
        silo,
        siloTop,
        cart,
        wheelL,
        wheelR,
      ]);
    } else if (z.id === "bridge") {
      const water = this.add.rectangle(
        z.x + z.w / 2,
        z.y + z.h / 2 + 10,
        z.w - 20,
        48,
        0x6a9ab8,
        0.75
      );
      const deck = this.add.rectangle(
        z.x + z.w / 2,
        z.y + z.h / 2 + 4,
        120,
        22,
        0x8a6d48,
        0.95
      );
      const railL = this.add.rectangle(
        z.x + z.w / 2 - 55,
        z.y + z.h / 2 - 6,
        8,
        18,
        0x5c4030,
        0.9
      );
      const railR = this.add.rectangle(
        z.x + z.w / 2 + 55,
        z.y + z.h / 2 - 6,
        8,
        18,
        0x5c4030,
        0.9
      );
      const reed1 = this.add.ellipse(z.x + 40, z.y + z.h - 30, 16, 28, 0x4a6b3c, 0.8);
      const reed2 = this.add.ellipse(
        z.x + z.w - 40,
        z.y + z.h - 28,
        18,
        30,
        0x3f5f34,
        0.75
      );
      const rock = this.add.ellipse(z.x + 80, z.y + z.h / 2 + 20, 20, 10, 0x7a7a70, 0.7);
      root.add([water, deck, railL, railR, reed1, reed2, rock]);
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
    const c = clampCamera(
      cam.scrollX + dx * dist,
      cam.scrollY + dy * dist,
      this._viewW,
      this._viewH
    );
    cam.setScroll(c.x, c.y);
    this._updateCamBadge();
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
    this._viewLabel = view.locationLabel || placeId;
    const tick = view.tick != null ? String(view.tick) : "?";
    const tickNum = Number(tick);
    const lastNum = this._lastTick != null ? Number(this._lastTick) : null;
    // 新开一局：tick 回落 / 回到 0 → 强制重置镜头，避免居民落在屏外
    const tickReset =
      lastNum != null && !Number.isNaN(tickNum) && tickNum < lastNum;
    const placeChanged = placeId !== this._placeId;

    if (placeChanged || tickReset) {
      this._placeId = placeId;
      this._resetCameraToPlace(placeId, placeChanged && !tickReset);
    } else if (this._placeId == null) {
      this._placeId = placeId;
      this._resetCameraToPlace(placeId, false);
    }

    this._refreshPlaceLabel();

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
      if (this._selectPulse) {
        this._selectPulse.setFillStyle(0xffe066, 0.55);
        this.tweens.add({
          targets: this._selectPulse,
          alpha: 0,
          duration: 420,
          onStart: () => this._selectPulse.setAlpha(1),
        });
      }
    }
    this._lastTick = tick;

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
        const dx = x - node.x;
        const dy = y - node.y;
        this._setFacing(node, dx, dy);
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
   * @param {{ quiet?: boolean }} [opts] quiet=true：布局重算时重建命中，不播入场动画
   */
  syncMenu(menu, opts = {}) {
    const quiet = !!(opts && opts.quiet);
    this._lastMenu = menu || null;
    if (!this._menuRoot) {
      this._pendingMenu = menu;
      return;
    }
    this.tweens.killTweensOf(this._menuRoot);
    this._clearMenuHits();
    this._menuRoot.removeAll(true);

    const hud = this._hud || computeHud(this._viewW, this._viewH);
    const menuW = hud.menuW;
    const menuY = hud.menuY;
    this._menuRoot.setPosition(hud.menuX, menuY);

    const bg = this.add
      .rectangle(0, 0, menuW, 8, 0x0e0c0a, 0.94)
      .setOrigin(0, 0)
      .setScrollFactor(0);
    bg.setStrokeStyle(2, 0xffe066, 0.45);
    this._menuRoot.add(bg);

    const title = this.add
      .text(10, 8, "菜单", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "14px",
        color: "#ffe066",
        fontStyle: "bold",
      })
      .setOrigin(0, 0)
      .setScrollFactor(0);
    this._menuRoot.add(title);

    let y = 30;
    const actions = menu?.actions || [];
    if (!actions.length) {
      const empty = this.add
        .text(10, y, "此刻没有候选动作。", {
          fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
          fontSize: "12px",
          color: "#fffdf8aa",
          wordWrap: { width: menuW - 20 },
        })
        .setOrigin(0, 0)
        .setScrollFactor(0);
      this._menuRoot.add(empty);
      y += 28;
    } else {
      for (const a of actions) {
        const btnH = 36;
        const row = this._makeMenuButton(
          8,
          y,
          menuW - 16,
          btnH,
          a.label || a.id,
          a.kind || a.practiceId || "",
          () => {
            if (this._onAct) this._onAct(a.id);
          }
        );
        this._menuRoot.add(row);
        y += btnH + 6;
      }
    }

    const wait = this._makeMenuButton(
      8,
      y,
      menuW - 16,
      32,
      "稍候（praxWait）",
      "",
      () => {
        if (this._onWait) this._onWait();
      },
      0x3a4a3a
    );
    this._menuRoot.add(wait);
    y += 40;

    const h = Math.max(y + 8, 72);
    bg.setDisplaySize(menuW, h);
    this._menuRoot.setData("panelH", h);
    this._pinHud(this._menuRoot);

    if (quiet) {
      this._menuRoot.setAlpha(1);
      this._menuRoot.y = menuY;
    } else {
      this._menuRoot.setAlpha(0);
      this._menuRoot.y = menuY - 8;
      this.tweens.add({
        targets: this._menuRoot,
        alpha: 1,
        y: menuY,
        duration: 200,
        ease: "Cubic.easeOut",
      });
    }

    if (this._lastView && this._selectedId) {
      const actor = (this._lastView.actors || []).find(
        (a) => a.id === this._selectedId
      );
      const node = this._sprites.get(this._selectedId);
      if (actor && node) this._syncBubble(node, actor, this._lastView, menu);
    }
  }

  _clearMenuHits() {
    this._menuHits = [];
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

    const hud = this._hud || computeHud(this._viewW, this._viewH);
    const logW = hud.logW;
    const logH = hud.logH;
    this._logRoot.setPosition(hud.logX, hud.logY);

    const bg = this.add
      .rectangle(0, 0, logW, logH, 0x0e0c0a, 0.92)
      .setOrigin(0, 0)
      .setScrollFactor(0);
    bg.setStrokeStyle(2, 0xd9d2c4, 0.55);
    this._logRoot.add(bg);

    const title = this.add
      .text(10, 5, "对话与回合反馈", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "12px",
        color: "#ffe066",
        fontStyle: "bold",
      })
      .setOrigin(0, 0)
      .setScrollFactor(0);
    this._logRoot.add(title);

    if (!lines.length) {
      const empty = this.add
        .text(10, 24, "还没有发生的事。", {
          fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
          fontSize: "12px",
          color: "#fffdf8aa",
        })
        .setOrigin(0, 0)
        .setScrollFactor(0);
      this._logRoot.add(empty);
    } else {
      const tail = lines.slice(-5);
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
        const bar = this.add
          .rectangle(6, y + 2, 3, 16, barColor, 0.95)
          .setOrigin(0, 0)
          .setScrollFactor(0);
        const t = this.add
          .text(14, y, line.text || "", {
            fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
            fontSize: "11px",
            color,
            wordWrap: { width: logW - 28 },
          })
          .setOrigin(0, 0)
          .setScrollFactor(0);
        this._logRoot.add(bar);
        this._logRoot.add(t);
        y += Math.min(t.height + 4, 22);
        if (y > logH - 10) break;
      }
    }

    this._pinHud(this._logRoot);

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

  /**
   * 菜单按钮：视觉在 container 内；点击由 _tryMenuClick 按屏坐标处理。
   */
  _makeMenuButton(x, y, w, h, label, sub, onClick, fill = 0x2f6f4e) {
    const g = this.add.container(x, y).setScrollFactor(0);
    const bg = this.add
      .rectangle(0, 0, w, h, fill, 0.95)
      .setOrigin(0, 0)
      .setScrollFactor(0);
    bg.setStrokeStyle(1, 0xd9d2c4, 0.75);

    const shown = ellipsize(label, 16);
    const title = this.add
      .text(8, sub ? 4 : h / 2, shown, {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "12px",
        color: "#fffdf8",
      })
      .setOrigin(0, sub ? 0 : 0.5)
      .setScrollFactor(0);
    g.add(bg);
    g.add(title);
    if (sub) {
      const kind = this.add
        .text(8, 20, ellipsize(sub, 18), {
          fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
          fontSize: "10px",
          color: "#d9d2c4",
        })
        .setOrigin(0, 0)
        .setScrollFactor(0);
      g.add(kind);
    }

    // 点击走 _tryMenuClick（屏坐标）；悬停走 _hoverMenu
    this._menuHits.push({ x, y, w, h, onClick, bg, g, fill });
    return g;
  }

  _makeActor(id, label, x, y) {
    const fill = actorFill(id);
    const tex = ensureActorTextures(this, id, fill);

    const shadow = this.add.ellipse(0, 22, 22, 8, 0x000000, 0.3);
    const body = this.add.sprite(0, 0, tex.sheet, 0);
    body.setScale(SPRITE_SCALE);
    body.setData("actorId", id);
    body.setData("face", "down");
    body.play(animKey(id, "idle", "down"));

    const ring = this.add.circle(0, 4, R + 6, 0x000000, 0);
    ring.setStrokeStyle(2, 0xffe066, 0);
    ring.setVisible(false);

    const arrow = this.add
      .triangle(0, -52, 0, 0, 6, 8, -6, 8, 0xffe066, 0.95)
      .setVisible(false);

    const bubbleBg = this.add
      .rectangle(0, -40, 8, 18, 0xfffdf8, 0.96)
      .setStrokeStyle(1, 0x1c1a17, 0.6)
      .setVisible(false);
    const bubbleText = this.add
      .text(0, -40, "", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "11px",
        color: "#1c1a17",
        align: "center",
        wordWrap: { width: 140 },
        padding: { x: 3, y: 1 },
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
      arrow,
      bubbleBg,
      bubbleText,
      name,
      hit,
    ]);
    node.setSize((R + 8) * 2, (R + 8) * 2);
    node.setData("body", body);
    node.setData("ring", ring);
    node.setData("arrow", arrow);
    node.setData("labelText", name);
    node.setData("bubbleBg", bubbleBg);
    node.setData("bubbleText", bubbleText);
    node.setData("actorId", id);
    node.setData("walking", false);
    node.setData("face", "down");
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

    return node;
  }

  /**
   * @param {Phaser.GameObjects.Container} node
   * @param {number} dx
   * @param {number} dy
   */
  _setFacing(node, dx, dy) {
    const { face, flipX } = facingFromDelta(dx, dy);
    node.setData("face", face);
    const body = node.getData("body");
    if (!body) return;
    body.setFlipX(flipX);
    body.setData("face", face);
    const walking = node.getData("walking");
    const id = node.getData("actorId");
    const key = animKey(id, walking ? "walk" : "idle", face);
    if (body.anims.currentAnim?.key !== key) {
      body.play(key, true);
    }
  }

  _playWalk(node, walking) {
    node.setData("walking", !!walking);
    const body = node.getData("body");
    if (!body) return;
    const id = node.getData("actorId");
    const face = node.getData("face") || "down";
    const key = animKey(id, walking ? "walk" : "idle", face);
    body.play(key, true);
  }

  _syncBubble(node, actor, view, menu) {
    const bg = node.getData("bubbleBg");
    const tx = node.getData("bubbleText");
    const arrow = node.getData("arrow");
    if (!bg || !tx) return;
    const text = bubbleFromView(actor, view, menu);
    if (!text) {
      bg.setVisible(false);
      tx.setVisible(false);
      return;
    }
    tx.setText(text);
    const w = Math.max(Math.min(tx.width + 16, 148), 28);
    const h = Math.max(tx.height + 10, 18);
    bg.setSize(w, h);
    bg.setDisplaySize(w, h);
    const by = arrow && arrow.visible ? -62 : -44;
    bg.setY(by);
    tx.setY(by);
    bg.setVisible(true);
    tx.setVisible(true);
  }

  _killActorTweens(node) {
    this.tweens.killTweensOf(node);
    const ring = node.getData("ring");
    const body = node.getData("body");
    const arrow = node.getData("arrow");
    if (ring) this.tweens.killTweensOf(ring);
    if (body) this.tweens.killTweensOf(body);
    if (arrow) this.tweens.killTweensOf(arrow);
  }

  _paintSelected(node, selected) {
    const ring = node.getData("ring");
    const arrow = node.getData("arrow");
    if (selected) {
      if (ring) {
        ring.setVisible(true);
        ring.setStrokeStyle(2, 0xffe066, 0.95);
        ring.setScale(1);
        ring.setAlpha(1);
        this.tweens.killTweensOf(ring);
        this.tweens.add({
          targets: ring,
          scaleX: 1.18,
          scaleY: 1.18,
          duration: 480,
          yoyo: true,
          repeat: -1,
          ease: "Sine.easeInOut",
        });
      }
      if (arrow) {
        arrow.setVisible(true);
        arrow.setAlpha(1);
        this.tweens.killTweensOf(arrow);
        this.tweens.add({
          targets: arrow,
          y: -56,
          duration: 420,
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
      if (arrow) {
        this.tweens.killTweensOf(arrow);
        arrow.setVisible(false);
        arrow.y = -52;
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

function ellipsize(text, max) {
  const s = String(text || "").replace(/\s+/g, " ").trim();
  if (!s) return "";
  if (s.length <= max) return s;
  return s.slice(0, Math.max(0, max - 1)) + "…";
}

export const TOWN_SIZE = { width: VIEW_W, height: VIEW_H };
