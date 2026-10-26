# 我的小镇 · 近端部署（M5a）

单容器跑通可玩页：**`prax-web-session` + `web/www` + `web/serve.py`**。  
Session JSON-lines 契约（v0.1.2）**不动**；wasm 非本切片门禁。

## 二进制入口

与 `web/hs/README.md`、`serve.py` 一致：

```sh
stack build prax:exe:prax-web-session
# 产物：
$(stack path --local-install-root)/bin/prax-web-session
```

容器镜像在 build 阶段按上述命令编译，并把该二进制拷进 `/usr/local/bin/prax-web-session`（`PRAX_WEB_SESSION`）。

## 健康检查

- `GET /health` → `200` + `{"ok":true,"status":"ok"}` 表示**桥进程仍存活**
- **不会**调用 `new` / `praxNew` 探活，不改 Session 状态
- 无桥或进程已退出 → `503`

## 本地（非容器）

```sh
stack build prax:exe:prax-web-session
python3 web/serve.py          # 监听 0.0.0.0:$PORT（默认 8080）
curl -s http://127.0.0.1:8080/health
# 浏览器打开 http://127.0.0.1:8080/
```

环境变量：`PORT`（默认 8080）、`HOST`（默认 `0.0.0.0`）、`PRAX_WEB_SESSION`（可选，显式指定桥二进制）。

## Docker Compose

在 `web/` 目录：

```sh
docker compose up --build
# 映射 http://127.0.0.1:8080/
curl -s http://127.0.0.1:8080/health
```

或在仓库根：

```sh
docker build -f web/Dockerfile -t prax-my-town .
docker run --rm -p 8080:8080 prax-my-town
```

## 边界（勿破）

- 不扩 Session schema / View；菜单仍只传 opaque `actionId`
- HTTP 只是便利壳：`POST /api/session` → JSON-lines 桥
- 上线推荐本路径拿公网 URL；wasm 作后置零服务器候选
