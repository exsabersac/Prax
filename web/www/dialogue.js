/** @param {HTMLElement} root @param {import('./api.js').View} view */
export function renderDialogue(root, view) {
  root.innerHTML = "";
  const h = document.createElement("h2");
  h.textContent = "对话与回合反馈";
  root.appendChild(h);

  const ul = document.createElement("ul");
  ul.className = "log";
  const lines = view.log || [];
  if (lines.length === 0) {
    const p = document.createElement("p");
    p.className = "empty";
    p.textContent = "还没有发生的事。";
    root.appendChild(p);
    return;
  }
  for (const line of lines) {
    const li = document.createElement("li");
    li.className = `kind-${line.kind || "system"}`;
    li.textContent = line.text;
    ul.appendChild(li);
  }
  root.appendChild(ul);
  ul.lastElementChild?.scrollIntoView({ block: "nearest" });
}
