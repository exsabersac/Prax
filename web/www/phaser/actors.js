/**
 * U1–U5：角色色与文案短标（纯前端装饰，不回写世界）。
 * U5：气泡截断放宽，避免过度省略。
 */

export const ACTOR_FILL = {
  you: 0x2f6f4e,
  bob: 0x3d5a80,
  carol: 0x9b5de5,
  dana: 0xe07a3d,
  eve: 0xc44569,
  gale: 0x457b9d,
};

export function actorFill(id) {
  return ACTOR_FILL[id] || 0x666666;
}

/** 截断现有文案为头顶短标（不新增 Session 字段）；U5 默认更宽 */
export function shortenLabel(text, max = 18) {
  const s = String(text || "").replace(/\s+/g, " ").trim();
  if (!s) return "";
  if (s.length <= max) return s;
  return s.slice(0, max - 1) + "…";
}

/**
 * 从 View / Menu / narrative / action 抽象头顶气泡文案。
 * @returns {string | null}
 */
export function bubbleFromView(actor, view, menu) {
  if (!actor || !view) return null;
  const selected = actor.id === view.selectedActorId;

  if (selected && menu && Array.isArray(menu.actions) && menu.actions.length) {
    const a = menu.actions[0];
    return shortenLabel(a.label || a.id || "", 18);
  }

  const log = (view && view.log) || [];
  for (let i = log.length - 1; i >= 0; i--) {
    const line = log[i];
    const t = (line && line.text) || "";
    if (!t) continue;
    if (
      t.includes(actor.label) ||
      t.includes(actor.id) ||
      (selected && (line.kind === "narrative" || line.kind === "system"))
    ) {
      return shortenLabel(t, 20);
    }
  }

  if (selected) {
    if (menu && Array.isArray(menu.actions) && menu.actions.length === 0) {
      return "无动作";
    }
    return "…";
  }
  return null;
}
