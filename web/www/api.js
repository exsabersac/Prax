/**
 * 会话客户端：POST /api/session → prax-web-session（真 Prax.Session JSON）。
 * 字段对齐 Session ToJSON / examples/my-town-session.json；JS 不重算规则。
 */

/** 玩家可见地名（内部 id 不变） */
const PLACE_LABEL = { square: "广场", mill: "磨坊", bridge: "小桥" };
/** 玩家可见角色名（产品定稿；内部 id 不变） */
const ACTOR_LABEL = {
  you: "你", bob: "鲍勃", carol: "卡萝", dana: "黛娜", eve: "伊芙", gale: "盖尔",
};

/** 展示层：把文案里的角色/地点 id 换成中文专名（不改契约字段） */
const DISPLAY_ID_RE = /\b(you|bob|carol|dana|eve|gale|square|mill|bridge)\b/g;
const DISPLAY_ID_ZH = Object.assign({}, ACTOR_LABEL, PLACE_LABEL);

export function localizeDisplayText(text) {
  if (text == null || text === "") return text == null ? "" : String(text);
  return String(text).replace(DISPLAY_ID_RE, (id) => DISPLAY_ID_ZH[id] || id);
}

export function actorDisplayName(id) {
  return ACTOR_LABEL[id] || localizeDisplayText(id) || String(id || "");
}

export function placeDisplayName(id) {
  return PLACE_LABEL[id] || localizeDisplayText(id) || String(id || "");
}

/** 已知 error 码 → 中文（坏档/桥死等强制中文，勿被桥端英文技术串盖掉） */
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
  // 桥端 SessionMain / praxLoad 实际 error 码
  praxLoad: "读档失败，存档可能已损坏。",
  save_decode: "存档无效或已损坏。",
  exception: "出错了，请稍后重试。",
  rejected: "行动未被接受。",
};

/** 含汉字则视为可读中文；否则当技术串处理 */
function isReadableZh(msg) {
  return /[\u4e00-\u9fff]/.test(msg);
}

/**
 * D01：load_failed / bad_save / bad_json / praxLoad / 桥死等优先 ERROR_ZH；
 * 仅当服务端 message 已是中文时才原样展示，避免 Prax.Session.praxLoad: JSON Error… 露给玩家。
 */
export function formatError(res, fallback = "出错了，请稍后重试。") {
  if (!res) return fallback;
  const code = res.error && String(res.error);
  const msg = (res.message && String(res.message).trim()) || "";
  const zh = code && ERROR_ZH[code];
  if (zh) {
    if (!msg || !isReadableZh(msg)) return zh;
    return msg;
  }
  if (msg && isReadableZh(msg)) return msg;
  if (msg) return fallback;
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
  const playerId = raw.player || opts.playerId || "you";
  const actors = (raw.actors || []).map((a) => {
    const place = a.here;
    return {
      id: a.id,
      label: ACTOR_LABEL[a.id] || a.id,
      place,
      placeLabel: PLACE_LABEL[place] || place,
      atPlayerLoc: place === locationId,
    };
  });
  const log = (opts.log || []).map((line) =>
    line && typeof line === "object"
      ? { ...line, text: localizeDisplayText(line.text) }
      : line
  );
  return {
    worldId: raw.worldId,
    playerId,
    playerLabel: ACTOR_LABEL[playerId] || playerId,
    locationId,
    locationLabel: PLACE_LABEL[locationId] || localizeDisplayText(raw.locationLabel) || locationId,
    actors,
    selectedActorId: opts.selectedActorId ?? null,
    log,
    tick: opts.tick ?? 0,
    canSave: true,
  };
}

export function normalizeMenu(items) {
  return (items || []).map((m) => {
    // 主文案 id→中文；副标不直出 practice.* 技术 id（动作仍只靠不透明 action.id）
    const rawKind = m.practiceId || m.kind || "";
    const kindLooksTech =
      !rawKind ||
      /^practice\./i.test(String(rawKind)) ||
      !/[\u4e00-\u9fff]/.test(String(rawKind));
    return {
      id: m.actionId,
      label: localizeDisplayText(m.label),
      kind: kindLooksTech ? "" : String(rawKind),
      practiceId: m.practiceId,
      actionName: m.actionName,
    };
  });
}

function appendNarrative(log, narrative) {
  const lines = Array.isArray(narrative) ? narrative : [];
  return (log || []).concat(
    lines.map((text) => ({
      kind: "narrative",
      text: localizeDisplayText(String(text)),
    }))
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
