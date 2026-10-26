# 我的小镇 · 网页壳（MVP）

对齐 Mach/match3 分层；**Day-1 不以 wasm 为门禁**。当前用 JSON-lines 桥接真 `Prax.Session`。

## 结构

```
web/
├── README.md
├── serve.py              # 静态 www/ + POST /api/session → prax-web-session
├── hs/SessionMain.hs     # JSON-lines Session 桥
└── www/                  # 原生 JS 薄壳
```

样例 JSON（Haskell 侧）：`examples/my-town-session.json`

M2 验收锚：同文件；门禁重点 J03（同种子 actionId 集合）与 J05（Save/Load，SaveMeta 进 localStorage，刷新 praxLoad）。

## 本地预览

```sh
stack build prax:exe:prax-web-session
python3 web/serve.py          # http://127.0.0.1:8080
```

## 字段

以 `Prax.Session` ToJSON 为准：`actors[].here` 为地点 id；菜单用 `actionId`（ga:v1）；`praxAct` 整玩家回合。前端只做展示规范化。

## 后置

wasm / WebMain / `build.sh → dist`

## 部署（M5a）

见 [DEPLOY.md](./DEPLOY.md)：Docker / `/health` / `0.0.0.0:$PORT`。
