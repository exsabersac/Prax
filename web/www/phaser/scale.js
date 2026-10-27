/**
 * U6：多分辨率抗糊（对照 Mach 网页版思路，非 wasm 同构）。
 * - 逻辑分辨率固定 VIEW_W×VIEW_H（U5 屏坐标菜单命中不变）
 * - CSS 显示：整数优先 / 亚像素可控 zoom，去掉非整数 FIT 发虚
 * - backing store = CSS × dpr（上限 3）
 * - resize 只重算布局/缩放，不销毁 Game、不碰 Session
 */
import { VIEW_W, VIEW_H } from "./map.js";

export const DPR_CAP = 3;

export function readDpr() {
  if (typeof window === "undefined") return 1;
  return Math.min(DPR_CAP, window.devicePixelRatio || 1);
}

/**
 * 把逻辑视口拟合进 host CSS 盒：≥1 取整数 zoom；<1 取 1/4 档可控缩放。
 * @param {number} availW
 * @param {number} availH
 */
export function fitCssZoom(availW, availH) {
  const raw = Math.min(availW / VIEW_W, availH / VIEW_H);
  if (!Number.isFinite(raw) || raw <= 0) return 1;
  if (raw >= 1) return Math.max(1, Math.floor(raw + 1e-9));
  return Math.max(0.25, Math.floor(raw * 4 + 1e-9) / 4);
}

/**
 * @param {Phaser.Game} game
 * @param {HTMLElement} hostEl
 * @returns {{ dpr: number, cssZoom: number, cssW: number, cssH: number, backW: number, backH: number } | null}
 */
export function applyTownScale(game, hostEl) {
  if (!game || !hostEl || !game.canvas) return null;
  const availW = hostEl.clientWidth || 0;
  const availH = hostEl.clientHeight || 0;
  if (availW < 2 || availH < 2) return null;

  const dpr = readDpr();
  const cssZoom = fitCssZoom(availW, availH);
  const cssW = VIEW_W * cssZoom;
  const cssH = VIEW_H * cssZoom;
  const backW = Math.max(1, Math.round(cssW * dpr));
  const backH = Math.max(1, Math.round(cssH * dpr));

  const canvas = game.canvas;
  const scale = game.scale;

  // 1) 钉逻辑 gameSize，并用 zoom/displaySize 对齐输入映射（pointer ∈ VIEW 坐标）
  if (scale) {
    if (scale.gameSize && typeof scale.gameSize.setSize === "function") {
      if (scale.gameSize.width !== VIEW_W || scale.gameSize.height !== VIEW_H) {
        scale.gameSize.setSize(VIEW_W, VIEW_H);
      }
    }
    if (typeof scale.setZoom === "function") {
      if (Math.abs((scale.zoom || 1) - cssZoom) > 1e-6) {
        scale.setZoom(cssZoom);
      }
    } else {
      scale.zoom = cssZoom;
    }
    if (scale.displaySize && typeof scale.displaySize.setSize === "function") {
      scale.displaySize.setSize(cssW, cssH);
    }
    // 刷新 canvas bounds，供 Input 做 page→game 换算；不改 Session
    if (typeof scale.updateBounds === "function") scale.updateBounds();
  }

  // 2) CSS 显示尺寸
  canvas.style.width = `${cssW}px`;
  canvas.style.height = `${cssH}px`;
  canvas.style.setProperty("image-rendering", "pixelated");

  // 3) Mach：backing = CSS × dpr。逻辑坐标仍 VIEW_W×VIEW_H。
  if (canvas.width !== backW || canvas.height !== backH) {
    if (game.renderer && typeof game.renderer.resize === "function") {
      game.renderer.resize(backW, backH);
    } else {
      canvas.width = backW;
      canvas.height = backH;
    }
  }

  // renderer.resize 可能改 style / gameSize，再钉回来
  canvas.style.width = `${cssW}px`;
  canvas.style.height = `${cssH}px`;
  if (scale) {
    if (scale.gameSize && typeof scale.gameSize.setSize === "function") {
      scale.gameSize.setSize(VIEW_W, VIEW_H);
    }
    if (scale.displaySize && typeof scale.displaySize.setSize === "function") {
      scale.displaySize.setSize(cssW, cssH);
    }
    scale.zoom = cssZoom;
    if (typeof scale.updateBounds === "function") scale.updateBounds();
  }

  const info = { dpr, cssZoom, cssW, cssH, backW, backH };
  game.__u6Scale = info;
  if (typeof window !== "undefined") window.__praxU6Scale = info;
  return info;
}

/**
 * 监听 host / 窗口 / visualViewport；回调只重算缩放。
 * @param {Phaser.Game} game
 * @param {HTMLElement} hostEl
 * @param {() => void} onLayout
 */
export function watchTownScale(game, hostEl, onLayout) {
  let pending = false;
  const schedule = () => {
    if (pending) return;
    pending = true;
    requestAnimationFrame(() => {
      pending = false;
      onLayout();
    });
  };

  const ro =
    typeof ResizeObserver !== "undefined"
      ? new ResizeObserver(schedule)
      : null;
  if (ro) ro.observe(hostEl);

  window.addEventListener("resize", schedule);
  window.addEventListener("orientationchange", schedule);
  if (window.visualViewport) {
    window.visualViewport.addEventListener("resize", schedule);
  }

  // 首帧后再跑一次（字体/布局稳定）
  schedule();
  setTimeout(schedule, 50);
  setTimeout(schedule, 200);

  game.__u6Unwatch = () => {
    if (ro) ro.disconnect();
    window.removeEventListener("resize", schedule);
    window.removeEventListener("orientationchange", schedule);
    if (window.visualViewport) {
      window.visualViewport.removeEventListener("resize", schedule);
    }
  };
}

export { VIEW_W, VIEW_H };
