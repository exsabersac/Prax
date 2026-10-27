/**
 * U1–U10 Boot：人物纹理运行时程序化生成。
 * U11：预载 Blender 烘图集（you），再进 TownScene。
 */
import { FRAME_W, FRAME_H } from "./sprites.js";

export class BootScene extends Phaser.Scene {
  constructor() {
    super({ key: "Boot" });
  }

  preload() {
    // U11：自研 Blender 图集；路径相对 www/
    this.load.spritesheet("u11-actor-you-sheet", "phaser/assets/u11/you-sheet.png", {
      frameWidth: FRAME_W,
      frameHeight: FRAME_H,
    });
  }

  create() {
    if (this.textures.exists("u11-actor-you-sheet")) {
      this.textures
        .get("u11-actor-you-sheet")
        .setFilter(Phaser.Textures.FilterMode.NEAREST);
    }
    this.scene.start("Town");
  }
}
