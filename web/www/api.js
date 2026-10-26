/**
 * 会话客户端：POST /api/session → prax-web-session（真 Prax.Session JSON）。
 * 字段对齐 Session ToJSON / examples/my-town-session.json；JS 不重算规则。
 */

const PLACE_LABEL = { square: "广场", mill: "磨坊" };
const ACTOR_LABEL = {
  you: "你", bob: "Bob", carol: "Carol", dana: "Dana", eve: "Eve", gale: "Gale",
};

async function rpc(payload) {
  const res = await fetch("/api/session", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  try {
    return await res.json();
  } catch (e) {
    return { ok: false, error: "bad_response", message: String(e) };
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
  return { ok: true, save: data.save };
}

export async function praxLoad(raw) {
  const data = await rpc({ op: "load", raw });
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
