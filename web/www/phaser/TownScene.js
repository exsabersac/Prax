/**
 * U13 TownScene：表现层减卡（叠 U12）。
 * 脏刷新选中/呼吸/气泡/日志/菜单；避免 paint 路径空转重绘与无限 tween 重启风暴。
 * Act 按下立即派发（视觉压下不挡回调）；U6–U12 观感等价不故意回退。
 * BAKED 仍仅 you；Session/api 零改。
 */
import { actorFill, bubbleFromView } from "./actors.js";
import {
  VIEW_W,
  VIEW_H,
  WORLD_W,
  WORLD_H,
  PLACES,
  PATH_SPINE,
  SIGNPOSTS,
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

/** 设计参考下的默认 HUD；实际由 computeHud(viewW,viewH) 随布局重算 */
const MENU_W0 = 200;
const LOG_H0 = 88;

const CAM_SPEED = 240;

/**
 * U8/U9 HUD：菜单右上；日志贴菜单下方右侧（不挡中左主舞台）；
 * 地名 / tick 左上纵排；镜头徽章贴菜单左上，互不重叠（不回退）。
 */
function computeHud(viewW, viewH) {
  const vw = Math.max(2, viewW | 0);
  const vh = Math.max(2, viewH | 0);
  const menuW = Math.min(MENU_W0, Math.max(140, Math.floor(vw * 0.28)));
  const menuX = Math.max(8, vw - menuW - 10);
  const menuY = 36; // 给顶栏徽章留位
  // 日志：右侧底栏，与菜单同列，中左舞台留给角色
  const logW = menuW;
  const logH = Math.min(LOG_H0, Math.max(52, Math.floor(vh * 0.16)));
  const logX = menuX;
  const logY = Math.max(menuY + 100, vh - logH - 6);
  // 顶栏分槽（U8-02）
  const placeX = 10;
  const placeY = 8;
  const tickX = 10;
  const tickY = 32;
  const camX = menuX - 6;
  const camY = 8;
  // hint 贴底左，矮条，不盖角色腰线
  const hintY = Math.max(24, vh - 4);
  return {
    vw,
    vh,
    menuX,
    menuY,
    menuW,
    logX,
    logY,
    logW,
    logH,
    hintY,
    placeX,
    placeY,
    tickX,
    tickY,
    camX,
    camY,
  };
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
    /** @type {string} */
    this._lastCamBadge = "";
    /** @type {number} */
    this._hoverIdx = -1;
    /** @type {string} */
    this._lastMenuKey = "";
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
      this.syncLog(this._lastView, { force: true });
    } else if (this._logRoot) {
      this._logRoot.setPosition(this._hud.logX, this._hud.logY);
    }
    this._updateCamBadge();
  }

  /** 仅搬 HUD 铬件位置/宽度，不重建菜单内容（U8 分槽） */
  _relayoutHudChrome() {
    const h = this._hud;
    if (!h) return;
    if (this._placeLabel) this._placeLabel.setPosition(h.placeX, h.placeY);
    if (this._tickLabel) {
      this._tickLabel.setOrigin(0, 0);
      this._tickLabel.setPosition(h.tickX, h.tickY);
    }
    if (this._camBadge) this._camBadge.setPosition(h.camX, h.camY);
    if (this._hint) {
      // 底左矮条；窄屏时藏到菜单下以免挡
      const hideHint = h.vw < 420;
      this._hint.setVisible(!hideHint);
      this._hint.setPosition(10, h.hintY);
      this._hint.setOrigin(0, 1);
    }
    if (this._selectPulse && typeof this._selectPulse.setSize === "function") {
      this._selectPulse.setSize(h.vw, 5);
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

    // HUD（固定于镜头；全部 scrollFactor 0）— U8 分槽：地名/tick 左上纵排，徽章贴菜单左
    const hud0 = this._hud;
    this._placeLabel = this.add
      .text(hud0.placeX, hud0.placeY, "", {
        fontFamily: "monospace, PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "12px",
        color: "#fffdf8",
        backgroundColor: "#000000aa",
        padding: { x: 7, y: 3 },
      })
      .setScrollFactor(0)
      .setDepth(40);

    this._tickLabel = this.add
      .text(hud0.tickX, hud0.tickY, "", {
        fontFamily: "monospace, PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "11px",
        color: "#fffdf8",
        backgroundColor: "#00000099",
        padding: { x: 7, y: 3 },
      })
      .setOrigin(0, 0)
      .setScrollFactor(0)
      .setDepth(40);

    // 镜头徽章：菜单左上角外侧，不与地名/tick 互叠
    this._camBadge = this.add
      .text(hud0.camX, hud0.camY, "", {
        fontFamily: "monospace, PingFang SC, sans-serif",
        fontSize: "10px",
        color: "#ffe066",
        backgroundColor: "#00000088",
        padding: { x: 6, y: 3 },
      })
      .setOrigin(1, 0)
      .setScrollFactor(0)
      .setDepth(41)
      .setAlpha(0.9);

    this._hint = this.add
      .text(10, hud0.hintY, "方向键/拖拽 · 点选 → 菜单 → Act", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "10px",
        color: "#fffdf8aa",
        backgroundColor: "#00000055",
        padding: { x: 5, y: 2 },
      })
      .setScrollFactor(0)
      .setDepth(35)
      .setOrigin(0, 1);

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

    // U12-01：顶栏选中/Act 闪条加厚，反馈更可感
    this._selectPulse = this.add
      .rectangle(0, 0, hud0.vw, 5, 0xffe066, 0)
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
    let hitIdx = -1;
    for (let i = 0; i < hits.length; i++) {
      const rec = hits[i];
      const sx = rootX + rec.x;
      const sy = rootY + rec.y;
      if (
        pointer.x >= sx &&
        pointer.x <= sx + rec.w &&
        pointer.y >= sy &&
        pointer.y <= sy + rec.h
      ) {
        hitIdx = i;
        break;
      }
    }
    if (hitIdx === this._hoverIdx) {
      if (this.game && this.game.canvas) {
        this.game.canvas.style.cursor = hitIdx >= 0 ? "pointer" : "";
      }
      return;
    }
    this._hoverIdx = hitIdx;
    for (let i = 0; i < hits.length; i++) {
      const rec = hits[i];
      if (!rec.bg) continue;
      if (i === hitIdx) {
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
      this.game.canvas.style.cursor = hitIdx >= 0 ? "pointer" : "";
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
        // U12-01：Act 按下反馈更清晰（亮填 + 粗描边 + 压下弹回 + 顶栏绿闪），不挡不误触
        if (rec.bg) {
          rec.bg.setFillStyle(0xffe066, 1);
          rec.bg.setStrokeStyle(3, 0xfffdf8, 1);
          this.time.delayedCall(120, () => {
            if (rec.bg && rec.bg.active !== false) {
              rec.bg.setFillStyle(rec.fill, 0.95);
              rec.bg.setStrokeStyle(1, 0xd9d2c4, 0.75);
            }
          });
        }
        if (this._selectPulse) {
          this._selectPulse.setFillStyle(0x7dcea0, 0.85);
          this.tweens.killTweensOf(this._selectPulse);
          this._selectPulse.setAlpha(1);
          this.tweens.add({
            targets: this._selectPulse,
            alpha: 0,
            duration: 420,
          });
        }
        // U13-02：先派发 Act，压下动画不挡回调（避免半拍延迟）
        if (rec.onClick) rec.onClick();
        if (rec.g) {
          this.tweens.add({
            targets: rec.g,
            scaleX: 0.9,
            scaleY: 0.9,
            duration: 80,
            yoyo: true,
            ease: "Back.easeOut",
          });
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
    // 窄屏缩短徽章，避免与左侧 tick 互叠（U8-02）
    const slim = (this._viewW || VIEW_W) < 520;
    const tag = slim
      ? `镜头 ${px}%,${py}%`
      : `镜头 ${px}%,${py}%${scaleTag}`;
    if (tag !== this._lastCamBadge) {
      this._lastCamBadge = tag;
      this._camBadge.setText(tag);
    }
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
    let next = "";
    if (focus && this._placeId && focus.id !== this._placeId) {
      next = `所在 ${hereLabel} · 画面 ${focus.label}`;
    } else if (focus && (!this._placeId || focus.id === this._placeId)) {
      next = hereLabel || focus.label;
    } else {
      next = hereLabel || "";
    }
    if (this._placeLabel.text !== next) {
      this._placeLabel.setText(next);
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

  /** 画完整小镇：多层底 + 路径层次 + 三区地标（U12 再精修，不扩地点） */
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

    // 远景草带（层次底）
    const bands = this.add.graphics();
    bands.fillStyle(0x2e4a2e, 0.35);
    bands.fillRect(0, 0, WORLD_W, 48);
    bands.fillStyle(0x3a5a38, 0.25);
    bands.fillRect(0, WORLD_H - 40, WORLD_W, 40);
    root.add(bands);

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

    // U12-02：路径阴影 + 路面 + 路缘 + 中线虚线 + 方向箭头，主道更可读
    const pathShadow = this.add.graphics();
    pathShadow.fillStyle(0x1a1a18, 0.28);
    for (const seg of PATH_SPINE) {
      pathShadow.fillRect(seg.x + 3, seg.y + 5, seg.w, seg.h);
    }
    root.add(pathShadow);

    const path = this.add.graphics();
    // 主干：广场→磨坊
    path.fillStyle(0xc4a878, 0.97);
    path.fillRect(500, 230, 240, 40);
    path.fillStyle(0xb89560, 0.8);
    path.fillRect(500, 242, 240, 10);
    path.fillStyle(0xd9c090, 0.55);
    path.fillRect(500, 232, 240, 4);
    // 主干延伸到磨坊门口
    path.fillStyle(0xc4a878, 0.92);
    path.fillRect(720, 236, 90, 28);
    path.fillStyle(0xb89560, 0.7);
    path.fillRect(720, 248, 90, 8);
    // 主干→小桥
    path.fillStyle(0xc4a878, 0.92);
    path.fillRect(660, 268, 36, 210);
    path.fillStyle(0xb89560, 0.7);
    path.fillRect(668, 268, 10, 210);
    // 路缘石（双排更醒目）
    path.fillStyle(0xd9d2c4, 0.95);
    for (let x = 510; x < 800; x += 18) {
      path.fillRect(x, 224, 7, 5);
      path.fillRect(x + 5, 268, 7, 5);
    }
    for (let y = 280; y < 470; y += 20) {
      path.fillRect(652, y, 6, 7);
      path.fillRect(692, y + 3, 6, 7);
    }
    // 广场内环路 + 中间虚线
    path.fillStyle(0xb8a878, 0.7);
    path.fillRect(120, 250, 320, 14);
    path.fillRect(260, 160, 14, 200);
    path.fillStyle(0xf0e6c8, 0.7);
    for (let x = 140; x < 420; x += 16) path.fillRect(x, 255, 9, 3);
    for (let y = 180; y < 340; y += 16) path.fillRect(265, y, 3, 9);
    // 主干中线虚线（方向感）
    path.fillStyle(0xfff8e0, 0.65);
    for (let x = 520; x < 780; x += 22) path.fillRect(x, 247, 12, 3);
    for (let y = 290; y < 460; y += 22) path.fillRect(675, y, 3, 12);
    // 踏脚石：广场→磨坊衔接
    path.fillStyle(0xd0b888, 0.9);
    for (let i = 0; i < 6; i++) {
      path.fillRect(478 + i * 8, 236 + (i % 2) * 7, 11, 9);
    }
    // U12：方向箭头（装饰）
    path.fillStyle(0xfffdf8, 0.75);
    // → 往磨坊
    path.fillTriangle(610, 242, 610, 258, 628, 250);
    path.fillTriangle(640, 242, 640, 258, 658, 250);
    // ↓ 往小桥
    path.fillTriangle(668, 360, 688, 360, 678, 378);
    path.fillTriangle(668, 400, 688, 400, 678, 418);
    root.add(path);

    for (const id of Object.keys(PLACES)) {
      this._paintPlace(root, PLACES[id]);
    }

    // 区间散景：树丛 / 栅栏 / 路牌，填空且强化层次
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
      [760, 40],
      [980, 300],
      [40, 560],
      [1180, 520],
    ];
    for (const [tx, ty] of trees) {
      props.fillStyle(0x1a2a18, 0.35);
      props.fillRect(tx + 1, ty + 24, 18, 6);
      props.fillStyle(0x2d4a28, 0.85);
      props.fillRect(tx + 5, ty + 14, 6, 12);
      props.fillStyle(0x3f6b38, 0.9);
      props.fillRect(tx, ty, 16, 14);
      props.fillStyle(0x4a7a40, 0.7);
      props.fillRect(tx + 3, ty - 4, 10, 8);
    }
    // 路边栅栏柱
    props.fillStyle(0x5c4030, 0.8);
    for (let x = 520; x < 720; x += 28) {
      props.fillRect(x, 218, 4, 12);
      props.fillRect(x - 1, 216, 6, 3);
    }
    // 路牌底柱（广场东口，保留）
    props.fillStyle(0x6b4f2a, 0.95);
    props.fillRect(492, 210, 5, 28);
    props.fillStyle(0xd9d2c4, 0.95);
    props.fillRect(478, 208, 34, 12);
    root.add(props);

    // U12-02：中文路标（装饰，不扩世界地点）
    for (const sp of SIGNPOSTS) {
      const post = this.add.rectangle(sp.x, sp.y + 14, 5, 28, 0x5c4030, 0.95);
      const board = this.add
        .rectangle(sp.x + 2, sp.y, 52, 16, 0xfffdf8, 0.92)
        .setStrokeStyle(1, 0x5c4030, 0.85);
      const lbl = this.add
        .text(sp.x + 2, sp.y, sp.label, {
          fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
          fontSize: "10px",
          color: "#1c1a17",
          fontStyle: "bold",
        })
        .setOrigin(0.5, 0.5);
      root.add([post, board, lbl]);
    }

    const border = this.add.graphics();
    border.lineStyle(2, 0x1a1a18, 0.55);
    border.strokeRect(1, 1, WORLD_W - 2, WORLD_H - 2);
    root.add(border);

    // U13-03：静态世界合批成一张纹理，削减每帧 display list
    this._flattenWorld(root);
  }

  /**
   * 将 _worldRoot 子树烘成单图；失败则保留原对象树（观感不回退）。
   * @param {Phaser.GameObjects.Container} root
   */
  _flattenWorld(root) {
    if (!root || !this.textures) return;
    try {
      const key = "u13-world-bake";
      if (this.textures.exists(key)) {
        this.textures.remove(key);
      }
      const rt = this.make.renderTexture(
        { x: 0, y: 0, width: WORLD_W, height: WORLD_H },
        false
      );
      rt.draw(root);
      rt.saveTexture(key);
      root.removeAll(true);
      rt.destroy();
      const img = this.add.image(0, 0, key).setOrigin(0, 0);
      root.add(img);
    } catch (err) {
      console.warn("U13 world flatten skipped", err);
    }
  }

  /**
   * @param {Phaser.GameObjects.Container} root
   * @param {import("./map.js").PlaceZone} z
   */
  _paintPlace(root, z) {
    // U12-02：区阴影 + 天空带 + 边框，层次更分明
    const drop = this.add.rectangle(
      z.x + z.w / 2 + 4,
      z.y + z.h / 2 + 10,
      z.w - 2,
      z.h - 28,
      0x1a1a18,
      0.18
    );
    root.add(drop);

    const sky = this.add
      .rectangle(z.x + z.w / 2, z.y + 18, z.w - 6, 32, z.sky)
      .setStrokeStyle(1, z.accent, 0.45);
    root.add(sky);

    const clouds = this.add.graphics();
    clouds.fillStyle(0xffffff, 0.22);
    clouds.fillRect(z.x + 40, z.y + 10, 28, 8);
    clouds.fillRect(z.x + z.w - 90, z.y + 14, 36, 7);
    clouds.fillStyle(0xffffff, 0.12);
    clouds.fillRect(z.x + z.w / 2 - 20, z.y + 8, 40, 6);
    root.add(clouds);

    const floor = this.add
      .rectangle(z.x + z.w / 2, z.y + z.h / 2 + 6, z.w - 6, z.h - 36, z.floor)
      .setStrokeStyle(4, z.accent, 1);
    root.add(floor);
    // U12：区外亮边，远处也能分清地块
    const rim = this.add
      .rectangle(z.x + z.w / 2, z.y + z.h / 2 + 6, z.w - 2, z.h - 32, 0x000000, 0)
      .setStrokeStyle(1, 0xfffdf8, z.decorative ? 0.25 : 0.4);
    root.add(rim);

    // 地面浅色斜纹，区与区更好区分
    const hatch = this.add.graphics();
    hatch.lineStyle(1, z.accent, 0.18);
    for (let i = 0; i < 8; i++) {
      const hx = z.x + 20 + i * Math.floor((z.w - 40) / 7);
      hatch.lineBetween(hx, z.y + 50, hx + 18, z.y + z.h - 30);
    }
    root.add(hatch);

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
      const ringShadow = this.add.circle(z.x + 204, z.y + 206, 46, 0x1a1a18, 0.2);
      const ring = this.add.circle(z.x + 200, z.y + 200, 44, 0x000000, 0);
      ring.setStrokeStyle(4, 0xd9d2c4, 0.75);
      const ringInner = this.add.circle(z.x + 200, z.y + 200, 28, 0x000000, 0);
      ringInner.setStrokeStyle(2, 0xc4b898, 0.45);
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
      // 摊位条纹顶
      const stripe = this.add.rectangle(z.x + 400, z.y + 136, 60, 4, 0xfffdf8, 0.55);
      root.add([
        ringShadow,
        ring,
        ringInner,
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
        stripe,
        notice,
      ]);
    } else if (z.id === "mill") {
      const houseShadow = this.add.rectangle(
        z.x + 388,
        z.y + 168,
        96,
        74,
        0x1a1a18,
        0.25
      );
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
      // 磨坊门口踏板
      const step = this.add.rectangle(z.x + 380, z.y + 198, 28, 6, 0x6b4f2a, 0.9);
      root.add([
        houseShadow,
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
        step,
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
      const shine = this.add.rectangle(
        z.x + z.w / 2,
        z.y + z.h / 2 + 2,
        z.w - 40,
        6,
        0xc8e6f0,
        0.35
      );
      const deck = this.add.rectangle(
        z.x + z.w / 2,
        z.y + z.h / 2 + 4,
        120,
        22,
        0x8a6d48,
        0.95
      );
      const plank = this.add.graphics();
      plank.lineStyle(1, 0x5c4030, 0.55);
      for (let i = -50; i <= 50; i += 14) {
        plank.lineBetween(
          z.x + z.w / 2 + i,
          z.y + z.h / 2 - 4,
          z.x + z.w / 2 + i,
          z.y + z.h / 2 + 14
        );
      }
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
      root.add([water, shine, deck, plank, railL, railR, reed1, reed2, rock]);
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

    const player =
      view.playerLabel ||
      (view.playerId === "you" ? "你" : view.playerId) ||
      "你";
    const tickStr = `回合 ${tick} · ${player}`;
    if (this._tickLabel.text !== tickStr) {
      this._tickLabel.setText(tickStr);
    }

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

    // 先钉选中，供呼吸幅度 / 脏刷新使用
    this._selectedId = view.selectedActorId || null;

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
        this.tweens.killTweensOf(node);
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
      const wantLabel = a.label || a.id;
      if (label && label.text !== wantLabel) {
        label.setText(wantLabel);
      }
      this._paintSelected(node, a.id === this._selectedId);
      this._syncBubble(node, a, view, this._lastMenu);
    });

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

    const hud = this._hud || computeHud(this._viewW, this._viewH);
    const menuW = hud.menuW;
    const menuY = hud.menuY;
    const actions = (menu && menu.actions) || [];
    const menuKey = `${(menu && menu.actorId) || ""}|${actions
      .map((a) => `${a.id}:${a.label || ""}:${a.kind || ""}`)
      .join(",")}|${menuW}`;
    // 同内容且非 quiet 重布局：跳过整板重建（U13-03）
    if (!quiet && menuKey === this._lastMenuKey && this._menuRoot.list.length) {
      if (this._lastView && this._selectedId) {
        const actor = (this._lastView.actors || []).find(
          (a) => a.id === this._selectedId
        );
        const node = this._sprites.get(this._selectedId);
        if (actor && node) this._syncBubble(node, actor, this._lastView, menu);
      }
      return;
    }
    this._lastMenuKey = menuKey;

    this.tweens.killTweensOf(this._menuRoot);
    this._clearMenuHits();
    this._hoverIdx = -1;
    this._menuRoot.removeAll(true);

    this._menuRoot.setPosition(hud.menuX, menuY);

    const bg = this.add
      .rectangle(0, 0, menuW, 8, 0x0e0c0a, 0.94)
      .setOrigin(0, 0)
      .setScrollFactor(0);
    bg.setStrokeStyle(2, 0xffe066, 0.45);
    this._menuRoot.add(bg);

    // U12-01：左侧金色强调条，菜单入场更醒目
    const accent = this.add
      .rectangle(0, 0, 4, 8, 0xffe066, 1)
      .setOrigin(0, 0)
      .setScrollFactor(0);
    this._menuRoot.add(accent);

    let who = "";
    if (menu && menu.actorId && this._lastView) {
      const a = (this._lastView.actors || []).find((x) => x.id === menu.actorId);
      who = (a && a.label) || "";
    } else if (this._selectedId && this._lastView) {
      const a = (this._lastView.actors || []).find((x) => x.id === this._selectedId);
      who = (a && a.label) || "";
    }
    const titleStr = who ? `菜单 · ${who}` : "菜单";
    const title = this.add
      .text(12, 8, titleStr, {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "14px",
        color: "#ffe066",
        fontStyle: "bold",
      })
      .setOrigin(0, 0)
      .setScrollFactor(0);
    this._menuRoot.add(title);

    let y = 30;
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
        const btnH = 40;
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
      "稍候",
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

    // 强调条跟面板高度（直接用 accent 引用，避免 list 下标漂移）
    if (accent && typeof accent.setDisplaySize === "function") {
      accent.setDisplaySize(4, h);
    }

    if (quiet) {
      this._menuRoot.setAlpha(1);
      this._menuRoot.y = menuY;
    } else {
      // U12-01：菜单入场更清晰（下滑弹入 + 白描边闪 + 强调条）；不改 scale，避免屏坐标命中短暂错位
      this._menuRoot.setAlpha(0);
      this._menuRoot.y = menuY - 22;
      this.tweens.add({
        targets: this._menuRoot,
        alpha: 1,
        y: menuY,
        duration: 300,
        ease: "Back.easeOut",
      });
      bg.setStrokeStyle(3, 0xfffdf8, 1);
      this.time.delayedCall(280, () => {
        if (bg && bg.active !== false) bg.setStrokeStyle(2, 0xffe066, 0.55);
      });
      if (this._selectPulse) {
        this._selectPulse.setFillStyle(0xffe066, 0.55);
        this.tweens.killTweensOf(this._selectPulse);
        this._selectPulse.setAlpha(1);
        this.tweens.add({
          targets: this._selectPulse,
          alpha: 0,
          duration: 380,
        });
      }
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
  syncLog(view, opts = {}) {
    if (!this._logRoot) return;

    const force = !!(opts && opts.force);
    const lines = (view && view.log) || [];
    const key = lines.map((l) => `${l.kind}|${l.text}`).join("\n");
    const changed = key !== this._lastLogKey;
    const hud = this._hud || computeHud(this._viewW, this._viewH);
    if (!changed && !force) {
      if (this._logRoot.alpha < 1) this._logRoot.setAlpha(1);
      return;
    }
    this._lastLogKey = key;

    this._logRoot.removeAll(true);

    const logW = hud.logW;
    const logH = hud.logH;
    this._logRoot.setPosition(hud.logX, hud.logY);

    // U8：半透明右侧底栏，不挡中左主舞台角色
    const bg = this.add
      .rectangle(0, 0, logW, logH, 0x0e0c0a, 0.78)
      .setOrigin(0, 0)
      .setScrollFactor(0);
    bg.setStrokeStyle(1, 0xd9d2c4, 0.4);
    this._logRoot.add(bg);

    const title = this.add
      .text(8, 4, "对话 / 反馈", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "11px",
        color: "#ffe066",
        fontStyle: "bold",
      })
      .setOrigin(0, 0)
      .setScrollFactor(0);
    this._logRoot.add(title);

    if (!lines.length) {
      const empty = this.add
        .text(8, 20, "还没有发生的事。", {
          fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
          fontSize: "11px",
          color: "#fffdf8aa",
        })
        .setOrigin(0, 0)
        .setScrollFactor(0);
      this._logRoot.add(empty);
    } else {
      const tail = lines.slice(-4);
      let y = 18;
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
          .rectangle(5, y + 1, 2, 12, barColor, 0.9)
          .setOrigin(0, 0)
          .setScrollFactor(0);
        const t = this.add
          .text(11, y, line.text || "", {
            fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
            fontSize: "10px",
            color,
            wordWrap: { width: logW - 20 },
          })
          .setOrigin(0, 0)
          .setScrollFactor(0);
        this._logRoot.add(bar);
        this._logRoot.add(t);
        y += Math.min(t.height + 3, 20);
        if (y > logH - 8) break;
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

    const title = this.add
      .text(8, sub ? 3 : h / 2, String(label || ""), {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "12px",
        color: "#fffdf8",
        wordWrap: { width: Math.max(40, w - 16) },
      })
      .setOrigin(0, sub ? 0 : 0.5)
      .setScrollFactor(0);
    g.add(bg);
    g.add(title);
    if (sub) {
      const kind = this.add
        .text(8, 19, ellipsize(sub, 22), {
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

    // U12-01：选中底盘柔光 + 双环，选中更可感且不挡命中
    const ringFill = this.add.circle(0, 8, R + 10, 0xffe066, 0);
    ringFill.setVisible(false);

    const ring = this.add.circle(0, 4, R + 6, 0x000000, 0);
    ring.setStrokeStyle(3, 0xffe066, 0);
    ring.setVisible(false);

    const ringOuter = this.add.circle(0, 4, R + 14, 0x000000, 0);
    ringOuter.setStrokeStyle(2, 0xfffdf8, 0);
    ringOuter.setVisible(false);

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
        wordWrap: { width: 200 },
        padding: { x: 4, y: 2 },
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
      ringFill,
      ringOuter,
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
    node.setData("ringOuter", ringOuter);
    node.setData("ringFill", ringFill);
    node.setData("arrow", arrow);
    node.setData("shadow", shadow);
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
      ringFill.setVisible(true);
      ringFill.setFillStyle(0xffe066, 0.35);
      ringFill.setScale(1);
      ringFill.setAlpha(1);
      ring.setVisible(true);
      ring.setStrokeStyle(3.5, 0xffe066, 1);
      ring.setScale(1);
      ring.setAlpha(1);
      ringOuter.setVisible(true);
      ringOuter.setStrokeStyle(2.5, 0xfffdf8, 0.85);
      ringOuter.setScale(1);
      ringOuter.setAlpha(1);
      this.tweens.add({
        targets: [ring, ringOuter, ringFill],
        scaleX: 1.5,
        scaleY: 1.5,
        alpha: 0,
        duration: 320,
        onComplete: () => {
          ring.setScale(1);
          ring.setAlpha(1);
          ringOuter.setScale(1);
          ringOuter.setAlpha(1);
          ringFill.setScale(1);
          ringFill.setAlpha(1);
          if (id !== this._selectedId) {
            ring.setVisible(false);
            ring.setStrokeStyle(3, 0xffe066, 0);
            ringOuter.setVisible(false);
            ringFill.setVisible(false);
            ringFill.setFillStyle(0xffe066, 0);
          }
        },
      });
      // U12-01：顶栏选中闪更醒目
      if (this._selectPulse) {
        this._selectPulse.setFillStyle(0xffe066, 0.8);
        this.tweens.killTweensOf(this._selectPulse);
        this._selectPulse.setAlpha(1);
        this.tweens.add({
          targets: this._selectPulse,
          alpha: 0,
          duration: 420,
        });
      }
      if (this._onSelect) this._onSelect(id);
    });

    // U9-03：创建后即站位呼吸
    this._syncBreath(node, true);
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
    // U9-03：站位呼吸（idle 时身影微 bob；走位时停）
    this._syncBreath(node, !walking);
  }

  /**
   * 站位呼吸：body/shadow 轻微起伏，选中时幅度略大。
   * @param {Phaser.GameObjects.Container} node
   * @param {boolean} on
   */
  _syncBreath(node, on) {
    const body = node.getData("body");
    const shadow = node.getData("shadow");
    const want = !!on;
    const amp = want
      ? node.getData("actorId") === this._selectedId
        ? 1.6
        : 1.1
      : 0;
    // 同状态不重启无限 tween（U13-03）
    if (want && node.getData("breathOn") && node.getData("breathAmp") === amp) {
      return;
    }
    if (!want && !node.getData("breathOn")) {
      return;
    }
    if (body) this.tweens.killTweensOf(body);
    if (shadow) this.tweens.killTweensOf(shadow);
    node.setData("breathOn", want);
    node.setData("breathAmp", amp);
    if (!want) {
      if (body) body.y = 0;
      if (shadow) {
        shadow.y = 22;
        shadow.setScale(1);
        shadow.setAlpha(0.3);
      }
      return;
    }
    if (body) {
      body.y = 0;
      this.tweens.add({
        targets: body,
        y: -amp,
        duration: 780,
        yoyo: true,
        repeat: -1,
        ease: "Sine.easeInOut",
      });
    }
    if (shadow) {
      shadow.y = 22;
      this.tweens.add({
        targets: shadow,
        scaleX: 0.88,
        scaleY: 0.88,
        alpha: 0.22,
        duration: 780,
        yoyo: true,
        repeat: -1,
        ease: "Sine.easeInOut",
      });
    }
  }

  _syncBubble(node, actor, view, menu) {
    const bg = node.getData("bubbleBg");
    const tx = node.getData("bubbleText");
    const arrow = node.getData("arrow");
    if (!bg || !tx) return;
    const text = bubbleFromView(actor, view, menu);
    if (!text) {
      if (bg.visible) bg.setVisible(false);
      if (tx.visible) tx.setVisible(false);
      node.setData("bubbleKey", "");
      return;
    }
    // U8：完整两行量级，少截断；宽随视口但不超过主舞台
    const wrapW = Math.min(200, Math.max(120, Math.floor((this._viewW || 640) * 0.36)));
    const arrowOn = !!(arrow && arrow.visible);
    const bubbleKey = `${text}|${wrapW}|${arrowOn ? 1 : 0}`;
    if (node.getData("bubbleKey") === bubbleKey && bg.visible) {
      return;
    }
    node.setData("bubbleKey", bubbleKey);
    tx.setStyle({ wordWrap: { width: wrapW } });
    tx.setText(text);
    const maxW = wrapW + 20;
    const w = Math.max(Math.min(tx.width + 18, maxW), 36);
    const h = Math.max(tx.height + 12, 20);
    bg.setSize(w, h);
    bg.setDisplaySize(w, h);
    const by = arrowOn ? -(h / 2 + 54) : -(h / 2 + 36);
    bg.setY(by);
    tx.setY(by);
    bg.setVisible(true);
    tx.setVisible(true);
  }

  _killActorTweens(node) {
    this.tweens.killTweensOf(node);
    const ring = node.getData("ring");
    const ringOuter = node.getData("ringOuter");
    const ringFill = node.getData("ringFill");
    const body = node.getData("body");
    const arrow = node.getData("arrow");
    const shadow = node.getData("shadow");
    if (ring) this.tweens.killTweensOf(ring);
    if (ringOuter) this.tweens.killTweensOf(ringOuter);
    if (ringFill) this.tweens.killTweensOf(ringFill);
    if (body) this.tweens.killTweensOf(body);
    if (arrow) this.tweens.killTweensOf(arrow);
    if (shadow) this.tweens.killTweensOf(shadow);
  }

  _paintSelected(node, selected) {
    const want = !!selected;
    const prev = !!node.getData("selected");
    // 选中态未变：不杀/重启脉动 tween；仅校正呼吸幅度
    if (prev === want) {
      if (!node.getData("walking")) this._syncBreath(node, true);
      return;
    }
    node.setData("selected", want);
    const ring = node.getData("ring");
    const ringOuter = node.getData("ringOuter");
    const ringFill = node.getData("ringFill");
    const arrow = node.getData("arrow");
    const name = node.getData("labelText");
    if (want) {
      if (ringFill) {
        ringFill.setVisible(true);
        ringFill.setFillStyle(0xffe066, 0.28);
        ringFill.setScale(1);
        ringFill.setAlpha(1);
        this.tweens.killTweensOf(ringFill);
        this.tweens.add({
          targets: ringFill,
          scaleX: 1.18,
          scaleY: 1.18,
          alpha: 0.12,
          duration: 640,
          yoyo: true,
          repeat: -1,
          ease: "Sine.easeInOut",
        });
      }
      if (ring) {
        ring.setVisible(true);
        ring.setStrokeStyle(3.5, 0xffe066, 1);
        ring.setScale(1);
        ring.setAlpha(1);
        this.tweens.killTweensOf(ring);
        this.tweens.add({
          targets: ring,
          scaleX: 1.28,
          scaleY: 1.28,
          duration: 480,
          yoyo: true,
          repeat: -1,
          ease: "Sine.easeInOut",
        });
      }
      if (ringOuter) {
        ringOuter.setVisible(true);
        ringOuter.setStrokeStyle(2.5, 0xfffdf8, 0.7);
        ringOuter.setScale(1.08);
        ringOuter.setAlpha(0.9);
        this.tweens.killTweensOf(ringOuter);
        this.tweens.add({
          targets: ringOuter,
          scaleX: 1.45,
          scaleY: 1.45,
          alpha: 0.2,
          duration: 660,
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
          y: -60,
          duration: 380,
          yoyo: true,
          repeat: -1,
          ease: "Sine.easeInOut",
        });
      }
      if (name && name.setColor) {
        name.setColor("#1c1a17");
        name.setBackgroundColor("#ffe066dd");
      }
      if (Math.abs(node.scaleX - 1.12) > 0.02) {
        this.tweens.add({
          targets: node,
          scaleX: 1.12,
          scaleY: 1.12,
          duration: 120,
        });
      }
      if (!node.getData("walking")) this._syncBreath(node, true);
    } else {
      if (ringFill) {
        this.tweens.killTweensOf(ringFill);
        ringFill.setVisible(false);
        ringFill.setFillStyle(0xffe066, 0);
        ringFill.setScale(1);
        ringFill.setAlpha(1);
      }
      if (ring) {
        this.tweens.killTweensOf(ring);
        ring.setVisible(false);
        ring.setStrokeStyle(2, 0xffe066, 0);
        ring.setScale(1);
        ring.setAlpha(1);
      }
      if (ringOuter) {
        this.tweens.killTweensOf(ringOuter);
        ringOuter.setVisible(false);
        ringOuter.setScale(1);
        ringOuter.setAlpha(1);
      }
      if (arrow) {
        this.tweens.killTweensOf(arrow);
        arrow.setVisible(false);
        arrow.y = -52;
      }
      if (name && name.setBackgroundColor) {
        name.setColor("#1c1a17");
        name.setBackgroundColor("#fffdf8dd");
      }
      if (Math.abs(node.scaleX - 1) > 0.02) {
        this.tweens.add({
          targets: node,
          scaleX: 1,
          scaleY: 1,
          duration: 110,
        });
      }
      if (!node.getData("walking")) this._syncBreath(node, true);
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
