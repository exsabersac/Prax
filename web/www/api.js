/**
 * 会话客户端。MVP：内存假数据，形状对齐架构契约 v0.1。
 * 日后换成 JSON 桥 / wasm 导出时，只替换本模块实现，UI 不改。
 */

const WORLD_ID = "my-town";
const PLAYER_ID = "you";

/** @typedef {{ id: string, label: string, here: boolean }} Actor */
/** @typedef {{ kind: string, text: string }} LogLine */
/** @typedef {{
 *   tick: number,
 *   playerId: string,
 *   locationId: string,
 *   locationLabel: string,
 *   actors: Actor[],
 *   selectedActorId: string | null,
 *   log: LogLine[],
 *   canSave: boolean
 * }} View */
/** @typedef {{
 *   id: string,
 *   label: string,
 *   kind: string,
 *   practiceId: string,
 *   actionId: string
 * }} MenuAction */

const LOC = {
  square: { id: "square", label: "广场" },
  mill: { id: "mill", label: "磨坊" },
};

/** 初始站位：square=you/bob/carol，mill=dana/eve/gale */
const ROSTER = [
  { id: "you", label: "你", place: "square" },
  { id: "bob", label: "Bob", place: "square" },
  { id: "carol", label: "Carol", place: "square" },
  { id: "dana", label: "Dana", place: "mill" },
  { id: "eve", label: "Eve", place: "mill" },
  { id: "gale", label: "Gale", place: "mill" },
];

/** 六必选 aff 的假菜单模板（id 为不透明 ga:v1） */
const AFF_TEMPLATES = [
  { stem: "go", label: "前往磨坊", kind: "move", practiceId: "world", actionId: "go" },
  { stem: "wait", label: "稍候片刻", kind: "wait", practiceId: "world", actionId: "wait" },
  { stem: "help", label: "公开帮忙", kind: "help", practiceId: "help", actionId: "help-public" },
  { stem: "say", label: "说破", kind: "talk", practiceId: "talk", actionId: "say-out" },
  { stem: "relay", label: "转告", kind: "talk", practiceId: "talk", actionId: "relay" },
  { stem: "doubt", label: "怀疑", kind: "talk", practiceId: "talk", actionId: "doubt" },
];

/** @type {{ sessionId: string, view: View, places: Record<string,string> } | null} */
let session = null;

function err(error, message) {
  return { ok: false, error, message };
}

function placesMap() {
  /** @type {Record<string,string>} */
  const m = {};
  for (const a of ROSTER) m[a.id] = a.place;
  return m;
}

/** @param {Record<string,string>} places @param {string} locationId @param {string|null} selectedActorId @param {LogLine[]} log @param {number} tick */
function projectView(places, locationId, selectedActorId, log, tick) {
  const loc = LOC[locationId] || LOC.square;
  /** @type {Actor[]} */
  const actors = ROSTER.map((r) => ({
    id: r.id,
    label: r.label,
    here: places[r.id] === locationId,
  }));
  return {
    tick,
    playerId: PLAYER_ID,
    locationId: loc.id,
    locationLabel: loc.label,
    actors,
    selectedActorId,
    log: log.slice(),
    canSave: false,
  };
}

/**
 * @param {string} worldId
 */
export async function praxNew(worldId) {
  if (worldId !== WORLD_ID) {
    return err("unknown_world", `未知世界：${worldId}（MVP 仅 my-town）`);
  }
  const places = placesMap();
  const log = [
    { kind: "system", text: "你站在广场上。磨坊在路的尽头。" },
    { kind: "system", text: "（假数据会话：规则尚未接上 Prax.Session）" },
  ];
  session = {
    sessionId: "sess-fake-1",
    places,
    view: projectView(places, "square", null, log, 0),
  };
  return {
    ok: true,
    sessionId: session.sessionId,
    worldId: WORLD_ID,
    playerId: PLAYER_ID,
    view: session.view,
  };
}

/**
 * @param {string} actorId
 */
export async function praxMenu(actorId) {
  if (!session) return err("no_session", "尚未 praxNew");
  const places = session.places;
  const playerPlace = places[PLAYER_ID];
  if (places[actorId] !== playerPlace && actorId !== PLAYER_ID) {
    return err("not_here", "对方不在同一地点");
  }

  /** @type {MenuAction[]} */
  const actions = [];
  for (const t of AFF_TEMPLATES) {
    // 前往：对地点锚点用 player；其余对选中角色（或自己）
    const target = t.stem === "go" ? "mill" : actorId;
    if (t.stem === "go" && playerPlace === "mill") {
      actions.push({
        id: `ga:v1:world:go:square`,
        label: "前往广场",
        kind: t.kind,
        practiceId: t.practiceId,
        actionId: t.actionId,
      });
      continue;
    }
    if (t.stem === "help" && actorId === PLAYER_ID) continue;
    actions.push({
      id: `ga:v1:${t.practiceId}:${t.actionId}:${target}`,
      label: t.stem === "help" ? `公开帮忙（${labelOf(actorId)}）` : t.label,
      kind: t.kind,
      practiceId: t.practiceId,
      actionId: t.actionId,
    });
  }

  session.view = {
    ...session.view,
    selectedActorId: actorId,
  };

  return { ok: true, actorId, actions };
}

/**
 * @param {string} actionId canonical ga:v1 string — 唯一允许传给引擎的菜单键
 */
export async function praxAct(actionId) {
  if (!session) return err("no_session", "尚未 praxNew");
  if (!actionId || typeof actionId !== "string") {
    return { ok: true, accepted: false, narrative: [], delta: {}, view: session.view, menu: null };
  }

  const parts = actionId.split(":");
  // ga:v1:practice:action:target
  if (parts.length < 5 || parts[0] !== "ga" || parts[1] !== "v1") {
    return {
      ok: true,
      accepted: false,
      narrative: [{ kind: "system", text: "无法识别的动作 id（请只传菜单返回的 id）" }],
      delta: {},
      view: session.view,
      menu: null,
    };
  }

  const practiceId = parts[2];
  const act = parts[3];
  const target = parts.slice(4).join(":");
  const places = { ...session.places };
  let locationId = places[PLAYER_ID];
  /** @type {LogLine[]} */
  const narrative = [];

  if (practiceId === "world" && act === "go") {
    const dest = target === "square" || target === "mill" ? target : "mill";
    places[PLAYER_ID] = dest;
    locationId = dest;
    narrative.push({ kind: "narrative", text: `你走向${LOC[dest].label}。` });
    narrative.push({ kind: "system", text: "（回合结束：NPC 尚未真实推进，假数据占位）" });
  } else if (practiceId === "world" && act === "wait") {
    narrative.push({ kind: "narrative", text: "你稍候片刻，镇上仍是往常的声音。" });
  } else if (act === "help-public") {
    const who = labelOf(target);
    narrative.push({ kind: "narrative", text: `你当众帮了 ${who} 一把。` });
    narrative.push({ kind: "system", text: "（trust 叶变化由引擎负责；前端不自算）" });
  } else if (act === "say-out") {
    narrative.push({ kind: "narrative", text: `你把话说明白了。` });
  } else if (act === "relay") {
    narrative.push({ kind: "narrative", text: `你把听来的话转告出去。` });
  } else if (act === "doubt") {
    narrative.push({ kind: "narrative", text: `你表示怀疑。` });
  } else {
    return {
      ok: true,
      accepted: false,
      narrative: [{ kind: "system", text: `假数据未实现：${actionId}` }],
      delta: {},
      view: session.view,
      menu: null,
    };
  }

  const tick = session.view.tick + 1;
  const log = session.view.log.concat(narrative);
  const selected = session.view.selectedActorId;
  session.places = places;
  session.view = projectView(places, locationId, selected, log, tick);

  let menu = null;
  if (selected) {
    const m = await praxMenu(selected);
    if (m.ok) menu = m;
  }

  return {
    ok: true,
    accepted: true,
    narrative,
    delta: { tick },
    view: session.view,
    menu,
  };
}

export async function praxSave() {
  return err("not_implemented", "praxSave 属 M2");
}

export async function praxLoad() {
  return err("not_implemented", "praxLoad 属 M2");
}

function labelOf(id) {
  const r = ROSTER.find((x) => x.id === id);
  return r ? r.label : id;
}
