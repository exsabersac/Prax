import { praxNew, praxMenu, praxAct, praxWait, praxSave, praxLoad } from "./api.js";
import { renderScene } from "./scene.js";
import { renderMenu } from "./menu.js";
import { renderDialogue } from "./dialogue.js";

const elScene = document.getElementById("scene");
const elMenu = document.getElementById("menu");
const elDialogue = document.getElementById("dialogue");
const elMeta = document.getElementById("meta");
const elError = document.getElementById("error");

let view = null;
let menu = null;
let lastSave = null;

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
  renderMenu(elMenu, menu, onAct, onWait);
  renderDialogue(elDialogue, view);
}

async function onSelectActor(actorId) {
  showError("");
  if (view) view = { ...view, selectedActorId: actorId };
  const res = await praxMenu(actorId);
  if (!res.ok) {
    showError(res.message || res.error);
    paint();
    return;
  }
  menu = { actorId: res.actorId, actions: res.actions };
  paint();
}

async function onAct(actionId) {
  showError("");
  const res = await praxAct(actionId, view);
  if (!res.ok) {
    showError(res.message || res.error);
    return;
  }
  view = res.view;
  menu = res.menu;
  paint();
}

async function onWait() {
  showError("");
  const res = await praxWait(view);
  if (!res.ok) {
    showError(res.message || res.error);
    return;
  }
  view = res.view;
  menu = res.menu;
  paint();
}

async function onSave() {
  showError("");
  const res = await praxSave();
  if (!res.ok) {
    showError(res.message || res.error);
    return;
  }
  lastSave = res.save;
  if (view) {
    view = {
      ...view,
      log: (view.log || []).concat([{ kind: "system", text: "已存档（内存）。" }]),
    };
  }
  paint();
}

async function onLoad() {
  showError("");
  if (lastSave == null) {
    showError("还没有存档，请先存档。");
    return;
  }
  const res = await praxLoad(lastSave);
  if (!res.ok) {
    showError(res.message || res.error);
    return;
  }
  view = res.view;
  menu = res.menu;
  paint();
}

function wireToolbar() {
  const bar = document.createElement("div");
  bar.style.display = "flex";
  bar.style.gap = "0.5rem";
  bar.style.margin = "0.5rem 0";
  for (const [label, fn] of [
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
  const res = await praxNew("my-town");
  if (!res.ok) {
    showError(res.message || res.error || "无法连接 Session 桥");
    return;
  }
  view = res.view;
  menu = res.menu;
  paint();
}

boot();
