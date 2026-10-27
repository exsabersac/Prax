/**
 * U2–U4：场景面板挂 Phaser；Menu/叙事在 canvas 叠层。
 * 无 Phaser 时回退到旧 DOM 按钮 + menu/dialogue 旁路。
 */
import {
  mountPhaser,
  setSelectHandler,
  setActHandler,
  setWaitHandler,
  syncTown,
  syncHud,
  isMounted,
} from "./phaser/game.js";

let mounted = false;

function renderDomFallback(root, view, onSelect) {
  root.innerHTML = "";
  const h = document.createElement("h2");
  h.textContent = "场景";
  root.appendChild(h);
  const place = document.createElement("div");
  place.className = "place";
  place.textContent = view.locationLabel;
  root.appendChild(place);
  const hint = document.createElement("p");
  hint.className = "empty";
  hint.textContent = "同场可点选高亮；菜单来自玩家候选动作（Session）";
  root.appendChild(hint);
  const row = document.createElement("div");
  row.className = "actors";
  for (const a of view.actors) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "actor";
    btn.textContent = a.atPlayerLoc ? a.label : `${a.label}（${a.placeLabel || a.place || "?"}）`;
    btn.disabled = !a.atPlayerLoc;
    btn.setAttribute("aria-pressed", a.id === view.selectedActorId ? "true" : "false");
    if (a.atPlayerLoc) btn.addEventListener("click", () => onSelect(a.id));
    row.appendChild(btn);
  }
  root.appendChild(row);
}

/**
 * @returns {"phaser" | "dom"} 当前渲染模式，供 main 决定是否还画 DOM 旁路
 */
export function renderScene(root, view, onSelect, onAct, onWait) {
  if (typeof Phaser === "undefined") {
    renderDomFallback(root, view, onSelect);
    return "dom";
  }

  if (!mounted || !isMounted()) {
    root.innerHTML = "";
    const h = document.createElement("h2");
    h.textContent = "场景";
    root.appendChild(h);
    const frame = document.createElement("div");
    frame.className = "town-frame";
    root.appendChild(frame);
    try {
      mountPhaser(frame);
      mounted = true;
    } catch (e) {
      console.warn("Phaser mount failed, DOM fallback", e);
      renderDomFallback(root, view, onSelect);
      return "dom";
    }
  }

  setSelectHandler(onSelect);
  setActHandler(onAct);
  setWaitHandler(onWait);
  syncTown(view);
  return "phaser";
}

export function pushHud(view, menu) {
  if (!isMounted()) return;
  syncHud(view, menu);
}
