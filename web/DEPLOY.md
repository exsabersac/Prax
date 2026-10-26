# 我的小镇 · 近端部署（M5a / M5f F01）

单容器跑通可玩页：**`prax-web-session` + `web/www` + `web/serve.py`**。  
Session JSON-lines 契约（v0.1.2）**不动**；wasm 非本切片门禁。

## 二进制入口

与 `web/hs/README.md`、`serve.py` 一致：

```sh
stack build prax:exe:prax-web-session
# 产物：
$(stack path --local-install-root)/bin/prax-web-session
```

**默认镜像（方案② / F01）不在 Docker 内跑 stack**：宿主编好后拷到 `web/bin/prax-web-session`，由 `web/Dockerfile.runtime` COPY 进 `/usr/local/bin/prax-web-session`（`PRAX_WEB_SESSION`）。  
全量容器内 stack 见 `web/Dockerfile`（后置可选，易遇 Stackage 超时）。

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

## Docker Compose（F01 默认 · 必须三步）

**禁止只写一句 `docker compose up`。** 在仓库根按顺序：

```sh
# 1) 宿主编译
stack build prax:exe:prax-web-session

# 2) 拷进 compose 构建上下文
mkdir -p web/bin
cp "$(stack path --local-install-root)/bin/prax-web-session" web/bin/prax-web-session

# 3) 起容器（默认 Dockerfile.runtime，不再拉 Stackage）
cd web && docker compose up --build
```

探活与打开：

```sh
curl -s http://127.0.0.1:8080/health
# 浏览器：http://127.0.0.1:8080/
```

停：`cd web && docker compose down`。

等价手搓（同三步前置）：

```sh
# 完成 1)+2) 后：
docker build -f web/Dockerfile.runtime -t prax-my-town .
docker run --rm -p 8080:8080 prax-my-town
```

后置可选（容器内 stack，非 F01 门禁）：`docker build -f web/Dockerfile -t prax-my-town:full .`

## 可分享（M5e）

外人只按本文档起**近端桥**即可进主路径；验收用固定可复制 URL，**不硬卡公网/域名**。  
Session / SaveMeta **不动**；不新增 share API。

**固定可复制开局地址（复制这段）：**

```
http://127.0.0.1:8080/
```

形如 `http://127.0.0.1:${PORT:-8080}/`（默认 **8080**，与 `docker-compose` 的 `${PORT:-8080}:8080`、容器内 `PORT=8080`、`serve.py` 一致）。改主机侧 `PORT` 时，改 URL 端口即可。

1. **前置**：Docker + 本机 `stack`（默认路径需宿主编二进制）；或本机 `stack` + `python3`（非容器）
2. **起桥（三步，勿省略）**：`stack build prax:exe:prax-web-session` → `mkdir -p web/bin && cp "$(stack path --local-install-root)/bin/prax-web-session" web/bin/` → `cd web && docker compose up --build`
3. **复制打开**：浏览器粘贴 `http://127.0.0.1:8080/`（非 `file://`）
4. **探活**：`curl -s http://127.0.0.1:8080/health` → **200**（只探桥存活；**勿用** `new` / `praxNew`）
5. **可玩**：真浏览器冷开 ≤30s 出 Menu（对齐已签 M5a/b）
6. **停**：在 `web/` 下 `docker compose down`
7. **可选公网**（非门禁）：自备隧道/反代映射到同一主机端口，路径仍为 `/`

## 外人可玩最短路径（M5f）

在上文「可分享」起桥并打开固定 URL 之后，按下列点法走通主路径中的 **3b**（公开帮助 **carol** → bob 亲见+自转告 → dana 怀疑）。  
Session / SaveMeta / serve **零改**（compose 默认 Dockerfile.runtime，见上）；只按菜单点，**不要**点「怀疑地打量」（怀疑者是 dana，由引擎在 narrative 里给出）。

1. **起桥**：同「可分享」三步 — build → cp → `compose up --build`；探活 `curl -s http://127.0.0.1:8080/health` → 200
2. **打开**：浏览器粘贴 `http://127.0.0.1:8080/`（非 `file://`）；冷开出 Menu 后点 **新开一局**（或已在局中则直接用菜单）
3. **主路径 · 3b（最短可玩）**
   1. 菜单点 **`you: 公开帮助 carol`**（受益人 carol；bob 共场亲见）
   2. 点 **稍候（praxWait）** — 推进 NPC；bob 会自行前往 mill 并向 dana 转告
   3. 菜单点 **`you: 前往 mill`**
   4. 再点 **稍候（praxWait）** — 可感知 = 对话/叙事区出现 Act.narrative 行 **`dana: 怀疑地打量 you`**

玩家只点：帮忙 / 前往 / 稍候。bob 转告与 dana 怀疑均由引擎推进，**勿**在菜单里找或点「怀疑」。

## 边界（勿破）

- 不扩 Session schema / View；菜单仍只传 opaque `actionId`
- HTTP 只是便利壳：`POST /api/session` → JSON-lines 桥
- 上线推荐本路径拿公网 URL；wasm 作后置零服务器候选
