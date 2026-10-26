/**
 * 会话客户端：POST /api/session → prax-web-session（真 Prax.Session JSON）。
 * 字段对齐 Session ToJSON / examples/my-town-session.json；JS 不重算规则。
 */

const PLACE_LABEL = { square: "广场", mill: "磨坊" };
const ACTOR_LABEL = {
  you: "你", bob: "Bob", carol: "Carol", dana: "Dana", eve: "Eve", gale: "Gale",
};

/** 已知 error 码 → 中文默认（仍优先用服务端 message） */
const ERROR_ZH = {
  network: "网络连接失败，请检查服务是否在运行。",
  bad_response: "服务返回无法解析，请稍后重试。",
  bad_request: "请求无效。",
  no_bridge: "会话桥未就绪，请确认 prax-web-session 已启动。",
  bridge_dead: "会话桥已断开，请刷新或新开一局。",
  bridge_eof: "会话桥无响应，请刷新或新开一局。",
  bad_json: "数据格式错误。",
  no_session: "还没有会话，请先新开一局。",
  bad_save: "存档无效或已损坏。",
  load_failed: "读档失败，存档可能已损坏。",
  rejected: "行动未被接受。",
};

export function formatError(res, fallback = "出错了，请稍后重试。") {
  if (!res) return fallback;
  const msg = (res.message && String(res.message).trim()) || "";
  if (msg) return msg;
  const code = res.error && String(res.error);
  if (code && ERROR_ZH[code]) return ERROR_ZH[code];
  if (code) return `出错了（${code}）。`;
  return fallback;
}

async function rpc(payload) {
  let res;
  try {
    res = await fetch("/api/session", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
  } catch (e) {
    return {
      ok: false,
      error: "network",
      message: ERROR_ZH.network,
      detail: String(e),
    };
  }
  try {
    return await res.json();
  } catch (e) {
    return {
      ok: false,
      error: "bad_response",
      message: ERROR_ZH.bad_response,
      detail: String(e),
    };
  }
}

export function normalizeView(raw, opts = {}) {
  const locationId = raw.locationId || "square";
  const actors = (raw.actors || []).map((a) => {
    const place = a.here;
    return {
      id: a.id,
      label: ACTOR_LABEL[a.id] || a.id,
      place,
      atPlayerLoc: place === locationId,
    };
  });
  return {
    worldId: raw.worldId,
    playerId: raw.player || opts.playerId || "you",
    locationId,
    locationLabel: PLACE_LABEL[locationId] || raw.locationLabel || locationId,
    actors,
    selectedActorId: opts.selectedActorId ?? null,
    log: opts.log || [],
    tick: opts.tick ?? 0,
    canSave: true,
  };
}

export function normalizeMenu(items) {
  return (items || []).map((m) => ({
    id: m.actionId,
    label: m.label,
    kind: m.practiceId,
    practiceId: m.practiceId,
    actionName: m.actionName,
  }));
}

function appendNarrative(log, narrative) {
  const lines = Array.isArray(narrative) ? narrative : [];
  return (log || []).concat(
    lines.map((text) => ({ kind: "narrative", text: String(text) }))
  );
}

export async function praxNew(worldId = "my-town") {
  const data = await rpc({ op: "new", worldId });
  if (!data.ok) return data;
  const view = normalizeView(data.view, {
    playerId: data.playerId,
    log: [{ kind: "system", text: "会话已连接 Prax.Session。" }],
    tick: 0,
  });
  return {
    ok: true,
    sessionId: "live",
    worldId: data.worldId,
    playerId: data.playerId,
    view,
    menu: { actorId: view.playerId, actions: normalizeMenu(data.menu) },
  };
}

/** Session 菜单是玩家候选动作；actorId 仅用于 UI 高亮。 */
export async function praxMenu(actorId) {
  const data = await rpc({ op: "menu" });
  if (!data.ok) return data;
  return { ok: true, actorId, actions: normalizeMenu(data.menu) };
}

export async function praxAct(actionId, prevView) {
  const data = await rpc({ op: "act", actionId });
  if (!data.ok) return data;
  const tick = (prevView?.tick ?? 0) + 1;
  const view = normalizeView(data.view, {
    playerId: prevView?.playerId,
    selectedActorId: prevView?.selectedActorId,
    log: appendNarrative(prevView?.log, data.narrative),
    tick,
  });
  return {
    ok: true,
    accepted: data.accepted !== false,
    message: data.message,
    error: data.error,
    narrative: data.narrative || [],
    view,
    menu: { actorId: view.playerId, actions: normalizeMenu(data.menu) },
  };
}

export async function praxWait(prevView) {
  const data = await rpc({ op: "wait" });
  if (!data.ok) return data;
  const tick = (prevView?.tick ?? 0) + 1;
  const view = normalizeView(data.view, {
    playerId: prevView?.playerId,
    selectedActorId: prevView?.selectedActorId,
    log: appendNarrative(prevView?.log, data.narrative),
    tick,
  });
  return {
    ok: true,
    accepted: true,
    narrative: data.narrative || [],
    view,
    menu: { actorId: view.playerId, actions: normalizeMenu(data.menu) },
  };
}

export async function praxSave() {
  const data = await rpc({ op: "save" });
  if (!data.ok) return data;
  const save =
    data.save != null
      ? data.save
      : { format: data.format, worldId: data.worldId, blob: data.blob };
  return { ok: true, save };
}

/** load.raw = praxSave / 桥 save 产出的整段 JSON 字符串 */
function saveRaw(save) {
  if (typeof save === "string") return save;
  if (save && typeof save.blob === "string" && (save.format || save.worldId)) {
    return JSON.stringify({
      format: save.format,
      worldId: save.worldId,
      blob: save.blob,
    });
  }
  if (save && typeof save.blob === "string") return save.blob;
  return JSON.stringify(save);
}

export async function praxLoad(raw) {
  const data = await rpc({ op: "load", raw: saveRaw(raw) });
  if (!data.ok) return data;
  const view = normalizeView(data.view, {
    playerId: data.playerId,
    log: [{ kind: "system", text: "已读档。" }],
    tick: 0,
  });
  return {
    ok: true,
    worldId: data.worldId,
    playerId: data.playerId,
    view,
    menu: { actorId: data.playerId, actions: normalizeMenu(data.menu) },
  };
}
