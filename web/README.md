# 我的小镇 · 网页壳（MVP）

对齐 Mach/match3 分层；**Day-1 不以 wasm 为门禁**。

## M2 传输契约（v0.1.2）

**真源 = JSON-lines**（可执行文件 `prax-web-session`）：stdin 一行 JSON 请求 → stdout 一行 JSON 响应，
字段对齐 `Prax.Session` ToJSON 与 `examples/my-town-session.json`。

本地 `POST /api/session`（`serve.py`）只是前端便利壳，**不是**门禁 / 不是 Day-1 契约。
协议细节与 op 表见 `web/hs/README.md`。

```sh
stack build prax:exe:prax-web-session
BIN=$(stack path --local-install-root)/bin/prax-web-session
printf '%s\n' '{"op":"new","worldId":"my-town"}' | "$BIN"
```

## 结构

```
web/
├── README.md
├── serve.py              # 静态 www/；可选 POST /api/session 透传 JSON-lines（便利壳）
├── hs/
│   ├── SessionMain.hs    # JSON-lines Session 桥（契约入口）
│   └── README.md         # op / 字段边界
└── www/                  # 原生 JS 薄壳
```

样例 JSON（Haskell 侧）：`examples/my-town-session.json`

M2 验收锚：同文件；门禁重点 J03（同种子 actionId 集合）与 J05（Save/Load）。

## 本地预览（可选 HTTP 壳）

```sh
stack build prax:exe:prax-web-session
python3 web/serve.py          # http://127.0.0.1:8080
```

## 字段边界

以 `Prax.Session` ToJSON 为准：

- `actors[].here` = 地点 id 或 `null`（不是 boolean）
- View **无** `log` / `tick`；叙事在 `act`/`wait` 的 `narrative`
- 菜单主键 `actionId`（`ga:v1:…`）；`act` 只传 `actionId`
- Save = `{format:"prax-state-v4", worldId, blob}`

## 后置

wasm / WebMain / `build.sh → dist`
