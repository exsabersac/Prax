/**
 * U7：canvas 流体铺满 + 逻辑尺寸随布局（叠 U6 抗糊，对照 Mach computeLayout 思路，非 wasm 同构）。
 * - host/canvas CSS 吃满可用区（不再钉死 640×360 离散 zoom）
 * - 逻辑 gameSize = CSS 尺寸（随布局变）；pointer 与屏坐标菜单命中同空间
 * - backing = CSS × dpr（上限 3）；pixelArt/nearest 不回退
 * - resize 只重算布局/缩放/命中，不销毁 Game、不碰 Session
 */
import { VIEW_W as DESIGN_W, VIEW_H as DESIGN_H } from "./map.js";

export const DPR_CAP = 3;
export { DESIGN_W, DESIGN_H };

export function readDpr() {
  if (typeof window === "undefined") return 1;
  return Math.min(DPR_CAP, window.devicePixelRatio || 1);
}

/**
 * Mach 风格布局：可用 CSS 盒 → 铺满 css + 随布局的逻辑 gameSize + dpr backing。
 * @param {number} availW
 * @param {number} availH
 */
export function computeLayout(availW, availH) {
  const cssW = Math.max(2, Math.round(availW));
  const cssH = Math.max(2, Math.round(availH));
  const dpr = readDpr();
  // 逻辑尺寸随布局：1 CSS 像素 = 1 逻辑单位（zoom=1），菜单屏坐标无需再乘离散 zoom
  const gameW = cssW;
  const gameH = cssH;
  const backW = Math.max(1, Math.round(cssW * dpr));
  const backH = Math.max(1, Math.round(cssH * dpr));
  // 设计单位参考缩放（仅调试/徽章；不作为离散显示 zoom）
  const designScale =
    Math.min(cssW / DESIGN_W, cssH / DESIGN_H) || 1;
  return {
    cssW,
    cssH,
    gameW,
    gameH,
    backW,
    backH,
    dpr,
    designScale,
    /** @deprecated U6 徽章兼容；U7 恒为 1（流体铺满，非离散 zoom） */
    cssZoom: 1,
  };
}

/**
 * @param {Phaser.Game} game
 * @param {HTMLElement} hostEl
 * @returns {ReturnType<typeof computeLayout> | null}
 */
export function applyTownScale(game, hostEl) {
  if (!game || !hostEl || !game.canvas) return null;
  const availW = hostEl.clientWidth || 0;
  const availH = hostEl.clientHeight || 0;
  if (availW < 2 || availH < 2) return null;

  const layout = computeLayout(availW, availH);
  const { cssW, cssH, gameW, gameH, backW, backH, dpr, designScale, cssZoom } =
    layout;

  const canvas = game.canvas;
  const scale = game.scale;

  // 1) 逻辑 gameSize 随布局；zoom=1；displaySize = CSS 铺满
  if (scale) {
    if (scale.gameSize && typeof scale.gameSize.setSize === "function") {
      if (scale.gameSize.width !== gameW || scale.gameSize.height !== gameH) {
        scale.gameSize.setSize(gameW, gameH);
      }
    }
    if (typeof scale.setGameSize === "function") {
      try {
        scale.setGameSize(gameW, gameH);
      } catch (_) {
        /* older phaser */
      }
    }
    if (typeof scale.setZoom === "function") {
      if (Math.abs((scale.zoom || 1) - 1) > 1e-6) scale.setZoom(1);
    } else {
      scale.zoom = 1;
    }
    if (scale.displaySize && typeof scale.displaySize.setSize === "function") {
      scale.displaySize.setSize(cssW, cssH);
    }
    if (typeof scale.updateBounds === "function") scale.updateBounds();
  }

  // 2) CSS 显示：吃满 host（流体）；钉左上，避免 Scale.CENTER 留边
  canvas.style.position = "absolute";
  canvas.style.left = "0";
  canvas.style.top = "0";
  canvas.style.margin = "0";
  canvas.style.width = `${cssW}px`;
  canvas.style.height = `${cssH}px`;
  canvas.style.setProperty("image-rendering", "pixelated");

  // 3) Mach：backing = CSS × dpr
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
      scale.gameSize.setSize(gameW, gameH);
    }
    if (scale.displaySize && typeof scale.displaySize.setSize === "function") {
      scale.displaySize.setSize(cssW, cssH);
    }
    scale.zoom = 1;
    if (typeof scale.updateBounds === "function") scale.updateBounds();
  }

  const info = {
    ...layout,
    dpr,
    cssZoom,
    designScale,
  };
  game.__u7Layout = info;
  // U6 徽章 / 旧钩子兼容
  game.__u6Scale = info;
  if (typeof window !== "undefined") {
    window.__praxU7Layout = info;
    window.__praxU6Scale = info;
  }
  return info;
}

/**
 * 监听 host / 窗口 / visualViewport；回调只重算缩放与布局。
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

  schedule();
  setTimeout(schedule, 50);
  setTimeout(schedule, 200);

  game.__u7Unwatch = game.__u6Unwatch = () => {
    if (ro) ro.disconnect();
    window.removeEventListener("resize", schedule);
    window.removeEventListener("orientationchange", schedule);
    if (window.visualViewport) {
      window.visualViewport.removeEventListener("resize", schedule);
    }
  };
}

export { DESIGN_W as VIEW_W, DESIGN_H as VIEW_H };
