'use strict';

// ── State ──────────────────────────────────────────────────────────────────────
const state = {
  visible: false,
  tool: 'coords',
  keyboardMode: false,

  coords: {
    player: { x: 0, y: 0, z: 0, h: 0 },
    cam:    { x: 0, y: 0, z: 0, rx: 0, ry: 0, rz: 0, fov: 50 },
  },

  placer: {
    active: false, model: '', mode: 'ped',
    x: 0, y: 0, z: 0, h: 0,
    step: 0.05,
    confirmed: null,
    error: null,
    pendingModel: '',
    pendingMode: 'ped',
  },

  camera: {
    active: false,
    x: 0, y: 0, z: 0, rx: 0, ry: 0, rz: 0, fov: 50,
  },

  inspector: {
    hit: false, entityType: 'NONE', model: '', netId: 0, networked: false,
    x: 0, y: 0, z: 0, h: 0,
    hx: 0, hy: 0, hz: 0,
    health: 0, maxHealth: 0, invincible: false,
    extra: {},
  },

  pedPresets: [],
  propPresets: [],
};

// ── Helpers ────────────────────────────────────────────────────────────────────
const $ = id => document.getElementById(id);

function post(name, body = {}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  }).then(r => r.json().catch(() => ({})));
}

function GetParentResourceName() {
  return window.GetParentResourceName?.() ?? 'nb-devtools';
}

async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const ta = document.createElement('textarea');
    ta.value = text;
    Object.assign(ta.style, { position: 'fixed', opacity: '0' });
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    document.body.removeChild(ta);
  }
  showToast();
}

let toastTimer = null;
function showToast() {
  const t = $('toast');
  t.classList.remove('hidden');
  requestAnimationFrame(() => t.classList.add('show'));
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    t.classList.remove('show');
    setTimeout(() => t.classList.add('hidden'), 200);
  }, 1200);
}

// Format helpers
const fv4  = (x, y, z, h) => `vec4(${x}, ${y}, ${z}, ${h})`;
const ftbl = (x, y, z, h) => `{ x = ${x}, y = ${y}, z = ${z}, w = ${h} }`;
const fv3  = (x, y, z)    => `vector3(${x}, ${y}, ${z})`;
const frot = (x, y, z)    => `vector3(${x}, ${y}, ${z})`;

// ── NUI message handler ────────────────────────────────────────────────────────
window.addEventListener('message', ({ data }) => {
  const { action } = data;

  if (action === 'open') {
    state.pedPresets  = data.data.pedPresets  || [];
    state.propPresets = data.data.propPresets || [];
    state.tool        = data.data.tool || 'coords';
    show();
    return;
  }

  if (action === 'close') { hide(); return; }

  if (action === 'update') {
    const d = data.data;
    if (d.tool === 'coords') {
      state.coords.player = d.player;
      state.coords.cam    = d.cam;
    } else if (d.tool === 'placer') {
      Object.assign(state.placer, { x: d.x, y: d.y, z: d.z, h: d.h, step: d.step });
    } else if (d.tool === 'camera') {
      Object.assign(state.camera, d);
    } else {
      // inspector: d has all fields at top level
      Object.assign(state.inspector, d);
    }
    if (state.visible && state.tool === d.tool) render();
    return;
  }

  if (action === 'placer_state') {
    const d = data.data;
    state.placer.active = d.active;
    if (d.active) {
      state.placer.model   = d.model;
      state.placer.mode    = d.mode;
      state.placer.x       = d.x || 0;
      state.placer.y       = d.y || 0;
      state.placer.z       = d.z || 0;
      state.placer.h       = d.h || 0;
      state.placer.error   = null;
      setKeyboardMode(true);
    } else {
      setKeyboardMode(false);
    }
    if (state.visible && state.tool === 'placer') render();
    return;
  }

  if (action === 'placer_confirmed') {
    state.placer.active    = false;
    state.placer.confirmed = data.data;
    setKeyboardMode(false);
    if (state.visible && state.tool === 'placer') render();
    return;
  }

  if (action === 'placer_error') {
    state.placer.active = false;
    state.placer.error  = data.data.msg;
    setKeyboardMode(false);
    if (state.visible && state.tool === 'placer') render();
    return;
  }

  if (action === 'camera_state') {
    state.camera.active = data.data.active;
    setKeyboardMode(data.data.active);
    if (state.visible && state.tool === 'camera') render();
    return;
  }
});

// ── Visibility ─────────────────────────────────────────────────────────────────
function show() {
  state.visible = true;
  $('app').classList.remove('hidden');
  activateTab(state.tool);
}

function hide() {
  state.visible = false;
  $('app').classList.add('hidden');
  setKeyboardMode(false);
}

function setKeyboardMode(on) {
  state.keyboardMode = on;
  const badge = $('keyboard-badge');
  if (on) badge.classList.remove('hidden');
  else    badge.classList.add('hidden');
}

// ── Tabs ───────────────────────────────────────────────────────────────────────
function activateTab(tool) {
  state.tool = tool;
  document.querySelectorAll('.tab').forEach(t => {
    t.classList.toggle('active', t.dataset.tool === tool);
  });
  post('setTool', { tool });
  render();
}

document.querySelectorAll('.tab').forEach(tab => {
  tab.addEventListener('click', () => activateTab(tab.dataset.tool));
});

// ── Panel drag ─────────────────────────────────────────────────────────────────
{
  const panel  = $('panel');
  const header = $('header');
  let drag = { on: false, sx: 0, sy: 0, sl: 0, st: 0 };

  header.addEventListener('mousedown', e => {
    const rect = $('app').getBoundingClientRect();
    drag = { on: true, sx: e.clientX, sy: e.clientY, sl: rect.left, st: rect.top };
    const app = $('app');
    app.style.right  = 'auto';
    app.style.bottom = 'auto';
    app.style.left   = rect.left + 'px';
    app.style.top    = rect.top  + 'px';
  });
  document.addEventListener('mousemove', e => {
    if (!drag.on) return;
    const app = $('app');
    app.style.left = (drag.sl + e.clientX - drag.sx) + 'px';
    app.style.top  = (drag.st + e.clientY - drag.sy) + 'px';
  });
  document.addEventListener('mouseup', () => { drag.on = false; });
}

// ── Close / reclaim focus ──────────────────────────────────────────────────────
$('btn-close').addEventListener('click', () => {
  hide();
  post('close');
});

$('btn-reclaim').addEventListener('click', () => {
  post('captureFocus');
  setKeyboardMode(false);
});

document.addEventListener('keyup', e => {
  if (e.key === 'Escape' && state.visible && !state.keyboardMode) {
    hide();
    post('close');
  }
});

// Clicking anywhere on the panel regains focus when in keyboard mode
$('panel').addEventListener('click', () => {
  if (state.keyboardMode) {
    post('captureFocus');
    setKeyboardMode(false);
  }
});

// ── Render ─────────────────────────────────────────────────────────────────────
function render() {
  const el = $('content');
  switch (state.tool) {
    case 'coords':    el.innerHTML = renderCoords();    break;
    case 'placer':    el.innerHTML = renderPlacer();    break;
    case 'camera':    el.innerHTML = renderCamera();    break;
    case 'inspector': el.innerHTML = renderInspector(); break;
    default: el.innerHTML = '';
  }
  attachHandlers();
}

// ── Copy helpers ───────────────────────────────────────────────────────────────
function copyBtn(id, getter) {
  return `<button class="btn btn-secondary" data-copy="${id}">Copy</button>`;
}

function attachHandlers() {
  document.querySelectorAll('[data-copy]').forEach(btn => {
    btn.addEventListener('click', () => {
      const key = btn.dataset.copy;
      const text = resolveCopy(key);
      if (text) copyText(text);
    });
  });

  // Placer
  const spawnBtn = $('btn-placer-spawn');
  if (spawnBtn) {
    spawnBtn.addEventListener('click', () => {
      const model = $('placer-model-input').value.trim();
      const mode  = state.placer.pendingMode || 'ped';
      if (!model) return;
      state.placer.pendingModel = model;
      post('placerSpawn', { model, mode });
    });
  }

  document.querySelectorAll('.mode-btn').forEach(b => {
    b.addEventListener('click', () => {
      state.placer.pendingMode = b.dataset.mode;
      document.querySelectorAll('.mode-btn').forEach(x => x.classList.remove('active'));
      b.classList.add('active');
    });
  });

  const presetSel = $('placer-preset-select');
  if (presetSel) {
    presetSel.addEventListener('change', () => {
      if (presetSel.value) {
        $('placer-model-input').value = presetSel.value;
        presetSel.value = '';
      }
    });
  }

  const confirmBtn = $('btn-placer-confirm');
  if (confirmBtn) confirmBtn.addEventListener('click', () => post('placerConfirm'));

  const cancelBtn = $('btn-placer-cancel');
  if (cancelBtn) cancelBtn.addEventListener('click', () => post('placerCancel'));

  // Step buttons
  const stepDown = $('step-down');
  const stepUp   = $('step-up');
  if (stepDown) stepDown.addEventListener('click', () => changeStep(-1));
  if (stepUp)   stepUp.addEventListener('click',   () => changeStep(1));

  // Camera toggle
  const camBtn = $('btn-camera-toggle');
  if (camBtn) camBtn.addEventListener('click', () => post('toggleCamera'));

  // Output boxes clickable = copy
  document.querySelectorAll('.output-box[data-copy]').forEach(box => {
    box.addEventListener('click', () => copyText(box.textContent));
  });
}

const STEPS = [0.001, 0.005, 0.01, 0.05, 0.1, 0.25, 0.5, 1.0];
function changeStep(dir) {
  const idx  = STEPS.indexOf(state.placer.step);
  const next = STEPS[Math.max(0, Math.min(STEPS.length - 1, idx + dir))];
  state.placer.step = next;
  post('placerSetStep', { step: next });
  render();
}

function resolveCopy(key) {
  const p = state.coords.player;
  const c = state.coords.cam;
  const pl = state.placer;
  const ca = state.camera;
  const ins = state.inspector;

  switch (key) {
    case 'player-vec4':  return fv4(p.x, p.y, p.z, p.h);
    case 'player-table': return ftbl(p.x, p.y, p.z, p.h);
    case 'player-v3':    return fv3(p.x, p.y, p.z);
    case 'player-raw':   return `${p.x}, ${p.y}, ${p.z}, ${p.h}`;
    case 'cam-pos':      return fv3(c.x, c.y, c.z);
    case 'cam-rot':      return frot(c.rx, c.ry, c.rz);
    case 'cam-fov':      return `${c.fov}`;
    case 'cam-all':      return `coords = ${fv3(c.x, c.y, c.z)}\nrot = ${frot(c.rx, c.ry, c.rz)}\nfov = ${c.fov}`;
    case 'placer-vec4':  return fv4(pl.x, pl.y, pl.z, pl.h);
    case 'placer-table': return ftbl(pl.x, pl.y, pl.z, pl.h);
    case 'freecam-pos':  return fv3(ca.x, ca.y, ca.z);
    case 'freecam-rot':  return frot(ca.rx, ca.ry, ca.rz);
    case 'freecam-all':  return `coords = ${fv3(ca.x, ca.y, ca.z)}\nrot = ${frot(ca.rx, ca.ry, ca.rz)}\nfov = ${ca.fov}`;
    case 'insp-model':   return ins.model;
    case 'insp-coords':  return fv4(ins.x, ins.y, ins.z, ins.h);
    case 'insp-hit':     return fv3(ins.hx, ins.hy, ins.hz);
    default: return null;
  }
}

// ── Tab renderers ──────────────────────────────────────────────────────────────

function renderCoords() {
  const p = state.coords.player;
  const c = state.coords.cam;
  return `
    <div class="section">
      <div class="section-title">Player Position</div>
      <div class="coord-grid">
        <span class="coord-label">X</span><span class="coord-value">${p.x}</span>
        <span class="coord-label">Y</span><span class="coord-value">${p.y}</span>
        <span class="coord-label">Z</span><span class="coord-value">${p.z}</span>
        <span class="coord-label">H</span><span class="coord-value">${p.h}</span>
      </div>
      <div class="output-box" data-copy>${fv4(p.x, p.y, p.z, p.h)}</div>
      <div class="btn-row">
        <button class="btn btn-secondary" data-copy="player-vec4">vec4</button>
        <button class="btn btn-secondary" data-copy="player-table">table</button>
        <button class="btn btn-secondary" data-copy="player-v3">vector3</button>
        <button class="btn btn-secondary" data-copy="player-raw">raw</button>
      </div>
    </div>

    <div class="divider"></div>

    <div class="section">
      <div class="section-title">Camera</div>
      <div class="coord-grid">
        <span class="coord-label">X</span><span class="coord-value cam">${c.x}</span>
        <span class="coord-label">Y</span><span class="coord-value cam">${c.y}</span>
        <span class="coord-label">Z</span><span class="coord-value cam">${c.z}</span>
        <span class="coord-label">FOV</span><span class="coord-value cam">${c.fov}</span>
        <span class="coord-label">RX</span><span class="coord-value cam">${c.rx}</span>
        <span class="coord-label">RY</span><span class="coord-value cam">${c.ry}</span>
        <span class="coord-label">RZ</span><span class="coord-value cam">${c.rz}</span>
      </div>
      <div class="btn-row">
        <button class="btn btn-secondary" data-copy="cam-pos">Pos</button>
        <button class="btn btn-secondary" data-copy="cam-rot">Rot</button>
        <button class="btn btn-secondary" data-copy="cam-fov">FOV</button>
        <button class="btn btn-secondary" data-copy="cam-all">All</button>
      </div>
    </div>
  `;
}

function renderPlacer() {
  const pl = state.placer;
  const presets = pl.pendingMode === 'prop' ? state.propPresets : state.pedPresets;
  const presetOptions = presets.map(p =>
    `<option value="${p.model}">${p.label}</option>`
  ).join('');

  const confirmedBlock = pl.confirmed ? `
    <div class="divider"></div>
    <div class="section">
      <div class="section-title">Last Confirmed</div>
      <div class="coord-grid">
        <span class="coord-label">X</span><span class="coord-value">${pl.confirmed.x}</span>
        <span class="coord-label">Y</span><span class="coord-value">${pl.confirmed.y}</span>
        <span class="coord-label">Z</span><span class="coord-value">${pl.confirmed.z}</span>
        <span class="coord-label">H</span><span class="coord-value">${pl.confirmed.h}</span>
      </div>
      <div class="output-box" data-copy>${fv4(pl.confirmed.x, pl.confirmed.y, pl.confirmed.z, pl.confirmed.h)}</div>
      <div class="btn-row">
        <button class="btn btn-secondary" data-copy="placer-vec4">vec4</button>
        <button class="btn btn-secondary" data-copy="placer-table">table</button>
      </div>
    </div>
  ` : '';

  const activeBlock = pl.active ? `
    <div class="divider"></div>
    <div class="section">
      <div class="section-title">Live Position</div>
      <div class="coord-grid">
        <span class="coord-label">X</span><span class="coord-value">${pl.x}</span>
        <span class="coord-label">Y</span><span class="coord-value">${pl.y}</span>
        <span class="coord-label">Z</span><span class="coord-value">${pl.z}</span>
        <span class="coord-label">H</span><span class="coord-value">${pl.h}</span>
      </div>
      <div class="step-control">
        <span class="info-label">Step</span>
        <button class="step-btn" id="step-down">−</button>
        <span class="step-value">${pl.step}</span>
        <button class="step-btn" id="step-up">+</button>
      </div>
      <div class="btn-row" style="margin-top:4px">
        <button class="btn btn-success" id="btn-placer-confirm">Confirm &amp; Copy</button>
        <button class="btn btn-danger"  id="btn-placer-cancel">Cancel</button>
      </div>
    </div>
  ` : '';

  const errorBlock = pl.error ? `
    <div class="output-box empty">${pl.error}</div>
  ` : '';

  return `
    <div class="section">
      <div class="section-title">Mode</div>
      <div class="mode-toggle">
        <button class="mode-btn ${pl.pendingMode !== 'prop' ? 'active' : ''}" data-mode="ped">Ped / NPC</button>
        <button class="mode-btn ${pl.pendingMode === 'prop' ? 'active' : ''}" data-mode="prop">Prop / Object</button>
      </div>
    </div>

    <div class="section">
      <div class="section-title">Model</div>
      <div class="input-row">
        <input id="placer-model-input" class="input-text" type="text"
               placeholder="e.g. mp_m_freemode_01"
               value="${pl.pendingModel || ''}">
      </div>
      <div class="input-row">
        <select id="placer-preset-select" class="select-input" style="flex:1">
          <option value="">— Quick presets —</option>
          ${presetOptions}
        </select>
      </div>
    </div>

    <div class="section">
      <div class="status-row">
        <span class="status-dot ${pl.active ? 'active' : ''}"></span>
        <span class="status-label">${pl.active ? 'ACTIVE — use keyboard to position' : 'INACTIVE'}</span>
      </div>
      ${!pl.active ? `<button class="btn btn-primary btn-full" id="btn-placer-spawn">Spawn Entity</button>` : ''}
    </div>

    ${errorBlock}
    ${activeBlock}
    ${confirmedBlock}

    <div class="section">
      <div class="controls-hint">
        <span>WASD</span> Move · <span>Space/Ctrl</span> Z · <span>← →</span> Rotate<br>
        <span>Shift</span> Fast · <span>Enter</span> Confirm · <span>Backspace</span> Cancel
      </div>
    </div>
  `;
}

function renderCamera() {
  const ca = state.camera;
  const btnLabel = ca.active ? 'Deactivate Free Camera' : 'Activate Free Camera';
  const btnClass = ca.active ? 'btn-danger' : 'btn-primary';

  return `
    <div class="section">
      <div class="status-row">
        <span class="status-dot ${ca.active ? 'active' : ''}"></span>
        <span class="status-label">${ca.active ? 'FREE CAM ACTIVE' : 'INACTIVE'}</span>
      </div>
      <button class="btn ${btnClass} btn-full" id="btn-camera-toggle">${btnLabel}</button>
    </div>

    <div class="divider"></div>

    <div class="section">
      <div class="section-title">Position</div>
      <div class="coord-grid">
        <span class="coord-label">X</span><span class="coord-value cam">${ca.x}</span>
        <span class="coord-label">Y</span><span class="coord-value cam">${ca.y}</span>
        <span class="coord-label">Z</span><span class="coord-value cam">${ca.z}</span>
        <span class="coord-label">FOV</span><span class="coord-value cam">${ca.fov}</span>
      </div>
    </div>

    <div class="section">
      <div class="section-title">Rotation</div>
      <div class="coord-grid">
        <span class="coord-label">RX</span><span class="coord-value cam">${ca.rx}</span>
        <span class="coord-label">RY</span><span class="coord-value cam">${ca.ry}</span>
        <span class="coord-label">RZ</span><span class="coord-value cam">${ca.rz}</span>
      </div>
    </div>

    <div class="btn-row">
      <button class="btn btn-secondary" data-copy="freecam-pos">Copy Pos</button>
      <button class="btn btn-secondary" data-copy="freecam-rot">Copy Rot</button>
      <button class="btn btn-secondary" data-copy="freecam-all">Copy All</button>
    </div>

    <div class="section">
      <div class="output-box" data-copy>${fv3(ca.x, ca.y, ca.z)}</div>
    </div>

    <div class="section">
      <div class="controls-hint">
        <span>WASD</span> Move · <span>Space/Ctrl</span> Up/Down · <span>Shift</span> Fast<br>
        <span>Mouse</span> Look · <span>Scroll</span> FOV · <span>Backspace</span> Exit
      </div>
    </div>
  `;
}

function renderInspector() {
  const ins = state.inspector;
  const typeClass = `entity-${ins.entityType.toLowerCase()}`;
  const hpPct = ins.maxHealth > 0
    ? Math.round((ins.health / ins.maxHealth) * 100)
    : 0;

  const extraRows = ins.entityType === 'VEHICLE' && ins.extra ? `
    <div class="info-row">
      <span class="info-label">Plate</span>
      <span class="info-value highlight">${ins.extra.plate || '—'}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Speed</span>
      <span class="info-value">${ins.extra.speed || 0} km/h</span>
    </div>
  ` : '';

  const entityBlock = ins.hit ? `
    <div class="divider"></div>
    <div class="section">
      <div class="section-title">Entity</div>
      <div class="info-row">
        <span class="info-label">Type</span>
        <span class="info-value ${typeClass}">${ins.entityType}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Model</span>
        <span class="info-value highlight">${ins.model}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Net ID</span>
        <span class="info-value">${ins.networked ? ins.netId : '(local)'}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Health</span>
        <span class="info-value">${ins.health} / ${ins.maxHealth} (${hpPct}%)</span>
      </div>
      <div class="info-row">
        <span class="info-label">Invincible</span>
        <span class="info-value ${ins.invincible ? 'entity-vehicle' : ''}">${ins.invincible ? 'YES' : 'NO'}</span>
      </div>
      ${extraRows}
    </div>

    <div class="divider"></div>

    <div class="section">
      <div class="section-title">Entity Position</div>
      <div class="coord-grid">
        <span class="coord-label">X</span><span class="coord-value">${ins.x}</span>
        <span class="coord-label">Y</span><span class="coord-value">${ins.y}</span>
        <span class="coord-label">Z</span><span class="coord-value">${ins.z}</span>
        <span class="coord-label">H</span><span class="coord-value">${ins.h}</span>
      </div>
      <div class="btn-row">
        <button class="btn btn-secondary" data-copy="insp-model">Model Hash</button>
        <button class="btn btn-secondary" data-copy="insp-coords">Coords</button>
      </div>
    </div>
  ` : `
    <div class="section">
      <div class="status-row">
        <span class="status-dot"></span>
        <span class="status-label">No entity in crosshair</span>
      </div>
    </div>
  `;

  return `
    <div class="section">
      <div class="section-title">Raycast Target</div>
      <div class="coord-grid">
        <span class="coord-label">X</span><span class="coord-value cam">${ins.hx}</span>
        <span class="coord-label">Y</span><span class="coord-value cam">${ins.hy}</span>
        <span class="coord-label">Z</span><span class="coord-value cam">${ins.hz}</span>
      </div>
      <div class="btn-row">
        <button class="btn btn-secondary" data-copy="insp-hit">Copy Hit Pos</button>
      </div>
    </div>

    ${entityBlock}

    <div class="section">
      <div class="controls-hint">
        Aim your crosshair at any entity.<br>
        Updates automatically every 300ms.
      </div>
    </div>
  `;
}

// ── Initial render ─────────────────────────────────────────────────────────────
render();
