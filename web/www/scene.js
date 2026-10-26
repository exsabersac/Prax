/** @param {HTMLElement} root @param {import('./api.js').View} view @param {(actorId: string) => void} onSelect */
export function renderScene(root, view, onSelect) {
  root.innerHTML = "";
  const h = document.createElement("h2");
  h.textContent = "场景";
  root.appendChild(h);

  const place = document.createElement("div");
  place.className = "place";
  place.textContent = view.locationLabel;
  root.appendChild(place);

  const row = document.createElement("div");
  row.className = "actors";
  for (const a of view.actors) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "actor";
    btn.textContent = a.label;
    btn.disabled = !a.here;
    btn.setAttribute("aria-pressed", a.id === view.selectedActorId ? "true" : "false");
    if (a.here) {
      btn.addEventListener("click", () => onSelect(a.id));
    }
    row.appendChild(btn);
  }
  root.appendChild(row);
}
