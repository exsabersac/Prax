/**
 * U1 TownScene：单地点俯视 + 同场可点精灵；点选回调到主壳 praxMenu。
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

export class TownScene extends Phaser.Scene {
  constructor() {
    super({ key: "Town" });
    /** @type {null | ((actorId: string) => void)} */
    this._onSelect = null;
    /** @type {Map<string, Phaser.GameObjects.Container>} */
    this._sprites = new Map();
    this._floor = null;
    this._border = null;
    this._placeLabel = null;
    this._hint = null;
    this._placeId = null;
  }

  setSelectHandler(fn) {
    this._onSelect = fn;
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

    this._hint = this.add
      .text(16, H - 28, "点选同场居民 → 右侧菜单", {
        fontFamily: "PingFang SC, Noto Sans SC, sans-serif",
        fontSize: "12px",
        color: "#fffdf8cc",
      })
      .setDepth(10);

    if (this._pendingView) {
      this.sync(this._pendingView);
      this._pendingView = null;
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
