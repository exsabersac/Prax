# 我的小镇 · 全量容器内 stack 构建（后置可选）
# 默认请用 web/Dockerfile.runtime（宿主 stack build → COPY web/bin/prax-web-session）。
# 本文件在 Docker 内拉 Stackage，易超时；仅在需要纯容器复现时使用：
#   docker build -f web/Dockerfile -t prax-my-town:full .
# Session / JSON-lines 桥协议不动；构建上下文为仓库根目录。
#
# 二进制入口（与 web/hs/README、serve.py 一致）：
#   stack build prax:exe:prax-web-session
#   → $(stack path --local-install-root)/bin/prax-web-session

FROM fpco/stack-build:lts-21.25 AS build
WORKDIR /src
COPY . .
RUN mkdir -p /out \
 && stack build prax:exe:prax-web-session \
 && BIN="$(stack path --local-install-root)/bin/prax-web-session" \
 && cp "$BIN" /out/prax-web-session \
 && chmod +x /out/prax-web-session

FROM python:3.12-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends libgmp10 libtinfo6 ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /out/prax-web-session /usr/local/bin/prax-web-session
COPY web/www /app/www
COPY web/serve.py /app/serve.py
ENV PRAX_WEB_SESSION=/usr/local/bin/prax-web-session \
    HOST=0.0.0.0 \
    PORT=8080
EXPOSE 8080
CMD ["python3", "/app/serve.py"]
