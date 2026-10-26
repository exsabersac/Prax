# web/hs — Session JSON-lines 桥（M2）

Day-1 **契约 = JSON-lines**（stdin 一行请求 → stdout 一行响应），真源是
`Prax.Session` 的 ToJSON，对齐 `examples/my-town-session.json`。
本地 HTTP（若日后接 `web/serve.py`）只是便利壳，**不是**门禁。

## 构建

```sh
stack build prax:exe:prax-web-session
# 二进制一般在 $(stack path --local-install-root)/bin/prax-web-session
```

## 协议

每行一个 JSON。成功带 `"ok": true`；失败 `"ok": false, "error": …, "message": …`。
无会话时 `view` / `menu` / `act` / `wait` / `save` → `error: "no_session"`。

| op | 请求字段 | 成功响应要点 |
|----|----------|--------------|
| `new` | `worldId?`（默认 `my-town`） | `worldId`, `playerId`, `view`, `menu` |
| `view` | — | `view`, `menu` |
| `menu` | — | `menu` |
| `act` | `actionId`（`ga:v1:…`） | `narrative`, `view`, `menu` |
| `wait` | — | 同 act |
| `save` | — | 扁平 `format`=`prax-state-v4`, `worldId`, `blob` |
| `load` | `raw`：整段 Save JSON 字符串（与 `save`/`praxSave` 一致） | 同 `new` |
| `quit` | — | `bye`; 随后进程退出 |

### 字段边界（v0.1.2）

- `view.actors[].here` = 地点 id 或 `null`（不是 boolean）
- View **无** `log` / `tick`；叙事只在 `act`/`wait` 的 `narrative`
- 菜单主键 `actionId`；`act` 只传 `actionId`，不靠 label
- Save = `{format:"prax-state-v4", worldId, blob}`

stdin/stdout 使用行缓冲，可与 `readline` / 管道对接。

## 冒烟示例

```sh
BIN=$(stack path --local-install-root)/bin/prax-web-session
printf '%s\n' '{"op":"new","worldId":"my-town"}' | "$BIN"
# → ok + view.actors 含 you/bob/carol/dana/eve/gale

# 交互式多步：new → menu → act → save → load → quit
```

## 非目标

- 不编 wasm / JSFFI（非 Day-1）
- 不把 practices / 信任叶写进本桥；只薄封 `Prax.Session`
