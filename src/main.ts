import { init, effect, frameLoop, surface, clock } from "vgpu";
import shader from "./scroll.wgsl";
import "./style.css";

const canvas = document.getElementById("gl") as HTMLCanvasElement;
const progress = document.getElementById("progress") as HTMLElement;
const sections = Array.from(document.querySelectorAll<HTMLElement>("section[data-scene]"));

let target = 0;
let current = 0;

function onScroll() {
  const max = document.documentElement.scrollHeight - window.innerHeight;
  target = max > 0 ? (window.scrollY / max) * 3 : 0;
  progress.style.transform = `scaleX(${max > 0 ? window.scrollY / max : 0})`;

  // fade text: section whose center is closest to viewport center wins
  const vc = window.scrollY + window.innerHeight / 2;
  let best: HTMLElement | null = null;
  let bestDist = Infinity;
  for (const s of sections) {
    const r = s.getBoundingClientRect();
    const c = window.scrollY + r.top + r.height / 2;
    const d = Math.abs(c - vc);
    if (d < bestDist) {
      bestDist = d;
      best = s;
    }
  }
  for (const s of sections) s.classList.toggle("active", s === best);
}

async function start() {
  let gpu;
  try {
    gpu = await init();
  } catch {
    document.body.classList.add("no-webgpu");
    return;
  }

  const out = surface(gpu, canvas, { dpr: [1, 1.5] });
  const fx = effect(gpu, shader, {
    set: { params: { time: 0, scroll: 0, aspect: 1, seed: 0 } },
  });

  const setAspect = () => {
    const size = out.size;
    fx.set({ params: { aspect: size[0] / Math.max(1, size[1]) } });
  };
  setAspect();
  if (typeof out.onResize === "function") out.onResize(setAspect);

  const time = clock(gpu);
  let running = true;
  document.addEventListener("visibilitychange", () => {
    running = !document.hidden;
  });

  window.addEventListener("scroll", onScroll, { passive: true });
  window.addEventListener("resize", onScroll, { passive: true });
  onScroll();

  frameLoop(gpu, (frame) => {
    if (!running) return;
    // buttery scroll smoothing
    current += (target - current) * 0.075;
    if (Math.abs(target - current) < 0.0004) current = target;
    fx.set({ params: { time: time.time, scroll: current } });
    frame.pass(out, fx);
  });
}

start();
