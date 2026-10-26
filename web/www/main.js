import { praxNew, praxMenu, praxAct } from "./api.js";
import { renderScene } from "./scene.js";
import { renderMenu } from "./menu.js";
import { renderDialogue } from "./dialogue.js";

const elScene = document.getElementById("scene");
const elMenu = document.getElementById("menu");
const elDialogue = document.getElementById("dialogue");
const elMeta = document.getElementById("meta");
const elError = document.getElementById("error");

/** @type {import('./api.js').View | null} */
let view = null;
/** @type {{ actorId: string, actions: any[] } | null} */
let menu = null;

function showError(msg) {
  if (!msg) {
    elError.hidden = true;
    elError.textContent = "";
    return;
  }
  elError.hidden = false;
  elError.textContent = msg;
}

function paint() {
  if (!view) return;
  elMeta.textContent = `${view.locationLabel} · 回合 ${view.tick} · 玩家 ${view.playerId}`;
  renderScene(elScene, view, onSelectActor);
  renderMenu(elMenu, menu, onAct);
  renderDialogue(elDialogue, view);
}

async function onSelectActor(actorId) {
  showError("");
  const res = await praxMenu(actorId);
  if (!res.ok) {
    showError(res.message || res.error);
    return;
  }
  // praxMenu 可能刷新 selectedActorId；重新拉一份 view 由本地 session 持有——假数据里 menu 成功后 view 已更新
  // 这里用返回菜单 + 现有 view 重绘；真桥接时应再 prax 读 view
  menu = { actorId: res.actorId, actions: res.actions };
  if (view) view = { ...view, selectedActorId: res.actorId };
  paint();
}

async function onAct(actionId) {
  showError("");
  // 契约：只传不透明 action.id
  const res = await praxAct(actionId);
  if (!res.ok) {
    showError(res.message || res.error);
    return;
  }
  if (!res.accepted) {
    const tip = (res.narrative && res.narrative[0] && res.narrative[0].text) || "动作未接受";
    showError(tip);
  }
  view = res.view;
  menu = res.menu;
  paint();
}

async function boot() {
  const res = await praxNew("my-town");
  if (!res.ok) {
    showError(res.message || res.error);
    return;
  }
  view = res.view;
  menu = null;
  paint();
}

boot();
