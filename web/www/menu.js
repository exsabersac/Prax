/** @param {HTMLElement} root @param {{ actorId?: string, actions?: import('./api.js').MenuAction[] } | null} menu @param {(actionId: string) => void} onAct */
export function renderMenu(root, menu, onAct) {
  root.innerHTML = "";
  const h = document.createElement("h2");
  h.textContent = "菜单";
  root.appendChild(h);

  if (!menu || !menu.actions || menu.actions.length === 0) {
    const p = document.createElement("p");
    p.className = "empty";
    p.textContent = menu ? "此刻没有可做的事。" : "点选场景中的角色以查看动作。";
    root.appendChild(p);
    return;
  }

  const list = document.createElement("div");
  list.className = "actions";
  for (const a of menu.actions) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "action";
    btn.dataset.actionId = a.id; // 只存 id，点击只传 id
    const title = document.createElement("span");
    title.textContent = a.label;
    const kind = document.createElement("span");
    kind.className = "kind";
    kind.textContent = a.kind;
    btn.appendChild(title);
    btn.appendChild(kind);
    btn.addEventListener("click", () => onAct(a.id));
    list.appendChild(btn);
  }
  root.appendChild(list);
}
