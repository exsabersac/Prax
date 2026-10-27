/**
 * U4：挂载 Phaser 3（像素锐化 + 多地点地图）；对外 sync(view) / syncMenu / set*Handler。
 */
import { BootScene } from "./BootScene.js";
import { TownScene, TOWN_SIZE } from "./TownScene.js";

let game = null;
/** @type {TownScene | null} */
let town = null;
/** @type {null | ((actorId: string) => void)} */
let selectHandler = null;
/** @type {null | ((actionId: string) => void)} */
let actHandler = null;
/** @type {null | (() => void)} */
let waitHandler = null;
/** @type {object | null} */
let lastView = null;
/** @type {object | null | undefined} */
let lastMenu = undefined;

function bindTown() {
  if (!game) return;
  const s = game.scene.getScene("Town");
  if (!s) return;
  town = /** @type {TownScene} */ (s);
  if (selectHandler) town.setSelectHandler(selectHandler);
  if (actHandler) town.setActHandler(actHandler);
  if (waitHandler) town.setWaitHandler(waitHandler);
  if (lastView) town.sync(lastView);
  if (lastMenu !== undefined) town.syncMenu(lastMenu);
}

export function mountPhaser(parentEl) {
  if (typeof Phaser === "undefined") {
    throw new Error("Phaser 未加载（需要 vendor/phaser.min.js）");
  }
  if (game) return game;

  parentEl.replaceChildren();
  const host = document.createElement("div");
  host.id = "phaser-host";
  host.className = "phaser-host";
  parentEl.appendChild(host);

  game = new Phaser.Game({
    type: Phaser.AUTO,
    parent: host,
    width: TOWN_SIZE.width,
    height: TOWN_SIZE.height,
    backgroundColor: "#2a2a28",
    scene: [BootScene, TownScene],
    // U4-01：pixelArt + roundPixels，缓解 FIT 发虚
    render: {
      pixelArt: true,
      antialias: false,
      roundPixels: true,
    },
    scale: {
      mode: Phaser.Scale.FIT,
      autoCenter: Phaser.Scale.CENTER_BOTH,
      width: TOWN_SIZE.width,
      height: TOWN_SIZE.height,
    },
    banner: false,
  });

  game.events.on("ready", bindTown);
  setTimeout(bindTown, 0);
  setTimeout(bindTown, 50);
  setTimeout(bindTown, 200);

  if (typeof window !== "undefined") window.__praxPhaser = game;
  return game;
}

export function setSelectHandler(fn) {
  selectHandler = fn;
  if (town) town.setSelectHandler(fn);
}

export function setActHandler(fn) {
  actHandler = fn;
  if (town) town.setActHandler(fn);
}

export function setWaitHandler(fn) {
  waitHandler = fn;
  if (town) town.setWaitHandler(fn);
}

export function syncTown(view) {
  lastView = view;
  if (!town) bindTown();
  if (town) town.sync(view);
}

export function syncMenu(menu) {
  lastMenu = menu;
  if (!town) bindTown();
  if (town) town.syncMenu(menu);
}

/** View + Menu 一次推入（U3/U4 主 paint 路径） */
export function syncHud(view, menu) {
  lastView = view;
  lastMenu = menu;
  if (!town) bindTown();
  if (town) {
    town.sync(view);
    town.syncMenu(menu);
  }
}

export function isMounted() {
  return !!game;
}
