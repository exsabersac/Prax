# 我的小镇 · 网页壳（MVP）

对齐 Mach/match3 分层目标，但 **Day-1 不以 wasm 为门禁**。

## 结构

```
web/
├── README.md
├── serve.py          # 静态服；默认根目录 www/
├── hs/               # 预留：日后 PraxWeb/Api + WebMain（JSFFI）
└── www/              # 原生 JS 薄壳（无重框架）
    ├── index.html
    ├── styles.css
    ├── main.js       # 接线：选人 → 菜单 → 行动 → 重绘
    ├── api.js        # 会话客户端；MVP 走假数据，日后换 JSON 桥 / wasm
    ├── scene.js
    ├── menu.js
    └── dialogue.js
```

## 会话契约（架构 v0.1 + 补丁）

- `praxNew("my-town")` → `{ok,sessionId,worldId,playerId,view}`
- `praxMenu(actorId)` → `{ok,actorId,actions[{id,label,kind,practiceId,actionId}]}`；`id` 为不透明 `ga:v1` canonical
- `praxAct(actionId)` → 整玩家回合（含 NPC 推进）`{ok,accepted,narrative[],delta,view,menu}`
- `praxSave` / `praxLoad`：M2
- 错误：`{ok:false,error,message}`
- UI 以返回的引擎快照为唯一真源；菜单只传 `action.id`，不传 label

## 本地预览

```sh
python3 web/serve.py          # http://127.0.0.1:8080
python3 web/serve.py --port 9000
```

## 非目标（本骨架）

- 不编 wasm、不写 WebMain
- 不把 practices / 信任叶逻辑写进 JS
- 不提交 `dist/`（日后全量重建）
