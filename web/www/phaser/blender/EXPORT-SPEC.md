# U11 导出规格 · Blender 烘像素 → Phaser3

**日期**：2026-10-27（Asia/Shanghai）  
**角色**：`you`（玩家「你」）最小切片；其余角色仍用 U9 几何精灵回退。  
**引擎**：继续 Phaser3；不 glTF 实时；禁商用素材。

## 管道

1. `bake_you_sheet.py`：Blender 4.2 后台简模（盒体低模 + EEVEE 正交 + 透明底）→ `_frames/{mode}_{face}_{i}.png`（64×96）
2. `pack_sheet.py`：nearest 缩到 32×48，拼 `assets/u11/you-sheet.png`（128×288）
3. Phaser `BootScene` 预载 spritesheet；`sprites.js` 对 `you` 走烘图，其它 id 仍 `u9-actor-*` 几何

重烘（本机需 Blender）：

```bash
export U11_OUT=/path/to/web/www/phaser/assets/u11
blender --background --python web/www/phaser/blender/bake_you_sheet.py
python3 web/www/phaser/blender/pack_sheet.py
```

## 图集约定

| 项 | 值 |
|----|-----|
| 逻辑帧 | 32×48（与 U9 `FRAME_W/H` 一致） |
| 列 × 行 | 4 × 6 |
| 行 0–2 | idle：down / side / up |
| 行 3–5 | walk：down / side / up |
| 列 0–3 | 动画帧 0–3 |
| 透明底 | RGBA，无底色 |
| 过滤 | Phaser `pixelArt` + `NEAREST` |
| 朝向 | side 面向屏幕右侧；左向用 `flipX`（同 U9） |
| 站位 | 与 U9 同帧尺寸、`SPRITE_SCALE=1`，影子/头顶标签不改 |

帧文件命名（中间产物）：`{idle\|walk}_{down\|side\|up}_{0-3}.png`

## 自研声明

造型与动画均为仓库内 Blender Python 程序化建模/姿态，**非** GA / CuteRPG / 其它商用素材。
