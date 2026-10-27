/**
 * U3 TownScene：单地点俯视 + 同场可点精灵；
 * Menu / 叙事·tick 叠层在 canvas 内。
 * U3：点选反馈、HUD 过渡动效、场景层次与 idle 动画。
 */
import {
  accentColor,
  actorFill,
  floorColor,
  pathColor,
  skyColor,
  slotFor,
} from "./actors.js";

const W = 640;
const H = 360;
const R = 24;

const MENU_X = 430;
const MENU_Y = 36;
const MENU_W = 198;
const LOG_X = 12;
const LOG_Y = 258;
const LOG_W = 406;
const LOG_H = 90;

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
    this._floor = null;
    this._border = null;
    this._sky = null;
    this._path = null;
    this._decor = null;
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

    // U3-03：背景层次 — 天条 / 地面 / 小径 / 边框
    this._sky = this.add
      .rectangle(W / 2, 28, W - 16, 48, skyColor("square"))
      .setDepth(0);
    this._floor = this.add
      .rectangle(W / 2, H / 2 + 8, W - 16, H - 40, floorColor("square"))
      .setDepth(1);
    this._path = this.add
      .ellipse(W / 2 - 20, H / 2 + 30, 280, 90, pathColor("square"), 0.55)
      .setDepth(2);
    this._border = this.add.rectangle(W / 2, H / 2, W - 16, H - 16);
    this._border.setStrokeStyle(3, accentColor("square"), 1);
    this._border.setFillStyle();
    this._border.setDepth(3);

    this._decor = this.add.container(0, 0).setDepth(2);
    this._paintDecor("square");

    this._placeLabel = this.add
      .text(16, 10, "", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "16px",
        color: "#fffdf8",
        backgroundColor: "#00000088",
        padding: { x: 8, y: 4 },
      })
      .setDepth(10);

    this._tickLabel = this.add
      .text(W / 2, 10, "", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "13px",
        color: "#fffdf8",
        backgroundColor: "#00000077",
        padding: { x: 8, y: 4 },
      })
      .setOrigin(0.5, 0)
      .setDepth(10);

    this._hint = this.add
      .text(16, H - 8, "点选同场居民 → 地图内菜单 → Act", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "11px",
        color: "#fffdf8bb",
      })
      .setDepth(10)
      .setOrigin(0, 1);

    this._menuRoot = this.add.container(MENU_X, MENU_Y).setDepth(30).setAlpha(0);
    this._logRoot = this.add.container(LOG_X, LOG_Y).setDepth(30).setAlpha(0);

    if (this._pendingView) {
      this.sync(this._pendingView);
      this._pendingView = null;
    }
    if (this._pendingMenu !== undefined) {
      this.syncMenu(this._pendingMenu);
      this._pendingMenu = undefined;
    }
  }

  /**
   * U3-03：极简场景装饰（广场喷泉环 / 磨坊粮袋），无正式美术。
   * @param {string} placeId
   */
  _paintDecor(placeId) {
    if (!this._decor) return;
    this._decor.removeAll(true);
    if (placeId === "mill") {
      const sack = this.add.ellipse(520, 210, 48, 32, 0x8a6d48, 0.85);
      const sack2 = this.add.ellipse(545, 225, 36, 24, 0x7a5f3c, 0.8);
      const post = this.add.rectangle(70, 200, 14, 70, 0x5c4030, 0.9);
      this._decor.add([sack, sack2, post]);
    } else {
      const ring = this.add.circle(200, 175, 38, 0x000000, 0);
      ring.setStrokeStyle(3, 0xd9d2c4, 0.45);
      const center = this.add.circle(200, 175, 10, 0xa8c4d8, 0.7);
      const bushL = this.add.ellipse(55, 240, 40, 22, 0x4a6b3c, 0.75);
      const bushR = this.add.ellipse(360, 235, 44, 24, 0x4a6b3c, 0.7);
      this._decor.add([ring, center, bushL, bushR]);
    }
  }

  /**
   * @param {object} view normalizeView 结果
   */
  sync(view) {
    if (!view) return;
    if (!this._floor) {
      this._pendingView = view;
      return;
    }

    const placeId = view.locationId || "square";
    if (placeId !== this._placeId) {
      this._placeId = placeId;
      this._floor.setFillStyle(floorColor(placeId));
      this._border.setStrokeStyle(3, accentColor(placeId), 1);
      if (this._sky) this._sky.setFillStyle(skyColor(placeId));
      if (this._path) this._path.setFillStyle(pathColor(placeId), 0.55);
      this._paintDecor(placeId);
    }
    this._placeLabel.setText(view.locationLabel || placeId);
    const tick = view.tick != null ? String(view.tick) : "?";
    const player = view.playerId || "you";
    this._tickLabel.setText(`回合 ${tick} · ${player}`);

    // U3-02：回合变化时 tick 标签轻脉冲
    if (this._lastTick !== null && this._lastTick !== tick) {
      this.tweens.killTweensOf(this._tickLabel);
      this._tickLabel.setScale(1.15);
      this.tweens.add({
        targets: this._tickLabel,
        scaleX: 1,
        scaleY: 1,
        duration: 280,
        ease: "Back.easeOut",
      });
    }
    this._lastTick = tick;

    const here = (view.actors || []).filter((a) => a.atPlayerLoc);
    const keep = new Set(here.map((a) => a.id));

    for (const [id, node] of this._sprites) {
      if (!keep.has(id)) {
        this.tweens.killTweensOf(node);
        const ring = node.getData("ring");
        const body = node.getData("body");
        if (ring) this.tweens.killTweensOf(ring);
        if (body) this.tweens.killTweensOf(body);
        node.destroy();
        this._sprites.delete(id);
      }
    }

    here.forEach((a, i) => {
      const [x, y] = slotFor(placeId, a.id, i);
      let node = this._sprites.get(a.id);
      if (!node) {
        node = this._makeActor(a.id, a.label || a.id, x, y);
        this._sprites.set(a.id, node);
      } else if (Math.abs(node.x - x) > 0.5 || Math.abs(node.y - y) > 0.5) {
        node.setData("baseY", y);
        this.tweens.add({
          targets: node,
          x,
          y,
          duration: 220,
          ease: "Sine.easeInOut",
        });
      }
      const label = node.getData("labelText");
      if (label && label.text !== (a.label || a.id)) {
        label.setText(a.label || a.id);
      }
      this._paintSelected(node, a.id === view.selectedActorId);
    });

    this._selectedId = view.selectedActorId || null;
    this.syncLog(view);
  }

  /**
   * @param {null | { actorId?: string, actions?: Array<{id:string,label:string,kind?:string,practiceId?:string}> }} menu
   */
  syncMenu(menu) {
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

    // U3-02：菜单淡入 + 微下滑
    this._menuRoot.setAlpha(0);
    this._menuRoot.y = MENU_Y - 8;
    this.tweens.add({
      targets: this._menuRoot,
      alpha: 1,
      y: MENU_Y,
      duration: 200,
      ease: "Cubic.easeOut",
    });
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

    // U3-02：日志更新时淡入
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
    // U3-03：脚底阴影
    const shadow = this.add.ellipse(0, R + 2, R * 1.6, 10, 0x000000, 0.28);
    const body = this.add.circle(0, 0, R, fill);
    body.setStrokeStyle(2, 0xffffff, 0.9);
    // U3-01：选中环（默认隐藏）
    const ring = this.add.circle(0, 0, R + 7, 0x000000, 0);
    ring.setStrokeStyle(3, 0xffe066, 0);
    ring.setVisible(false);

    const text = this.add
      .text(0, R + 12, label, {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "12px",
        color: "#1c1a17",
        backgroundColor: "#fffdf8dd",
        padding: { x: 5, y: 2 },
      })
      .setOrigin(0.5, 0);

    const hit = this.add.circle(0, 0, R + 10, 0xffffff, 0.001);
    hit.setInteractive({ useHandCursor: true });

    const node = this.add.container(x, y, [shadow, ring, body, text, hit]);
    node.setSize((R + 10) * 2, (R + 10) * 2);
    node.setData("body", body);
    node.setData("ring", ring);
    node.setData("labelText", text);
    node.setData("actorId", id);
    node.setData("baseY", y);
    node.setDepth(5);

    hit.on("pointerover", () => {
      if (id === this._selectedId) return;
      body.setStrokeStyle(3, 0xffffff, 1);
      this.tweens.add({
        targets: node,
        scaleX: 1.06,
        scaleY: 1.06,
        duration: 100,
      });
    });
    hit.on("pointerout", () => {
      if (id === this._selectedId) return;
      body.setStrokeStyle(2, 0xffffff, 0.9);
      this.tweens.add({
        targets: node,
        scaleX: 1,
        scaleY: 1,
        duration: 100,
      });
    });
    hit.on("pointerdown", () => {
      // U3-01：点击瞬时反馈
      this.tweens.add({
        targets: node,
        scaleX: 0.92,
        scaleY: 0.92,
        duration: 70,
        yoyo: true,
        ease: "Quad.easeOut",
      });
      ring.setVisible(true);
      ring.setStrokeStyle(3, 0xffe066, 1);
      ring.setScale(1);
      ring.setAlpha(1);
      this.tweens.add({
        targets: ring,
        scaleX: 1.35,
        scaleY: 1.35,
        alpha: 0,
        duration: 280,
        onComplete: () => {
          ring.setScale(1);
          ring.setAlpha(1);
          if (id !== this._selectedId) {
            ring.setVisible(false);
            ring.setStrokeStyle(3, 0xffe066, 0);
          }
        },
      });
      if (this._onSelect) this._onSelect(id);
    });

    // U3-03：轻微 idle —— 只动 body/shadow，不抢容器站位
    const phase = (id.charCodeAt(0) % 7) * 80;
    this.tweens.add({
      targets: [body, shadow],
      y: "-=3",
      duration: 900 + phase,
      yoyo: true,
      repeat: -1,
      ease: "Sine.easeInOut",
      delay: phase,
    });

    return node;
  }

  _paintSelected(node, selected) {
    const body = node.getData("body");
    const ring = node.getData("ring");
    if (!body) return;
    if (selected) {
      body.setStrokeStyle(4, 0xffe066, 1);
      if (ring) {
        ring.setVisible(true);
        ring.setStrokeStyle(2, 0xffe066, 0.85);
        ring.setScale(1);
        ring.setAlpha(1);
        this.tweens.killTweensOf(ring);
        // U3-01：选中环脉冲
        this.tweens.add({
          targets: ring,
          scaleX: 1.18,
          scaleY: 1.18,
          duration: 520,
          yoyo: true,
          repeat: -1,
          ease: "Sine.easeInOut",
        });
      }
      if (Math.abs(node.scaleX - 1.1) > 0.02) {
        this.tweens.add({
          targets: node,
          scaleX: 1.1,
          scaleY: 1.1,
          duration: 120,
        });
      }
    } else {
      body.setStrokeStyle(2, 0xffffff, 0.9);
      if (ring) {
        this.tweens.killTweensOf(ring);
        ring.setVisible(false);
        ring.setStrokeStyle(3, 0xffe066, 0);
        ring.setScale(1);
        ring.setAlpha(1);
      }
      if (Math.abs(node.scaleX - 1) > 0.02) {
        this.tweens.add({
          targets: node,
          scaleX: 1,
          scaleY: 1,
          duration: 120,
        });
      }
    }
  }
}

export const TOWN_SIZE = { width: W, height: H };
