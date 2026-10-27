/**
 * U1 Boot：立刻进 TownScene（无资源预载）。
 */
export class BootScene extends Phaser.Scene {
  constructor() {
    super({ key: "Boot" });
  }

  create() {
    this.scene.start("Town");
  }
}
