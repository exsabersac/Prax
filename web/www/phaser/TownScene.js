/**
 * U2 TownScene：单地点俯视 + 同场可点精灵；
 * Menu / 叙事·tick 叠层在 canvas 内（主路径不再依赖 DOM 三栏）。
 */
import {
  accentColor,
  actorFill,
  floorColor,
  slotFor,
} from "./actors.js";

const W = 640;
const H = 360;
const R = 22;

const MENU_X = 430;
const MENU_Y = 36;
const MENU_W = 198;
const LOG_X = 12;
const LOG_Y = 268;
const LOG_W = 406;
const LOG_H = 80;

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
    this._placeLabel = null;
    this._tickLabel = null;
    this._hint = null;
    this._placeId = null;
    this._menuRoot = null;
    this._logRoot = null;
    /** @type {object | null} */
    this._pendingView = null;
    /** @type {object | null} */
    this._pendingMenu = null;
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
    this._floor = this.add.rectangle(W / 2, H / 2, W - 16, H - 16, floorColor("square"));
    this._border = this.add.rectangle(W / 2, H / 2, W - 16, H - 16);
    this._border.setStrokeStyle(3, accentColor("square"), 1);
    this._border.setFillStyle();

    this._placeLabel = this.add
      .text(16, 10, "", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "16px",
        color: "#fffdf8",
        backgroundColor: "#00000066",
        padding: { x: 8, y: 4 },
      })
      .setDepth(10);

    this._tickLabel = this.add
      .text(W / 2, 10, "", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "13px",
        color: "#fffdf8",
        backgroundColor: "#00000055",
        padding: { x: 6, y: 3 },
      })
      .setOrigin(0.5, 0)
      .setDepth(10);

    this._hint = this.add
      .text(16, H - 18, "点选同场居民 → 地图内菜单 → Act", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "11px",
        color: "#fffdf8aa",
      })
      .setDepth(10)
      .setOrigin(0, 1);

    this._menuRoot = this.add.container(MENU_X, MENU_Y).setDepth(30);
    this._logRoot = this.add.container(LOG_X, LOG_Y).setDepth(30);

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
    }
    this._placeLabel.setText(view.locationLabel || placeId);
    const tick = view.tick != null ? String(view.tick) : "?";
    const player = view.playerId || "you";
    this._tickLabel.setText(`回合 ${tick} · ${player}`);

    const here = (view.actors || []).filter((a) => a.atPlayerLoc);
    const keep = new Set(here.map((a) => a.id));

    for (const [id, node] of this._sprites) {
      if (!keep.has(id)) {
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
      } else {
        node.setPosition(x, y);
        const label = node.getData("labelText");
        if (label && label.text !== (a.label || a.id)) {
          label.setText(a.label || a.id);
        }
      }
      this._paintSelected(node, a.id === view.selectedActorId);
    });

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
    this._menuRoot.removeAll(true);

    const bg = this.add
      .rectangle(0, 0, MENU_W, 8, 0x1c1a17, 0.82)
      .setOrigin(0, 0);
    this._menuRoot.add(bg);

    const title = this.add
      .text(10, 8, "菜单", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "13px",
        color: "#d9d2c4",
      })
      .setOrigin(0, 0);
    this._menuRoot.add(title);

    let y = 28;
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
        const btnH = 36;
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
        y += btnH + 6;
      }
    }

    const wait = this._makeMenuButton(
      8,
      y,
      MENU_W - 16,
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

    bg.setSize(MENU_W, Math.max(y + 8, 72));
    // Phaser rectangle setSize may need display size update
    bg.width = MENU_W;
    bg.height = Math.max(y + 8, 72);
    bg.setDisplaySize(MENU_W, Math.max(y + 8, 72));
  }

  /**
   * @param {object} view
   */
  syncLog(view) {
    if (!this._logRoot) return;
    this._logRoot.removeAll(true);

    const bg = this.add
      .rectangle(0, 0, LOG_W, LOG_H, 0x1c1a17, 0.78)
      .setOrigin(0, 0);
    this._logRoot.add(bg);

    const title = this.add
      .text(8, 4, "对话与回合反馈", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "11px",
        color: "#d9d2c4",
      })
      .setOrigin(0, 0);
    this._logRoot.add(title);

    const lines = (view && view.log) || [];
    if (!lines.length) {
      const empty = this.add
        .text(8, 22, "还没有发生的事。", {
          fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
          fontSize: "12px",
          color: "#fffdf8aa",
        })
        .setOrigin(0, 0);
      this._logRoot.add(empty);
      return;
    }

    // 只展示末尾若干行，保证可见
    const tail = lines.slice(-3);
    let y = 20;
    for (const line of tail) {
      const kind = line.kind || "system";
      const color =
        kind === "narrative" ? "#c8e6d0" : kind === "system" ? "#e6dfc8" : "#fffdf8";
      const t = this.add
        .text(8, y, line.text || "", {
          fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
          fontSize: "11px",
          color,
          wordWrap: { width: LOG_W - 16 },
        })
        .setOrigin(0, 0);
      this._logRoot.add(t);
      y += Math.min(t.height + 4, 22);
      if (y > LOG_H - 8) break;
    }
  }

  _makeMenuButton(x, y, w, h, label, sub, onClick, fill = 0x2f6f4e) {
    const g = this.add.container(x, y);
    const bg = this.add.rectangle(0, 0, w, h, fill, 0.95).setOrigin(0, 0);
    bg.setStrokeStyle(1, 0xd9d2c4, 0.7);
    bg.setInteractive({ useHandCursor: true });
    bg.on("pointerover", () => bg.setFillStyle(fill, 1));
    bg.on("pointerout", () => bg.setFillStyle(fill, 0.95));
    bg.on("pointerdown", (pointer, _lx, _ly, event) => {
      if (event && event.stopPropagation) event.stopPropagation();
      onClick();
    });
    const title = this.add
      .text(8, sub ? 4 : h / 2, label, {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "12px",
        color: "#fffdf8",
        wordWrap: { width: w - 16 },
      })
      .setOrigin(0, sub ? 0 : 0.5);
    g.add(bg);
    g.add(title);
    if (sub) {
      const kind = this.add
        .text(8, 18, sub, {
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
    const body = this.add.circle(0, 0, R, fill);
    body.setStrokeStyle(2, 0xffffff, 0.85);
    const text = this.add
      .text(0, R + 10, label, {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "12px",
        color: "#1c1a17",
        backgroundColor: "#fffdf8cc",
        padding: { x: 4, y: 2 },
      })
      .setOrigin(0.5, 0);

    const hit = this.add.circle(0, 0, R + 8, 0xffffff, 0.001);
    hit.setInteractive({ useHandCursor: true });
    hit.on("pointerdown", () => {
      if (this._onSelect) this._onSelect(id);
    });

    const node = this.add.container(x, y, [body, text, hit]);
    node.setSize((R + 8) * 2, (R + 8) * 2);
    node.setData("body", body);
    node.setData("labelText", text);
    node.setData("actorId", id);
    node.setDepth(5);
    return node;
  }

  _paintSelected(node, selected) {
    const body = node.getData("body");
    if (!body) return;
    if (selected) {
      body.setStrokeStyle(4, 0xffe066, 1);
      node.setScale(1.08);
    } else {
      body.setStrokeStyle(2, 0xffffff, 0.85);
      node.setScale(1);
    }
  }
}

export const TOWN_SIZE = { width: W, height: H };
