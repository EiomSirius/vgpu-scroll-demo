// Deriva — scroll-driven morphing shader (4 scenes blended by params.scroll 0..3)
struct Params {
  time: f32,
  scroll: f32,
  aspect: f32,
  seed: f32,
};
@group(0) @binding(0) var<uniform> params: Params;

fn hash21(p: vec2f) -> f32 {
  var p3 = fract(vec3f(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

fn noise2(p: vec2f) -> f32 {
  let i = floor(p);
  let f = fract(p);
  let u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash21(i), hash21(i + vec2f(1.0, 0.0)), u.x),
    mix(hash21(i + vec2f(0.0, 1.0)), hash21(i + vec2f(1.0, 1.0)), u.x),
    u.y
  );
}

fn fbm(p: vec2f) -> f32 {
  var v = 0.0;
  var a = 0.5;
  var q = p;
  for (var i = 0; i < 5; i++) {
    v += a * noise2(q);
    q = q * 2.03 + vec2f(1.7, 9.2);
    a *= 0.5;
  }
  return v;
}

// 0 — Aurora: domain-warped flowing bands, teal into violet
fn aurora(p: vec2f, t: f32) -> vec3f {
  let q = vec2f(
    fbm(p * 1.6 + vec2f(0.0, t * 0.12)),
    fbm(p * 1.6 + vec2f(5.2, t * 0.10))
  );
  let bands = fbm(p * 2.2 + q * 2.6 + vec2f(0.0, -t * 0.28));
  let glow = smoothstep(0.32, 0.85, bands);
  let deep = vec3f(0.012, 0.030, 0.085);
  let teal = vec3f(0.05, 0.72, 0.60);
  let violet = vec3f(0.46, 0.22, 0.85);
  var col = mix(deep, teal, glow * 0.9);
  col = mix(col, violet, smoothstep(0.58, 1.0, bands) * 0.75);
  // curtain streaks rising
  let streak = fbm(vec2f(p.x * 7.0, p.y * 1.2 - t * 0.35));
  col += teal * smoothstep(0.55, 0.95, streak) * 0.35 * glow;
  return col;
}

// 1 — Magma: ridged plasma, ember heat
fn magma(p: vec2f, t: f32) -> vec3f {
  let n = fbm(p * 1.8 + vec2f(t * 0.10, -t * 0.16));
  let vein = 1.0 - abs(n - 0.5) * 2.0; // 1 along ridge centers
  let heat = smoothstep(0.58, 0.95, vein);
  let dark = vec3f(0.045, 0.010, 0.008);
  let ember_red = vec3f(0.50, 0.070, 0.020);
  let red = vec3f(0.72, 0.11, 0.030);
  let orange = vec3f(0.98, 0.40, 0.060);
  let yellow = vec3f(1.00, 0.86, 0.48);
  // dark cooling rock with faint warm breath
  var col = mix(dark, ember_red, smoothstep(0.10, 0.55, vein) * 0.8);
  col = mix(col, red, smoothstep(0.40, 0.66, heat));
  col = mix(col, orange, smoothstep(0.60, 0.82, heat));
  col = mix(col, yellow, smoothstep(0.80, 0.97, heat));
  // drifting embers
  let e = p * 26.0 + vec2f(0.0, -t * 2.2);
  let id = floor(e);
  let h = hash21(id);
  let ember = step(0.985, h) * smoothstep(0.30, 0.05, length(fract(e) - 0.5));
  col += vec3f(1.0, 0.55, 0.20) * ember * (0.5 + 0.5 * sin(t * 4.0 + h * 40.0));
  return col;
}

// 2 — Nebulosa: violet swirl with twinkling stars
fn nebula(p: vec2f, t: f32) -> vec3f {
  let r = length(p);
  let ang = atan2(p.y, p.x) + t * 0.05 + 2.6 / (r + 0.38);
  let sp = vec2f(cos(ang), sin(ang)) * r;
  let n = fbm(sp * 2.4 + vec2f(0.0, t * 0.05));
  let deep = vec3f(0.018, 0.010, 0.060);
  let violet = vec3f(0.40, 0.15, 0.72);
  let pink = vec3f(0.95, 0.36, 0.64);
  var col = mix(deep, violet, smoothstep(0.30, 0.80, n));
  col = mix(col, pink, smoothstep(0.60, 0.95, n) * 0.65);
  // starfield
  let g = p * 30.0;
  let id = floor(g);
  let h = hash21(id);
  let star = step(0.990, h) * smoothstep(0.38, 0.06, length(fract(g) - 0.5));
  let tw = 0.55 + 0.45 * sin(t * 3.0 + h * 40.0);
  col += vec3f(1.0, 0.96, 0.92) * star * tw;
  return col;
}

// 3 — Amanecer: golden horizon glow with soft rays
fn dawn(p: vec2f, t: f32) -> vec3f {
  let sunY = -0.30 + 0.05 * sin(t * 0.4);
  let d = length(vec2f(p.x * 0.72, p.y - sunY));
  let glow = exp(-d * 2.4);
  let top = vec3f(0.10, 0.14, 0.36);
  let mid = vec3f(0.82, 0.40, 0.24);
  let sun = vec3f(1.00, 0.80, 0.52);
  var col = mix(top, mid, smoothstep(0.95, -0.45, p.y));
  col = mix(col, sun, smoothstep(0.22, 0.95, glow));
  let rays = fbm(vec2f(atan2(p.y - sunY, p.x) * 5.0, t * 0.12)) * glow;
  col += vec3f(1.0, 0.68, 0.38) * rays * 0.38;
  // slow clouds
  let cl = fbm(p * vec2f(1.4, 3.2) + vec2f(t * 0.06, 0.0));
  col = mix(col, vec3f(0.98, 0.62, 0.42), smoothstep(0.55, 0.9, cl) * 0.35 * smoothstep(0.6, 0.0, p.y));
  return col;
}

fn scene(i: f32, p: vec2f, t: f32) -> vec3f {
  if (i < 0.5) {
    return aurora(p, t);
  }
  if (i < 1.5) {
    return magma(p, t);
  }
  if (i < 2.5) {
    return nebula(p, t);
  }
  return dawn(p, t);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let t = params.time;
  let s = clamp(params.scroll, 0.0, 3.0);
  var p = (uv - vec2f(0.5, 0.5)) * vec2f(params.aspect, 1.0) * 2.0;
  // gentle vertical drift as you scroll, so motion never stalls
  p = p + vec2f(0.0, s * 0.12);

  let i = floor(s);
  let f = smoothstep(0.0, 1.0, fract(s));
  let c0 = scene(i, p, t);
  let c1 = scene(i + 1.0, p, t);
  var col = mix(c0, c1, f);

  // vignette
  let vig = smoothstep(1.50, 0.40, length((uv - vec2f(0.5, 0.5)) * vec2f(params.aspect, 1.0)));
  col *= mix(0.72, 1.0, vig);
  // film grain
  let g = hash21(uv * vec2f(1920.0, 1080.0) + vec2f(fract(t) * 7.0, fract(t * 1.7) * 5.0)) - 0.5;
  col += g * 0.035;

  return vec4f(col, 1.0);
}
