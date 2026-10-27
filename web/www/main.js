import { praxNew, praxMenu, praxAct, praxWait, praxSave, praxLoad, formatError } from "./api.js";
import { renderScene, pushHud } from "./scene.js";
import { renderMenu } from "./menu.js";
import { renderDialogue } from "./dialogue.js";

const elScene = document.getElementById("scene");
const elMenu = document.getElementById("menu");
const elDialogue = document.getElementById("dialogue");
const elMeta = document.getElementById("meta");
const elError = document.getElementById("error");
const elGuide = document.getElementById("guide");
const elLayout = document.querySelector(".layout");

/** J05：扁平 SaveMeta 持久化，刷新后 praxLoad 可恢复 */
const SAVE_KEY = "prax.my-town.saveMeta";
/** M5b：本页会话内 dismiss 引导 */
const GUIDE_DISMISS_KEY = "prax.my-town.guideDismissed";

let view = null;
let menu = null;
let offerNewOnError = false;
/** @type {"phaser" | "dom"} */
let uiMode = "dom";

function clearError() {
  offerNewOnError = false;
  elError.hidden = true;
  elError.textContent = "";
  elError.replaceChildren();
}

/** M5d：可见中文错误；可选挂「新开一局」（M5c） */
function showError(msg, { offerNew = false } = {}) {
  if (!msg) {
    clearError();
    return;
  }
  offerNewOnError = offerNew;
  elError.hidden = false;
  elError.replaceChildren();
  const text = document.createElement("div");
  text.textContent = msg;
  elError.appendChild(text);
  if (offerNew) {
    const row = document.createElement("div");
    row.className = "error-actions";
    const btn = document.createElement("button");
    btn.type = "button";
    btn.textContent = "新开一局";
    btn.addEventListener("click", () => startNewGame());
    row.appendChild(btn);
    elError.appendChild(row);
  }
}

function showErrorFrom(res, fallback, opts) {
  showError(formatError(res, fallback), opts);
}

/** M5b 开局引导：地点 / 阵容 / 下一步；可 dismiss */
function showGuide() {
  if (!elGuide) return;
  if (sessionStorage.getItem(GUIDE_DISMISS_KEY) === "1") {
    elGuide.hidden = true;
    elGuide.replaceChildren();
    return;
  }
  elGuide.hidden = false;
  elGuide.replaceChildren();
  const h = document.createElement("h2");
  h.textContent = "开局指引";
  elGuide.appendChild(h);
  const ul = document.createElement("ul");
  for (const line of [
    "地点：广场（square）、磨坊（mill）",
    "阵容：你（you）+ Bob / Carol / Dana / Eve / Gale",
    "下一步：方向键/拖拽逛地图；点居民 → 菜单 → Act",
  ]) {
    const li = document.createElement("li");
    li.textContent = line;
    ul.appendChild(li);
  }
  elGuide.appendChild(ul);
  const row = document.createElement("div");
  row.className = "guide-actions";
  const dismiss = document.createElement("button");
  dismiss.type = "button";
  dismiss.textContent = "知道了";
  dismiss.addEventListener("click", () => {
    sessionStorage.setItem(GUIDE_DISMISS_KEY, "1");
    elGuide.hidden = true;
    elGuide.replaceChildren();
  });
  row.appendChild(dismiss);
  elGuide.appendChild(row);
}

function readStoredSave() {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return null;
    const meta = JSON.parse(raw);
    if (!meta || typeof meta.blob !== "string") return null;
    return {
      format: meta.format || "prax-state-v4",
      worldId: meta.worldId || "my-town",
      blob: meta.blob,
    };
  } catch {
    return { __corrupt: true };
  }
}

function writeStoredSave(save) {
  if (!save || typeof save.blob !== "string") return;
  const meta = {
    format: save.format || "prax-state-v4",
    worldId: save.worldId || "my-town",
    blob: save.blob,
  };
  localStorage.setItem(SAVE_KEY, JSON.stringify(meta));
}

function setBypassPanels(hidden) {
  if (elMenu) elMenu.hidden = hidden;
  if (elDialogue) elDialogue.hidden = hidden;
  if (elLayout) elLayout.classList.toggle("layout-u2", hidden);
}

function paint() {
  if (!view) return;
  elMeta.textContent = `${view.locationLabel} · 回合 ${view.tick} · 玩家 ${view.playerId}`;
  uiMode = renderScene(elScene, view, onSelectActor, onAct, onWait);
  if (uiMode === "phaser") {
    setBypassPanels(true);
    pushHud(view, menu);
  } else {
    setBypassPanels(false);
    renderMenu(elMenu, menu, onAct, onWait);
    renderDialogue(elDialogue, view);
  }
}

async function onSelectActor(actorId) {
  clearError();
  if (view) view = { ...view, selectedActorId: actorId };
  const res = await praxMenu(actorId);
  if (!res.ok) {
    showErrorFrom(res, "无法刷新菜单。");
    paint();
    return;
  }
  menu = { actorId: res.actorId, actions: res.actions };
  paint();
}

async function onAct(actionId) {
  clearError();
  const res = await praxAct(actionId, view);
  if (!res.ok) {
    showErrorFrom(res, "行动失败。");
    return;
  }
  if (res.accepted === false) {
    showErrorFrom(res, "行动未被接受。");
  }
  view = res.view;
  menu = res.menu;
  paint();
}

async function onWait() {
  clearError();
  const res = await praxWait(view);
  if (!res.ok) {
    showErrorFrom(res, "稍候失败。");
    return;
  }
  view = res.view;
  menu = res.menu;
  paint();
}

async function onSave() {
  clearError();
  const res = await praxSave();
  if (!res.ok) {
    showErrorFrom(res, "存档失败。");
    return;
  }
  writeStoredSave(res.save);
  if (view) {
    view = {
      ...view,
      log: (view.log || []).concat([{ kind: "system", text: "已存档（localStorage）。" }]),
    };
  }
  paint();
}

/**
 * Load 成功后丢弃读档前/Load 响应里的旧 menu，按当前 actor 重拉 praxMenu，
 * 保证按钮上的 actionId 只来自该次之后的 Menu（禁缓存旧 id）。
 */
async function applyLoaded(res) {
  view = res.view;
  menu = null;
  const actorId = view.selectedActorId || view.playerId;
  const menuRes = await praxMenu(actorId);
  if (!menuRes.ok) {
    showErrorFrom(menuRes, "读档后无法刷新菜单。");
    menu = { actorId, actions: [] };
    paint();
    return;
  }
  menu = { actorId: menuRes.actorId, actions: menuRes.actions };
  paint();
}

async function onLoad() {
  clearError();
  const stored = readStoredSave();
  if (!stored) {
    showError("还没有存档，请先存档。");
    return;
  }
  if (stored.__corrupt) {
    localStorage.removeItem(SAVE_KEY);
    showError("本地存档已损坏（无法解析），请新开一局。", { offerNew: true });
    return;
  }
  const res = await praxLoad(stored);
  if (!res.ok) {
    showErrorFrom(res, "读档失败：存档无效或已损坏。", { offerNew: true });
    return;
  }
  await applyLoaded(res);
}

async function startNewGame() {
  clearError();
  sessionStorage.removeItem(GUIDE_DISMISS_KEY);
  const res = await praxNew("my-town");
  if (!res.ok) {
    showErrorFrom(res, "无法新开一局，请检查会话桥。", { offerNew: true });
    return;
  }
  view = res.view;
  menu = res.menu;
  showGuide();
  paint();
}

function wireToolbar() {
  const bar = document.createElement("div");
  bar.className = "toolbar";
  for (const [label, fn] of [
    ["新开一局", startNewGame],
    ["存档", onSave],
    ["读档", onLoad],
  ]) {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = label;
    b.addEventListener("click", fn);
    bar.appendChild(b);
  }
  elMeta.after(bar);
}

async function boot() {
  wireToolbar();
  const stored = readStoredSave();
  if (stored && stored.__corrupt) {
    localStorage.removeItem(SAVE_KEY);
    elMeta.textContent = "存档无效";
    showError("本地存档已损坏（无法解析），请新开一局。", { offerNew: true });
    return;
  }
  if (stored) {
    const loaded = await praxLoad(stored);
    if (loaded.ok) {
      await applyLoaded(loaded);
      return;
    }
    // M5c：坏档不静默挂死——清本地、中文提示、可点新开
    localStorage.removeItem(SAVE_KEY);
    elMeta.textContent = "存档无效";
    showErrorFrom(loaded, "存档无效或已损坏，请新开一局。", { offerNew: true });
    return;
  }
  await startNewGame();
}

boot();
