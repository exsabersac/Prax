export function renderMenu(root, menu, onAct, onWait) {
  root.innerHTML = "";
  const h = document.createElement("h2");
  h.textContent = "菜单";
  root.appendChild(h);
  if (!menu?.actions?.length) {
    const p = document.createElement("p");
    p.className = "empty";
    p.textContent = "此刻没有候选动作。";
    root.appendChild(p);
  } else {
    const list = document.createElement("div");
    list.className = "actions";
    for (const a of menu.actions) {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "action";
      const title = document.createElement("span");
      title.textContent = a.label;
      const kind = document.createElement("span");
      kind.className = "kind";
      kind.textContent = a.kind || a.practiceId || "";
      btn.appendChild(title);
      btn.appendChild(kind);
      btn.addEventListener("click", () => onAct(a.id));
      list.appendChild(btn);
    }
    root.appendChild(list);
  }
  const wait = document.createElement("button");
  wait.type = "button";
  wait.className = "action";
  wait.style.marginTop = "0.5rem";
  wait.textContent = "稍候";
  wait.addEventListener("click", onWait);
  root.appendChild(wait);
}
