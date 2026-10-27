/**
 * U1：挂载 Phaser 3 单场景；对外 sync(view) / setSelectHandler。
 */
import { BootScene } from "./BootScene.js";
import { TownScene, TOWN_SIZE } from "./TownScene.js";

let game = null;
/** @type {TownScene | null} */
let town = null;
/** @type {null | ((actorId: string) => void)} */
let selectHandler = null;
/** @type {object | null} */
let lastView = null;

function bindTown() {
  if (!game) return;
  const s = game.scene.getScene("Town");
  if (!s) return;
  town = /** @type {TownScene} */ (s);
  if (selectHandler) town.setSelectHandler(selectHandler);
  if (lastView) town.sync(lastView);
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

export function syncTown(view) {
  lastView = view;
  if (!town) bindTown();
  if (town) town.sync(view);
}

export function isMounted() {
  return !!game;
}
