/* Motor do editor de mapas mentais da Boha: estrutura, layouts, texto/outline, exportação e modelos.
   Sem dependência de tela: roda no navegador e no Node (para testes). */
(function (root) {
'use strict';
const MM = {};
MM.FONT = 'system-ui,-apple-system,"Segoe UI",Roboto,Arial,sans-serif';
MM.LAYOUTS = { both: 'Dos dois lados', right: 'Para a direita', left: 'Para a esquerda', down: 'Para baixo', radial: 'Radial', free: 'Livre (posição manual)' };
MM.SHAPES = { round: 'Arredondado', pill: 'Pílula', rect: 'Retângulo', ellipse: 'Elipse', diamond: 'Losango', line: 'Sublinhado', text: 'Só texto' };
MM.LINES = { curve: 'Curva', elbow: 'Em ângulo', straight: 'Reta' };
MM.THEMES = {
  boha:   { name: 'Boha',   bg: '#0f0f0f', grid: '#202020', text: '#f2f2f2', root: '#fff000', rootText: '#111111', palette: ['#fff000', '#4da3ff', '#2fd39a', '#ff8a4c', '#b88cff', '#ff5d8f', '#6ee7ff', '#9be15d'] },
  claro:  { name: 'Claro',  bg: '#fafaf8', grid: '#e6e6e1', text: '#1b1b1b', root: '#1b1b1b', rootText: '#ffffff', palette: ['#e6a700', '#2b7de9', '#14a87a', '#e8651d', '#8a5cf5', '#e0347a', '#0fa3b8', '#6aa81f'] },
  oceano: { name: 'Oceano', bg: '#0b1d2c', grid: '#13304a', text: '#e8f4ff', root: '#38bdf8', rootText: '#06202f', palette: ['#38bdf8', '#34d399', '#a78bfa', '#fbbf24', '#f472b6', '#60a5fa', '#22d3ee', '#fb923c'] },
  pastel: { name: 'Pastel', bg: '#fdf6ef', grid: '#efe3d6', text: '#3a2f2a', root: '#ff9f80', rootText: '#3a2f2a', palette: ['#ffb4a2', '#a8d8ea', '#b5e5cf', '#ffd6a5', '#cdb4db', '#ffc8dd', '#bde0fe', '#d4e09b'] },
  mono:   { name: 'Mono',   bg: '#ffffff', grid: '#ececec', text: '#222222', root: '#111111', rootText: '#ffffff', palette: ['#333333', '#666666', '#888888', '#444444', '#777777', '#555555', '#999999', '#222222'] },
  neon:   { name: 'Neon',   bg: '#0a0a14', grid: '#181830', text: '#f0f0ff', root: '#00f5d4', rootText: '#001a16', palette: ['#00f5d4', '#f15bb5', '#fee440', '#9b5de5', '#00bbf9', '#ff6b6b', '#7bf1a8', '#ff9e00'] }
};
MM.ICONS = ['⭐', '🔥', '💡', '🎯', '✅', '⚠️', '❓', '❗', '📅', '📣', '🎬', '📸', '🖼️', '✍️', '💰', '👥', '📈', '🏆', '❤️', '🚀', '🔒', '📌', '🧩', '⏰'];
MM.PRI_COLORS = ['#ff4d4d', '#ff9f2e', '#ffd93d', '#4da3ff', '#9aa0a6'];

let _uid = 0;
MM.uid = () => 'n' + Math.random().toString(36).slice(2, 8) + (++_uid).toString(36);

/* ---------- medição de texto ---------- */
let measureFn = (text, fs, bold) => String(text).length * fs * (bold ? 0.6 : 0.54);
MM.setMeasurer = fn => { measureFn = fn; cache.clear(); };
const cache = new Map();
function tw(text, fs, bold, italic) {
  const k = fs + (bold ? 'b' : '') + (italic ? 'i' : '') + '|' + text;
  let v = cache.get(k);
  if (v === undefined) { v = measureFn(text, fs, bold, italic); if (cache.size > 6000) cache.clear(); cache.set(k, v); }
  return v;
}
function wrap(text, maxW, fs, bold, italic) {
  const out = [];
  String(text || '').split('\n').forEach(par => {
    const words = par.split(/\s+/).filter(Boolean);
    if (!words.length) { out.push(''); return; }
    let cur = '';
    const flush = () => { if (cur) out.push(cur); cur = ''; };
    words.forEach(w => {
      while (tw(w, fs, bold, italic) > maxW && w.length > 1) { // palavra maior que a linha: quebra por caracteres
        let i = w.length - 1;
        while (i > 1 && tw(w.slice(0, i), fs, bold, italic) > maxW) i--;
        flush(); out.push(w.slice(0, i)); w = w.slice(i);
      }
      const t = cur ? cur + ' ' + w : w;
      if (tw(t, fs, bold, italic) <= maxW || !cur) cur = t; else { flush(); cur = w; }
    });
    flush();
  });
  return out.length ? out : [''];
}

/* ---------- documento ---------- */
MM.newDoc = function (title) {
  return { v: 1, root: 'root', nodes: { root: { id: 'root', parent: null, text: title || 'Ideia central', children: [] } }, links: [], groups: [],
    settings: { layout: 'both', theme: 'boha', line: 'curve', lineW: 2, grid: true, branchColors: true } };
};
MM.count = doc => Object.keys(doc.nodes).length;
const clampStr = (s, n) => String(s == null ? '' : s).slice(0, n);
const okUrl = u => { try { const x = new URL(String(u).trim()); return (x.protocol === 'https:' || x.protocol === 'http:') ? x.href : ''; } catch (e) { return ''; } };
MM.okUrl = okUrl;

/* Valida e normaliza um documento vindo do banco/arquivo */
MM.sanitize = function (raw) {
  if (!raw || typeof raw !== 'object' || !raw.nodes || typeof raw.nodes !== 'object') throw new Error('Arquivo de mapa inválido.');
  const doc = MM.newDoc('');
  const ids = Object.keys(raw.nodes).slice(0, 5000);
  const N = {};
  ids.forEach(id => {
    const r = raw.nodes[id]; if (!r || typeof r !== 'object') return;
    const st = r.style && typeof r.style === 'object' ? r.style : {};
    const n = { id, parent: r.parent && raw.nodes[r.parent] ? String(r.parent) : null, text: clampStr(r.text, 2000), children: [] };
    if (r.collapsed) n.collapsed = true;
    if (r.side === 'l' || r.side === 'r') n.side = r.side;
    if (isFinite(r.x) && isFinite(r.y)) { n.x = +r.x; n.y = +r.y; }
    const s = {};
    if (MM.SHAPES[st.shape]) s.shape = st.shape;
    ['fill', 'stroke', 'color'].forEach(k => { if (/^#[0-9a-f]{6}$/i.test(st[k] || '')) s[k] = st[k]; });
    if (isFinite(st.fs) && st.fs >= 8 && st.fs <= 60) s.fs = +st.fs;
    if (st.b === true || st.b === false) s.b = st.b;
    if (st.i === true) s.i = true;
    if (isFinite(st.w) && st.w >= 80 && st.w <= 700) s.w = +st.w;
    if (isFinite(st.sw) && st.sw >= 0 && st.sw <= 8) s.sw = +st.sw;
    if (Object.keys(s).length) n.style = s;
    if (typeof r.icon === 'string' && r.icon) n.icon = clampStr(r.icon, 8);
    if (isFinite(r.pri) && r.pri >= 1 && r.pri <= 5) n.pri = Math.round(r.pri);
    if (isFinite(r.prog) && r.prog >= 0 && r.prog <= 100) n.prog = Math.round(r.prog);
    if (r.task) { n.task = true; if (r.done) n.done = true; }
    if (Array.isArray(r.tags)) n.tags = r.tags.map(t => clampStr(t, 24).trim()).filter(Boolean).slice(0, 8);
    if (r.note) n.note = clampStr(r.note, 6000);
    if (r.link && okUrl(r.link)) n.link = okUrl(r.link);
    N[id] = n;
  });
  // acha a raiz e reconstrói filhos respeitando a ordem original
  let rootId = N[raw.root] && !N[raw.root].parent ? raw.root : ids.find(id => N[id] && !N[id].parent);
  if (!rootId) throw new Error('Mapa sem tópico central.');
  ids.forEach(id => { const r = raw.nodes[id]; if (!N[id]) return;
    (Array.isArray(r.children) ? r.children : []).forEach(c => { if (N[c] && N[c].parent === id && !N[id].children.includes(c)) N[id].children.push(c); }); });
  // órfãos viram tópicos flutuantes; ciclos são cortados
  ids.forEach(id => { const n = N[id]; if (!n) return; const seen = new Set(); let p = n.parent; while (p) { if (seen.has(p) || p === id) { n.parent = null; break; } seen.add(p); p = N[p] && N[p].parent; } });
  ids.forEach(id => { const n = N[id]; if (n && n.parent && !N[n.parent].children.includes(id)) N[n.parent].children.push(id); });
  ids.forEach(id => { const n = N[id]; if (n && n.parent === null && id !== rootId && n.x === undefined) { n.x = 0; n.y = 0; } });
  doc.nodes = N; doc.root = rootId;
  const S = raw.settings || {};
  doc.settings = {
    layout: MM.LAYOUTS[S.layout] ? S.layout : 'both', theme: MM.THEMES[S.theme] ? S.theme : 'boha', line: MM.LINES[S.line] ? S.line : 'curve',
    lineW: isFinite(S.lineW) ? Math.max(1, Math.min(6, +S.lineW)) : 2, grid: S.grid !== false, branchColors: S.branchColors !== false
  };
  doc.links = (Array.isArray(raw.links) ? raw.links : []).filter(l => l && N[l.from] && N[l.to] && l.from !== l.to).slice(0, 1000)
    .map(l => ({ id: clampStr(l.id || MM.uid(), 20), from: l.from, to: l.to, label: clampStr(l.label, 80), color: /^#[0-9a-f]{6}$/i.test(l.color || '') ? l.color : '', dash: l.dash !== false }));
  doc.groups = (Array.isArray(raw.groups) ? raw.groups : []).map(g => ({ id: clampStr(g && g.id || MM.uid(), 20), ids: ((g && g.ids) || []).filter(i => N[i]), label: clampStr(g && g.label, 60), color: /^#[0-9a-f]{6}$/i.test((g && g.color) || '') ? g.color : '' }))
    .filter(g => g.ids.length).slice(0, 200);
  return doc;
};

/* ---------- operações na árvore ---------- */
MM.descendants = function (doc, id, out) {
  out = out || []; (doc.nodes[id] ? doc.nodes[id].children : []).forEach(c => { out.push(c); MM.descendants(doc, c, out); }); return out;
};
MM.isAncestor = function (doc, anc, id) { let p = doc.nodes[id] && doc.nodes[id].parent; while (p) { if (p === anc) return true; p = doc.nodes[p].parent; } return false; };
MM.roots = doc => [doc.root].concat(Object.keys(doc.nodes).filter(id => id !== doc.root && !doc.nodes[id].parent));
MM.depthOf = (doc, id) => { let d = 0, p = doc.nodes[id] && doc.nodes[id].parent; while (p) { d++; p = doc.nodes[p].parent; } return d; };

MM.addChild = function (doc, pid, text, index) {
  const p = doc.nodes[pid]; if (!p) return null;
  const id = MM.uid(); doc.nodes[id] = { id, parent: pid, text: text || '', children: [] };
  if (index == null || index >= p.children.length) p.children.push(id); else p.children.splice(Math.max(0, index), 0, id);
  p.collapsed = false;
  return id;
};
MM.addSibling = function (doc, id, after, text) {
  const n = doc.nodes[id]; if (!n) return null;
  if (!n.parent) return MM.addChild(doc, id, text);
  const p = doc.nodes[n.parent], i = p.children.indexOf(id);
  return MM.addChild(doc, n.parent, text, i + (after === false ? 0 : 1));
};
MM.addFloating = function (doc, x, y, text) {
  const id = MM.uid(); doc.nodes[id] = { id, parent: null, text: text || '', children: [], x, y }; return id;
};
MM.removeNodes = function (doc, ids) {
  const set = new Set(ids.filter(i => i !== doc.root && doc.nodes[i]));
  const top = [...set].filter(i => { let p = doc.nodes[i].parent; while (p) { if (set.has(p)) return false; p = doc.nodes[p].parent; } return true; });
  const gone = new Set();
  top.forEach(i => {
    const n = doc.nodes[i];
    if (n.parent) { const p = doc.nodes[n.parent]; p.children = p.children.filter(c => c !== i); }
    [i].concat(MM.descendants(doc, i)).forEach(d => gone.add(d));
  });
  gone.forEach(d => { delete doc.nodes[d]; });
  doc.links = doc.links.filter(l => !gone.has(l.from) && !gone.has(l.to));
  doc.groups.forEach(g => { g.ids = g.ids.filter(i => !gone.has(i)); });
  doc.groups = doc.groups.filter(g => g.ids.length);
  return top.length;
};
/* move um tópico (com os filhos) para outro pai e posição; newParent=null vira tópico flutuante em (x,y) */
MM.move = function (doc, id, newParent, index, x, y) {
  const n = doc.nodes[id]; if (!n || id === doc.root) return false;
  if (newParent) { if (newParent === id || MM.isAncestor(doc, id, newParent) || !doc.nodes[newParent]) return false; }
  let oi = -1;
  if (n.parent) { const op = doc.nodes[n.parent]; oi = op.children.indexOf(id); op.children.splice(oi, 1); if (op.id === newParent && index != null && oi < index) index--; }
  n.parent = newParent || null;
  if (newParent) {
    const p = doc.nodes[newParent];
    if (index == null || index >= p.children.length) p.children.push(id); else p.children.splice(Math.max(0, index), 0, id);
    p.collapsed = false; delete n.x; delete n.y;
  } else { n.x = x || 0; n.y = y || 0; }
  return true;
};
MM.reorder = function (doc, id, delta) {
  const n = doc.nodes[id]; if (!n || !n.parent) return false;
  const p = doc.nodes[n.parent], i = p.children.indexOf(id), j = i + delta;
  if (j < 0 || j >= p.children.length) return false;
  p.children.splice(i, 1); p.children.splice(j, 0, id); return true;
};
const COPY_KEYS = ['text', 'collapsed', 'style', 'icon', 'pri', 'prog', 'task', 'done', 'tags', 'note', 'link', 'side'];
MM.extract = function (doc, ids) {
  const set = new Set(ids);
  const top = ids.filter(i => doc.nodes[i] && (() => { let p = doc.nodes[i].parent; while (p) { if (set.has(p)) return false; p = doc.nodes[p].parent; } return true; })());
  const rec = id => { const n = doc.nodes[id], o = {}; COPY_KEYS.forEach(k => { if (n[k] !== undefined) o[k] = JSON.parse(JSON.stringify(n[k])); }); o.children = n.children.map(rec); return o; };
  return { boha: 'mm1', trees: top.map(rec) };
};
MM.insert = function (doc, pid, payload, index) {
  const out = [];
  const rec = (t, parent, idx) => {
    const id = MM.uid(); const n = { id, parent, text: clampStr(t.text, 2000), children: [] };
    COPY_KEYS.forEach(k => { if (k !== 'text' && t[k] !== undefined) n[k] = JSON.parse(JSON.stringify(t[k])); });
    doc.nodes[id] = n;
    if (parent) { const p = doc.nodes[parent]; if (idx == null || idx >= p.children.length) p.children.push(id); else p.children.splice(idx, 0, id); p.collapsed = false; }
    (t.children || []).forEach(c => rec(c, id));
    return id;
  };
  (payload.trees || []).forEach((t, k) => out.push(rec(t, pid, index == null ? null : index + k)));
  return out;
};
MM.duplicate = function (doc, id) {
  const n = doc.nodes[id]; if (!n || !n.parent) return null;
  const p = doc.nodes[n.parent], i = p.children.indexOf(id);
  return MM.insert(doc, n.parent, MM.extract(doc, [id]), i + 1)[0];
};

/* ---------- texto/outline ---------- */
MM.toOutline = function (doc, ids) {
  const lines = [];
  const rec = (id, lvl) => { const n = doc.nodes[id]; const t = (n.text || '').replace(/\n+/g, ' ').trim() || 'Tópico';
    lines.push('  '.repeat(lvl) + '- ' + (n.task ? (n.done ? '[x] ' : '[ ] ') : '') + t); n.children.forEach(c => rec(c, lvl + 1)); };
  if (!ids) { lines.push('# ' + ((doc.nodes[doc.root].text || 'Mapa').replace(/\n+/g, ' ').trim() || 'Mapa')); doc.nodes[doc.root].children.forEach(c => rec(c, 0)); }
  else ids.forEach(i => rec(i, 0));
  return lines.join('\n');
};
/* converte texto em árvore [{text,children,task,done}] ; devolve {title, trees} */
MM.parseOutline = function (text) {
  const rows = [];
  String(text || '').replace(/\r/g, '').split('\n').forEach(raw => {
    if (!raw.trim()) return;
    let h = raw.match(/^\s{0,3}(#{1,6})\s+(.*)$/), lvlHead = null, indent = 0, body;
    if (h) { lvlHead = h[1].length; body = h[2]; }
    else {
      const m = raw.match(/^(\s*)(?:[-*+•–]|\d+[.)])?\s*(.*)$/);
      const ws = m[1].replace(/\t/g, '    '); indent = ws.length; body = m[2];
    }
    body = body.trim(); if (!body) return;
    let task = null, done = false;
    const tm = body.match(/^\[( |x|X)\]\s+(.*)$/); if (tm) { task = true; done = tm[1] !== ' '; body = tm[2].trim(); }
    rows.push({ head: lvlHead, indent, text: clampStr(body, 2000), task, done });
  });
  // níveis: cabeçalho # = 0, ## = 1…; itens indentados ficam abaixo do último cabeçalho
  let base = 0, stack = [], title = null;
  const items = [];
  let curHead = -1;
  rows.forEach(r => {
    if (r.head) { curHead = r.head - 1; stack = []; items.push({ lvl: curHead, r }); return; }
    while (stack.length && stack[stack.length - 1] >= r.indent) stack.pop();
    const lvl = (curHead + 1) + stack.length; stack.push(r.indent);
    items.push({ lvl, r });
  });
  if (!items.length) return { title: null, trees: [] };
  // se há exatamente um item de nível 0 e é cabeçalho, ele é a raiz
  const zeros = items.filter(i => i.lvl === 0);
  let shift = 0;
  if (zeros.length === 1 && items[0].lvl === 0 && items[0].r.head) { title = items[0].r.text; shift = 1; items.shift(); }
  const trees = [], path = [];
  items.forEach(it => {
    const lvl = Math.max(0, it.lvl - shift);
    const node = { text: it.r.text, children: [] }; if (it.r.task) { node.task = true; if (it.r.done) node.done = true; }
    const useLvl = Math.min(lvl, path.length);
    path.length = useLvl; if (useLvl === 0) trees.push(node); else path[useLvl - 1].children.push(node);
    path.push(node);
  });
  return { title, trees };
};
MM.fromTree = function (trees, title, settings) {
  const doc = MM.newDoc(title || 'Ideia central');
  if (settings) Object.assign(doc.settings, settings);
  const rec = (t, parent) => { const id = MM.addChild(doc, parent, t.text); const n = doc.nodes[id];
    ['icon', 'pri', 'prog', 'task', 'done', 'tags', 'note', 'link', 'style', 'collapsed'].forEach(k => { if (t[k] !== undefined) n[k] = t[k]; });
    (t.children || []).forEach(c => rec(c, id)); };
  trees.forEach(t => rec(t, doc.root));
  return doc;
};

/* ---------- busca ---------- */
const fold = s => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
MM.search = function (doc, q) {
  q = fold(q).trim(); if (!q) return [];
  return Object.keys(doc.nodes).filter(id => { const n = doc.nodes[id]; return fold(n.text).includes(q) || fold(n.note).includes(q) || (n.tags || []).some(t => fold(t).includes(q)); });
};

/* ---------- cores ---------- */
const hex2 = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const toHex = a => '#' + a.map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
MM.mix = (c1, c2, t) => { const a = hex2(c1), b = hex2(c2); return toHex(a.map((v, i) => v * t + b[i] * (1 - t))); };
MM.contrast = h => { const [r, g, b] = hex2(h); return (0.299 * r + 0.587 * g + 0.114 * b) > 150 ? '#111111' : '#ffffff'; };

MM.look = function (doc, n, l) {
  const th = MM.THEMES[doc.settings.theme] || MM.THEMES.boha, st = n.style || {};
  let fill, stroke = null, sw = 0, text, shape = 'round', fs = 14, bold = false;
  const pal = th.palette, col = doc.settings.branchColors ? pal[(l.bi || 0) % pal.length] : pal[0];
  if (l.depth === 0) { fill = th.root; text = th.rootText; fs = 20; bold = true; shape = 'pill'; }
  else if (l.depth === 1) { fill = col; text = MM.contrast(col); fs = 16; bold = true; }
  else { fill = MM.mix(col, th.bg, 0.16); stroke = col; sw = 1.4; text = th.text; }
  if (st.shape) shape = st.shape;
  if (st.fill) { fill = st.fill; text = MM.contrast(st.fill); }
  if (st.stroke) { stroke = st.stroke; sw = sw || 1.6; }
  if (st.sw != null) sw = st.sw;
  if (st.color) text = st.color;
  if (st.fs) fs = st.fs;
  if (st.b != null) bold = st.b;
  if (shape === 'text' || shape === 'line') { if (!st.fill) { fill = 'none'; if (!st.color) text = th.text; } }
  return { fill, stroke, sw, text, shape, fs, bold, italic: !!st.i, col };
};

/* ---------- tamanho dos nós ---------- */
function sizeOf(doc, n, depth, bi) {
  const lk = MM.look(doc, n, { depth, bi });
  const prefix = (n.icon ? 24 : 0) + (n.task ? 22 : 0), suffix = n.pri ? 24 : 0;
  const maxW = (n.style && n.style.w) || (depth === 0 ? 300 : 260);
  const shapeK = lk.shape === 'ellipse' ? 1.28 : lk.shape === 'diamond' ? 1.5 : 1;
  const lines = wrap(n.text, Math.max(60, maxW - prefix - suffix - 24), lk.fs, lk.bold, lk.italic);
  let textW = 0; lines.forEach(s => { textW = Math.max(textW, tw(s, lk.fs, lk.bold, lk.italic)); });
  if (!n.text) textW = tw('Tópico', lk.fs, lk.bold, lk.italic);
  const lh = Math.round(lk.fs * 1.32);
  let extra = 0, tagsW = 0;
  if (n.tags && n.tags.length) { extra += 22; tagsW = n.tags.reduce((a, t) => a + tw(t, 10, true) + 14, 0) + (n.tags.length - 1) * 4; }
  if (n.prog != null) extra += 9;
  let w = Math.max(44, Math.max(textW + prefix + suffix + 24, tagsW + 24));
  let h = lines.length * lh + (lk.shape === 'line' ? 10 : 18) + extra;
  w *= shapeK; h *= (lk.shape === 'ellipse' ? 1.18 : lk.shape === 'diamond' ? 1.45 : 1);
  return { w: Math.round(w), h: Math.round(h), lines, lh, prefix, suffix, extra, tagsW, lk };
}

/* ---------- layout ---------- */
const VG = 12;
MM.layout = function (doc) {
  const N = doc.nodes, S = doc.settings, mode = S.layout || 'both', L = {};
  const roots = MM.roots(doc);
  const walk = (id, depth, bi) => {
    const n = N[id]; L[id] = Object.assign({ id, depth, bi, x: 0, y: 0, side: 'r' }, sizeOf(doc, n, depth, bi));
    if (!n.collapsed) n.children.forEach((c, i) => walk(c, depth + 1, depth === 0 ? i : bi));
  };
  walk(doc.root, 0, 0);
  const nRootKids = N[doc.root].children.length;
  roots.slice(1).forEach((r, j) => walk(r, 1, nRootKids + j));
  const kidsOf = id => (N[id].collapsed ? [] : N[id].children);
  const hg = d => d === 0 ? 74 : 50;

  const sh = id => { const l = L[id]; if (l.sh != null) return l.sh; let t = 0; const k = kidsOf(id); k.forEach((c, i) => { t += sh(c) + (i ? VG : 0); }); return l.sh = Math.max(l.h, t); };
  const placeH = (id, edge, cy, dir) => {
    const l = L[id]; l.side = dir > 0 ? 'r' : 'l'; l.x = dir > 0 ? edge : edge - l.w; l.y = cy - l.h / 2;
    const k = kidsOf(id); if (!k.length) return;
    let total = 0; k.forEach((c, i) => { total += sh(c) + (i ? VG : 0); });
    let y = cy - total / 2;
    k.forEach(c => { const s = sh(c); placeH(c, dir > 0 ? l.x + l.w + hg(l.depth) : l.x - hg(l.depth), y + s / 2, dir); y += s + VG; });
  };
  const sw = id => { const l = L[id]; if (l.sw != null) return l.sw; let t = 0; const k = kidsOf(id); k.forEach((c, i) => { t += sw(c) + (i ? 16 : 0); }); return l.sw = Math.max(l.w, t); };
  const placeD = (id, cx, top) => {
    const l = L[id]; l.side = 'd'; l.x = cx - l.w / 2; l.y = top;
    const k = kidsOf(id); if (!k.length) return;
    let total = 0; k.forEach((c, i) => { total += sw(c) + (i ? 16 : 0); });
    let x = cx - total / 2;
    k.forEach(c => { const s = sw(c); placeD(c, x + s / 2, top + l.h + 64); x += s + 16; });
  };
  const leaves = id => { const l = L[id]; if (l.lv != null) return l.lv; const k = kidsOf(id); return l.lv = k.length ? k.reduce((a, c) => a + leaves(c), 0) : 1; };
  // radial: cada anel tem o raio necessário para os tópicos caberem sem se sobrepor
  const radial = (rid, cx, cy) => {
    const k0 = kidsOf(rid); if (!k0.length) return;
    const rings = [];
    const assign = (id, a0, a1, d) => {
      const l = L[id]; l.ang = (a0 + a1) / 2; l.span = a1 - a0; (rings[d] = rings[d] || []).push(id);
      const k = kidsOf(id); if (!k.length) return;
      const tot = k.reduce((s, c) => s + leaves(c), 0); let st = a0;
      k.forEach(c => { const sp = (a1 - a0) * leaves(c) / tot; assign(c, st, st + sp, d + 1); st += sp; });
    };
    const tot0 = k0.reduce((s, c) => s + leaves(c), 0); let st0 = -Math.PI / 2;
    k0.forEach(c => { const sp = 2 * Math.PI * leaves(c) / tot0; assign(c, st0, st0 + sp, 1); st0 += sp; });
    const rl = L[rid]; const radii = [0]; let prevExt = Math.max(rl.w, rl.h);
    for (let d = 1; d < rings.length; d++) {
      let ext = 0, req = 0;
      rings[d].forEach(id => { const l = L[id], c = Math.abs(Math.cos(l.ang)), sn = Math.abs(Math.sin(l.ang));
        ext = Math.max(ext, c * l.w + sn * l.h); req = Math.max(req, (sn * l.w + c * l.h + 16) / Math.max(l.span, 1e-3)); });
      radii[d] = Math.max(req, (d === 1 ? prevExt / 2 : radii[d - 1] + prevExt / 2) + ext / 2 + 46);
      prevExt = ext;
    }
    rings.forEach((ids, d) => { if (!ids) return; ids.forEach(id => { const l = L[id];
      l.x = cx + Math.cos(l.ang) * radii[d] - l.w / 2; l.y = cy + Math.sin(l.ang) * radii[d] - l.h / 2; l.side = Math.cos(l.ang) >= 0 ? 'r' : 'l'; }); });
  };

  const placeMain = () => {
    const rl = L[doc.root], k = kidsOf(doc.root);
    if (mode === 'down') { placeD(doc.root, 0, -rl.h / 2); return; }
    if (mode === 'radial') { rl.x = -rl.w / 2; rl.y = -rl.h / 2; rl.side = 'r'; radial(doc.root, 0, 0); return; }
    rl.x = -rl.w / 2; rl.y = -rl.h / 2;
    const right = [], left = []; let rt = 0, lt = 0;
    k.forEach(c => {
      let side = mode === 'right' ? 'r' : mode === 'left' ? 'l' : (N[c].side || null);
      if (!side) side = rt <= lt ? 'r' : 'l';
      if (side === 'r') { right.push(c); rt += sh(c) + VG; } else { left.push(c); lt += sh(c) + VG; }
    });
    const put = (list, dir) => { if (!list.length) return; let tot = 0; list.forEach((c, i) => { tot += sh(c) + (i ? VG : 0); });
      let y = -tot / 2; const edge = dir > 0 ? rl.x + rl.w + hg(0) : rl.x - hg(0);
      list.forEach(c => { const s = sh(c); placeH(c, edge, y + s / 2, dir); y += s + VG; }); };
    put(right, 1); put(left, -1);
  };

  if (mode === 'free') {
    // posições guardadas; tópicos sem posição nascem ao lado do pai
    const place = id => {
      const n = N[id], l = L[id];
      if (n.x != null && n.y != null) { l.x = n.x; l.y = n.y; }
      else if (id === doc.root) { l.x = -l.w / 2; l.y = -l.h / 2; }
      else if (n.parent && L[n.parent]) { const p = L[n.parent], i = N[n.parent].children.indexOf(id); l.x = p.x + p.w + 60; l.y = p.y + i * (l.h + 14); }
      l.side = (l.x + l.w / 2) >= (L[doc.root].x + L[doc.root].w / 2) ? 'r' : 'l';
      kidsOf(id).forEach(place);
    };
    roots.forEach(place);
  } else {
    placeMain();
    roots.slice(1).forEach(r => {
      const n = N[r], l = L[r]; const cy = (n.y || 0) + l.h / 2;
      if (mode === 'down') placeD(r, (n.x || 0) + l.w / 2, n.y || 0);
      else if (mode === 'radial') { l.x = n.x || 0; l.y = n.y || 0; radial(r, l.x + l.w / 2, l.y + l.h / 2); }
      else placeH(r, n.x || 0, cy, 1);
    });
  }
  return L;
};

/* limites de tudo que aparece */
MM.bounds = function (doc, L, withExtras) {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  Object.keys(L).forEach(id => { const l = L[id]; x0 = Math.min(x0, l.x); y0 = Math.min(y0, l.y); x1 = Math.max(x1, l.x + l.w); y1 = Math.max(y1, l.y + l.h); });
  if (withExtras !== false) (doc.groups || []).forEach(g => { const b = MM.groupBox(doc, L, g); if (b) { x0 = Math.min(x0, b.x); y0 = Math.min(y0, b.y); x1 = Math.max(x1, b.x + b.w); y1 = Math.max(y1, b.y + b.h); } });
  if (!isFinite(x0)) { x0 = y0 = -50; x1 = y1 = 50; }
  return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
};
MM.groupBox = function (doc, L, g) {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity, any = false;
  g.ids.forEach(id => { if (!doc.nodes[id]) return; [id].concat(doc.nodes[id].collapsed ? [] : MM.descendants(doc, id)).forEach(d => { const l = L[d]; if (!l) return; any = true;
    x0 = Math.min(x0, l.x); y0 = Math.min(y0, l.y); x1 = Math.max(x1, l.x + l.w); y1 = Math.max(y1, l.y + l.h); }); });
  if (!any) return null;
  const pad = 16; return { x: x0 - pad, y: y0 - pad - 14, w: x1 - x0 + pad * 2, h: y1 - y0 + pad * 2 + 14 };
};

/* ---------- ligações ---------- */
function anchors(a, b, mode, childSide) {
  const acx = a.x + a.w / 2, acy = a.y + a.h / 2, bcx = b.x + b.w / 2, bcy = b.y + b.h / 2;
  let orient;
  if (mode === 'both' || mode === 'right' || mode === 'left') orient = 'h';
  else if (mode === 'down') orient = 'v';
  else orient = Math.abs(bcx - acx) * 0.8 >= Math.abs(bcy - acy) ? 'h' : 'v';
  if (orient === 'h') { const right = bcx >= acx; return [right ? a.x + a.w : a.x, acy, right ? b.x : b.x + b.w, bcy, 'h']; }
  const below = bcy >= acy; return [acx, below ? a.y + a.h : a.y, bcx, below ? b.y : b.y + b.h, 'v'];
}
MM.pathOf = function (x1, y1, x2, y2, orient, style) {
  const r = v => Math.round(v * 10) / 10;
  if (style === 'straight') return `M${r(x1)} ${r(y1)}L${r(x2)} ${r(y2)}`;
  if (style === 'elbow') { if (orient === 'h') { const xm = (x1 + x2) / 2; return `M${r(x1)} ${r(y1)}H${r(xm)}V${r(y2)}H${r(x2)}`; } const ym = (y1 + y2) / 2; return `M${r(x1)} ${r(y1)}V${r(ym)}H${r(x2)}V${r(y2)}`; }
  if (orient === 'h') { const xm = (x1 + x2) / 2; return `M${r(x1)} ${r(y1)}C${r(xm)} ${r(y1)} ${r(xm)} ${r(y2)} ${r(x2)} ${r(y2)}`; }
  const ym = (y1 + y2) / 2; return `M${r(x1)} ${r(y1)}C${r(x1)} ${r(ym)} ${r(x2)} ${r(ym)} ${r(x2)} ${r(y2)}`;
};
MM.edges = function (doc, L) {
  const out = [], mode = doc.settings.layout, th = MM.THEMES[doc.settings.theme] || MM.THEMES.boha;
  Object.keys(L).forEach(id => {
    const n = doc.nodes[id]; if (!n.parent || !L[n.parent]) return;
    const a = L[n.parent], b = L[id], [x1, y1, x2, y2, o] = anchors(a, b, mode);
    const col = doc.settings.branchColors ? th.palette[(b.bi || 0) % th.palette.length] : th.palette[0];
    const lw = Math.max(1.2, doc.settings.lineW * (b.depth <= 1 ? 1.5 : b.depth === 2 ? 1 : 0.8));
    out.push({ id, d: MM.pathOf(x1, y1, x2, y2, o, doc.settings.line), color: col, w: lw, ax: x1, ay: y1, bx: x2, by: y2 });
  });
  return out;
};
MM.linkGeom = function (doc, L, lk) {
  const a = L[lk.from], b = L[lk.to]; if (!a || !b) return null;
  const [x1, y1, x2, y2, o] = anchors(a, b, 'free');
  const bend = 0.3, dx = x2 - x1, dy = y2 - y1;
  let d, mx, my;
  if (o === 'h') { const c = dx * 0.5; d = `M${x1} ${y1}C${x1 + c} ${y1 - Math.abs(dy) * bend - 30} ${x2 - c} ${y2 - Math.abs(dy) * bend - 30} ${x2} ${y2}`; }
  else { const c = dy * 0.5; d = `M${x1} ${y1}C${x1 + Math.abs(dx) * bend + 30} ${y1 + c} ${x2 + Math.abs(dx) * bend + 30} ${y2 - c} ${x2} ${y2}`; }
  mx = (x1 + x2) / 2 + (o === 'h' ? 0 : Math.abs(dx) * bend * 0.75 + 22); my = (y1 + y2) / 2 + (o === 'h' ? -Math.abs(dy) * bend * 0.75 - 22 : 0);
  return { d, mx, my, x2, y2 };
};

/* ---------- desenho SVG (usado na tela e na exportação) ---------- */
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
MM.esc = esc;
const r1 = v => Math.round(v * 10) / 10;
function shapeSVG(l, lk, hit) {
  const { x, y, w, h } = l, fill = lk.fill, stroke = lk.stroke ? ` stroke="${lk.stroke}" stroke-width="${lk.sw}"` : '';
  const f = `fill="${fill}"`;
  switch (lk.shape) {
    case 'pill': return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${h / 2}" ${f}${stroke}/>`;
    case 'rect': return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="3" ${f}${stroke}/>`;
    case 'ellipse': return `<ellipse cx="${x + w / 2}" cy="${y + h / 2}" rx="${w / 2}" ry="${h / 2}" ${f}${stroke}/>`;
    case 'diamond': return `<polygon points="${x + w / 2},${y} ${x + w},${y + h / 2} ${x + w / 2},${y + h} ${x},${y + h / 2}" ${f}${stroke}/>`;
    case 'line': return `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="transparent"/><path d="M${x} ${y + h}H${x + w}" stroke="${lk.stroke || lk.col}" stroke-width="${Math.max(2, lk.sw || 2)}" stroke-linecap="round"/>`;
    case 'text': return `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="transparent"/>`;
    default: return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${Math.min(12, h / 2)}" ${f}${stroke}/>`;
  }
}
MM.nodeSVG = function (doc, n, l, o) {
  o = o || {}; const lk = l.lk, th = MM.THEMES[doc.settings.theme] || MM.THEMES.boha;
  const { x, y, w, h } = l; let s = '';
  s += shapeSVG(l, lk);
  const contentX = x + 12 + l.prefix, contentW = w - 24 - l.prefix - l.suffix, cx = contentX + contentW / 2;
  const top = y + (lk.shape === 'line' ? 3 : 9);
  const empty = !n.text;
  const dim = n.task && n.done ? ' opacity="0.55"' : '';
  const lines = empty ? ['Tópico'] : l.lines;
  s += `<g${dim}>`;
  lines.forEach((ln, i) => {
    s += `<text x="${r1(cx)}" y="${r1(top + i * l.lh + l.lh * 0.78)}" text-anchor="middle" font-size="${lk.fs}" font-weight="${lk.bold ? 700 : 500}"${lk.italic ? ' font-style="italic"' : ''}${n.task && n.done ? ' text-decoration="line-through"' : ''} fill="${lk.text}"${empty ? ' opacity="0.45"' : ''}>${esc(ln)}</text>`;
  });
  s += '</g>';
  const mid = top + (lines.length * l.lh) / 2;
  let px = x + 10;
  if (n.task) { s += `<rect x="${px}" y="${r1(mid - 8)}" width="16" height="16" rx="4" fill="${n.done ? th.palette[2] : 'none'}" stroke="${lk.text}" stroke-width="1.6"/>`; if (n.done) s += `<path d="M${px + 3.5} ${r1(mid)}l3.2 3.4 6-6.6" fill="none" stroke="#fff" stroke-width="2"/>`; px += 22; }
  if (n.icon) s += `<text x="${px}" y="${r1(mid + 6)}" font-size="17">${esc(n.icon)}</text>`;
  if (n.pri) { const bx = x + w - 21; s += `<circle cx="${bx}" cy="${r1(mid)}" r="9" fill="${MM.PRI_COLORS[n.pri - 1]}"/><text x="${bx}" y="${r1(mid + 4)}" text-anchor="middle" font-size="11" font-weight="800" fill="#111">${n.pri}</text>`; }
  let by = top + lines.length * l.lh + 3;
  if (n.tags && n.tags.length) { let tx = x + (w - l.tagsW) / 2;
    n.tags.forEach(t => { const tw2 = tw(t, 10, true) + 14; s += `<rect x="${r1(tx)}" y="${r1(by)}" width="${r1(tw2)}" height="16" rx="8" fill="${th.palette[(t.length + 2) % th.palette.length]}" opacity="0.95"/><text x="${r1(tx + tw2 / 2)}" y="${r1(by + 11.5)}" text-anchor="middle" font-size="10" font-weight="700" fill="#111">${esc(t)}</text>`; tx += tw2 + 4; }); by += 20; }
  if (n.prog != null) s += `<rect x="${x + 12}" y="${r1(y + h - 11)}" width="${w - 24}" height="5" rx="2.5" fill="${lk.text}" opacity="0.2"/><rect x="${x + 12}" y="${r1(y + h - 11)}" width="${r1((w - 24) * n.prog / 100)}" height="5" rx="2.5" fill="${n.prog >= 100 ? th.palette[2] : lk.col}"/>`;
  // marcas de nota e link
  let mxp = x + w - 4;
  if (n.link) { s += `<g${o.live ? ' data-act="link"' : ''} class="mk"><circle cx="${mxp}" cy="${y - 2}" r="9" fill="#4da3ff"/><text x="${mxp}" y="${y + 2}" text-anchor="middle" font-size="11" font-weight="800" fill="#fff">↗</text></g>`; mxp -= 21; }
  if (n.note) { s += `<g${o.live ? ' data-act="note"' : ''} class="mk"><circle cx="${mxp}" cy="${y - 2}" r="9" fill="#ffd93d"/><text x="${mxp}" y="${y + 2}" text-anchor="middle" font-size="11" font-weight="800" fill="#111">≡</text></g>`; }
  // recolher/expandir
  if (n.children.length) {
    const side = l.side; let tx, ty;
    if (side === 'd') { tx = x + w / 2; ty = y + h + 11; } else if (side === 'l') { tx = x - 11; ty = y + h / 2; } else { tx = x + w + 11; ty = y + h / 2; }
    if (n.collapsed) s += `<g class="tg on"${o.live ? ' data-act="toggle"' : ''}><circle cx="${r1(tx)}" cy="${r1(ty)}" r="10" fill="${th.bg}" stroke="${lk.col}" stroke-width="2"/><text x="${r1(tx)}" y="${r1(ty + 4)}" text-anchor="middle" font-size="11" font-weight="800" fill="${th.text}">${MM.descendants(doc, n.id).length}</text></g>`;
    else if (o.live) s += `<g class="tg" data-act="toggle"><circle cx="${r1(tx)}" cy="${r1(ty)}" r="8" fill="${th.bg}" stroke="${lk.col}" stroke-width="1.6"/><path d="M${r1(tx - 3.5)} ${r1(ty)}h7" stroke="${th.text}" stroke-width="1.8"/></g>`;
  }
  return s;
};
/* peças do desenho, em texto; opts.live adiciona atributos de interação */
MM.parts = function (doc, L, o) {
  o = o || {}; const th = MM.THEMES[doc.settings.theme] || MM.THEMES.boha, sel = o.selected || new Set(), match = o.match || new Set();
  let groups = '', edges = '', links = '', nodes = '', defs = '';
  (doc.groups || []).forEach(g => {
    const b = MM.groupBox(doc, L, g); if (!b) return; const c = g.color || th.palette[0];
    const gs = o.selGroup === g.id;
    groups += `<g${o.live ? ` data-group="${g.id}"` : ''}><rect x="${r1(b.x)}" y="${r1(b.y)}" width="${r1(b.w)}" height="${r1(b.h)}" rx="18" fill="${c}" fill-opacity="0.09" stroke="${c}" stroke-width="${gs ? 3 : 1.6}" stroke-dasharray="7 5"/>`
      + (g.label ? `<text x="${r1(b.x + 14)}" y="${r1(b.y + 17)}" font-size="12" font-weight="800" fill="${c}">${esc(g.label)}</text>` : '') + '</g>';
  });
  MM.edges(doc, L).forEach(e => { edges += `<path d="${e.d}" fill="none" stroke="${e.color}" stroke-width="${r1(e.w)}" stroke-linecap="round" stroke-linejoin="round" opacity="0.92"/>`; });
  const marks = new Set();
  (doc.links || []).forEach(lk => {
    const g = MM.linkGeom(doc, L, lk); if (!g) return; const c = lk.color || th.text, mk = 'ar' + c.slice(1); marks.add(c);
    const ls = o.selLink === lk.id;
    links += `<g${o.live ? ` data-link="${lk.id}"` : ''}><path d="${g.d}" fill="none" stroke="transparent" stroke-width="14"/><path d="${g.d}" fill="none" stroke="${c}" stroke-width="${ls ? 3 : 1.8}"${lk.dash === false ? '' : ' stroke-dasharray="7 5"'} marker-end="url(#${mk})" opacity="0.9"/>`
      + (lk.label ? `<rect x="${r1(g.mx - tw(lk.label, 11, true) / 2 - 6)}" y="${r1(g.my - 10)}" width="${r1(tw(lk.label, 11, true) + 12)}" height="19" rx="9" fill="${th.bg}" stroke="${c}" stroke-width="1"/><text x="${r1(g.mx)}" y="${r1(g.my + 3.5)}" text-anchor="middle" font-size="11" font-weight="700" fill="${c}">${esc(lk.label)}</text>` : '') + '</g>';
  });
  marks.forEach(c => { defs += `<marker id="ar${c.slice(1)}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" fill="${c}"/></marker>`; });
  Object.keys(L).forEach(id => {
    const n = doc.nodes[id], l = L[id], isSel = sel.has(id);
    nodes += `<g class="node${isSel ? ' sel' : ''}${match.has(id) ? ' hit' : ''}${o.drop === id ? ' drop' : ''}" data-id="${id}">`
      + (isSel ? `<rect class="selbox" x="${l.x - 5}" y="${l.y - 5}" width="${l.w + 10}" height="${l.h + 10}" rx="${l.lk.shape === 'pill' ? (l.h + 10) / 2 : 14}" fill="none"/>` : '')
      + (match.has(id) ? `<rect class="hitbox" x="${l.x - 7}" y="${l.y - 7}" width="${l.w + 14}" height="${l.h + 14}" rx="16" fill="none"/>` : '')
      + MM.nodeSVG(doc, n, l, o) + '</g>';
  });
  return { groups, edges, links, nodes, defs };
};
MM.toSVG = function (doc, o) {
  o = o || {}; const L = MM.layout(doc), th = MM.THEMES[doc.settings.theme] || MM.THEMES.boha, p = MM.parts(doc, L, { live: false });
  let b = MM.bounds(doc, L); const pad = 48; b = { x: b.x - pad, y: b.y - pad, w: b.w + pad * 2, h: b.h + pad * 2 };
  const bg = o.transparent ? '' : `<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" fill="${th.bg}"/>`;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${Math.round(b.w)}" height="${Math.round(b.h)}" viewBox="${r1(b.x)} ${r1(b.y)} ${r1(b.w)} ${r1(b.h)}" font-family='${MM.FONT.replace(/"/g, '&quot;')}'><defs>${p.defs}</defs>${bg}${p.groups}${p.edges}${p.links}${p.nodes}</svg>`;
  return { svg, w: Math.round(b.w), h: Math.round(b.h) };
};
/* miniatura para a lista de mapas */
MM.thumb = function (doc) {
  const L = MM.layout(doc), th = MM.THEMES[doc.settings.theme] || MM.THEMES.boha;
  const ids = Object.keys(L).slice(0, 220); let b = MM.bounds(doc, L, false); const pad = 30; b = { x: b.x - pad, y: b.y - pad, w: b.w + 2 * pad, h: b.h + 2 * pad };
  let s = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${Math.round(b.x)} ${Math.round(b.y)} ${Math.round(b.w)} ${Math.round(b.h)}" preserveAspectRatio="xMidYMid meet"><rect x="${Math.round(b.x)}" y="${Math.round(b.y)}" width="${Math.round(b.w)}" height="${Math.round(b.h)}" fill="${th.bg}"/>`;
  MM.edges(doc, L).forEach(e => { s += `<path d="${e.d.replace(/\.\d+/g, '')}" fill="none" stroke="${e.color}" stroke-width="${Math.max(2, Math.round(e.w * 1.6))}"/>`; });
  ids.forEach(id => { const l = L[id]; s += `<rect x="${Math.round(l.x)}" y="${Math.round(l.y)}" width="${Math.round(l.w)}" height="${Math.round(l.h)}" rx="${Math.min(10, Math.round(l.h / 2))}" fill="${l.lk.fill === 'none' ? l.lk.col : l.lk.fill}" stroke="${l.lk.stroke || 'none'}" stroke-width="${l.lk.stroke ? 3 : 0}"/>`; });
  return s + '</svg>';
};

/* ---------- modelos ---------- */
const T = (text, children, extra) => Object.assign({ text, children: children || [] }, extra || {});
MM.TEMPLATES = [
  { id: 'campanha', name: 'Planejamento de campanha', icon: '📣', desc: 'Objetivo, público, oferta, canais, peças, prazos e métricas.', settings: {},
    tree: [T('Objetivo', [T('Meta de matrículas'), T('Meta de alcance'), T('Verba')], { icon: '🎯' }), T('Público', [T('Quem queremos atingir'), T('Dores e desejos'), T('Onde está')], { icon: '👥' }),
      T('Oferta', [T('O que oferecemos'), T('Condições e prazo'), T('Regras e restrições')], { icon: '💰' }), T('Canais', [T('Instagram'), T('WhatsApp'), T('Recepção das unidades'), T('Tráfego pago')], { icon: '📲' }),
      T('Peças', [T('Feed'), T('Stories'), T('Reels'), T('Cartaz e flyer')], { icon: '🎬' }), T('Cronograma', [T('Pré-campanha'), T('Lançamento'), T('Reforço'), T('Encerramento')], { icon: '📅' }),
      T('Resultados', [T('Matrículas'), T('Custo por matrícula'), T('Aprendizados')], { icon: '📈' })] },
  { id: 'conteudo', name: 'Calendário de conteúdo do mês', icon: '📅', desc: 'Semanas, pilares de conteúdo e formatos.', settings: {},
    tree: [T('Semana 1', [T('Segunda: Dica de treino'), T('Quarta: Bastidores'), T('Sexta: Depoimento')], { icon: '1️⃣' }), T('Semana 2', [T('Segunda: Aula coletiva'), T('Quarta: Nutrição'), T('Sexta: Aluno destaque')], { icon: '2️⃣' }),
      T('Semana 3', [T('Segunda: Desafio'), T('Quarta: Estrutura'), T('Sexta: Promoção')], { icon: '3️⃣' }), T('Semana 4', [T('Segunda: Resultado do mês'), T('Quarta: Enquete'), T('Sexta: Chamada do mês seguinte')], { icon: '4️⃣' }),
      T('Pilares', [T('Educação'), T('Comunidade'), T('Venda'), T('Autoridade')], { icon: '🧩' }), T('Formatos', [T('Reels'), T('Carrossel'), T('Stories'), T('Foto única')], { icon: '📸' })] },
  { id: 'funil', name: 'Funil de marketing', icon: '🔻', desc: 'Atração, interesse, decisão e retenção.', settings: { layout: 'right' },
    tree: [T('Atração', [T('Conteúdo orgânico'), T('Anúncios'), T('Indicação')], { icon: '👀' }), T('Interesse', [T('Aula experimental'), T('Visita à unidade'), T('Mensagem no WhatsApp')], { icon: '💡' }),
      T('Decisão', [T('Plano e condição'), T('Objeções'), T('Fechamento')], { icon: '✅' }), T('Retenção', [T('Boas-vindas'), T('Acompanhamento'), T('Eventos'), T('Renovação')], { icon: '❤️' })] },
  { id: 'brainstorm', name: 'Brainstorm de ideias', icon: '💡', desc: 'Tema central, ideias soltas e próximos passos.', settings: { layout: 'radial' },
    tree: [T('Ideias', [T('Ideia 1'), T('Ideia 2'), T('Ideia 3')], { icon: '💡' }), T('Referências', [T('Perfis que gostamos'), T('Campanhas de outras academias')], { icon: '🔎' }), T('Restrições', [T('Orçamento'), T('Prazo'), T('Equipe')], { icon: '⚠️' }),
      T('Próximos passos', [T('Escolher 3 ideias', [], { task: true }), T('Validar com a gerência', [], { task: true }), T('Produzir', [], { task: true })], { icon: '🚀' })] },
  { id: 'swot', name: 'Análise SWOT', icon: '🧭', desc: 'Forças, fraquezas, oportunidades e ameaças.', settings: { layout: 'both' },
    tree: [T('Forças', [T('Estrutura'), T('Equipe'), T('Preço')], { icon: '💪' }), T('Fraquezas', [T('Ponto fraco 1'), T('Ponto fraco 2')], { icon: '🩹' }), T('Oportunidades', [T('Datas sazonais'), T('Parcerias locais')], { icon: '🌱' }), T('Ameaças', [T('Concorrência'), T('Cancelamentos')], { icon: '⚡' })] },
  { id: '5w2h', name: 'Briefing de peça (5W2H)', icon: '📝', desc: 'O que, por quê, quem, onde, quando, como e quanto.', settings: { layout: 'right' },
    tree: [T('O quê', [T('Peça e formato')], { icon: '🖼️' }), T('Por quê', [T('Objetivo')], { icon: '❓' }), T('Quem', [T('Público'), T('Responsável')], { icon: '👥' }), T('Onde', [T('Canal e unidade')], { icon: '📍' }), T('Quando', [T('Prazo de entrega'), T('Data de publicação')], { icon: '⏰' }), T('Como', [T('Texto e chamada'), T('Referências')], { icon: '✍️' }), T('Quanto', [T('Verba, se houver')], { icon: '💰' })] },
  { id: 'unidades', name: 'Ação nas 3 unidades', icon: '🏢', desc: 'Um plano comum e o que muda em cada unidade.', settings: { layout: 'both' },
    tree: [T('Plano da rede', [T('Mensagem principal'), T('Oferta'), T('Datas')], { icon: '🎯' }), T('Casa Branca', [T('Peças locais'), T('Ações na recepção'), T('Meta')], { icon: '🏢' }), T('Santa Tereza', [T('Peças locais'), T('Ações na recepção'), T('Meta')], { icon: '🏢' }), T('Macedônia', [T('Peças locais'), T('Ações na recepção'), T('Meta')], { icon: '🏢' })] }
];
MM.fromTemplate = function (id, title) {
  const t = MM.TEMPLATES.find(x => x.id === id); if (!t) return MM.newDoc(title);
  return MM.fromTree(JSON.parse(JSON.stringify(t.tree)), title || t.name, t.settings);
};

root.MM = MM;
if (typeof module !== 'undefined' && module.exports) module.exports = MM;
})(typeof window !== 'undefined' ? window : globalThis);
