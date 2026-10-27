/**
 * U1–U4 Boot：立刻进 TownScene（人物纹理运行时程序化生成）。
 */
export class BootScene extends Phaser.Scene {
  constructor() {
    super({ key: "Boot" });
  }

  create() {
    this.scene.start("Town");
  }
}
