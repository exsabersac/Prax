/**
 * U1：场景面板挂 Phaser 单地点 canvas；点选走 onSelect → praxMenu。
 * 无 Phaser 时回退到旧 DOM 按钮（便于静态自检）。
 */
import { mountPhaser, setSelectHandler, syncTown, isMounted } from "./phaser/game.js";

let mounted = false;
let lastOnSelect = null;

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
    btn.textContent = a.atPlayerLoc ? a.label : `${a.label}（${a.place || "?"}）`;
    btn.disabled = !a.atPlayerLoc;
    btn.setAttribute("aria-pressed", a.id === view.selectedActorId ? "true" : "false");
    if (a.atPlayerLoc) btn.addEventListener("click", () => onSelect(a.id));
    row.appendChild(btn);
  }
  root.appendChild(row);
}

export function renderScene(root, view, onSelect) {
  lastOnSelect = onSelect;
  if (typeof Phaser === "undefined") {
    renderDomFallback(root, view, onSelect);
    return;
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
      return;
    }
  }

  setSelectHandler(onSelect);
  syncTown(view);
}
