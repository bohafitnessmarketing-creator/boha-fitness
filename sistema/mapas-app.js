/* Tela dos Mapas mentais da Boha: lista, editor, painel, exportação e histórico. Usa o motor em mapas-core.js. */
(function () {
'use strict';
const $ = id => document.getElementById(id);
let CTX = null; try { CTX = (window.parent !== window && window.parent.bohaCtx) || window.bohaCtx || null; } catch (e) { CTX = null; }
const esc = MM.esc, TZ = 'America/Sao_Paulo';
const ME = () => String(CTX && CTX.profile && CTX.profile.email || '').toLowerCase();
const first = s => String(s || '').split('@')[0];
const fmtDT = iso => new Date(iso).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit', timeZone: TZ });
const ago = iso => { const m = Math.round((Date.now() - new Date(iso)) / 6e4); return m < 1 ? 'agora' : m < 60 ? 'há ' + m + ' min' : m < 1440 ? 'há ' + Math.round(m / 60) + ' h' : 'há ' + Math.round(m / 1440) + ' d'; };
function toast(t) { const e = $('toast'); e.textContent = t; e.classList.add('show'); clearTimeout(toast.t); toast.t = setTimeout(() => e.classList.remove('show'), 3600); }
const mctx = document.createElement('canvas').getContext('2d');
MM.setMeasurer((t, fs, b, i) => { mctx.font = (i ? 'italic ' : '') + (b ? 700 : 500) + ' ' + fs + 'px ' + MM.FONT; return mctx.measureText(t).width; });
const clone = o => JSON.parse(JSON.stringify(o));
const isTouch = () => matchMedia('(pointer:coarse)').matches;
const slug = s => String(s || 'mapa').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 50) || 'mapa';
function download(blob, name) { const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = name; document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 4000); }
const C = () => CTX.client;
const LASTSNAP = {};

/* =====================================================================  LISTA  */
let MAPS = [], TAB = 'maps', QS = '', NEWTPL = 'blank';
async function loadList() {
  const r = await C().from('boha_mindmaps').select('id,title,node_count,thumb,created_by,updated_by,created_at,updated_at,deleted_at').order('updated_at', { ascending: false }).limit(500);
  if (r.error) throw r.error;
  MAPS = r.data || []; renderHome();
}
function thumbImg(m) { return m.thumb ? '<img alt="" loading="lazy" src="data:image/svg+xml;utf8,' + encodeURIComponent(m.thumb) + '">' : '<span style="font-size:42px;opacity:.4">🧠</span>'; }
function renderHome() {
  if (E) return;
  const live = MAPS.filter(m => !m.deleted_at), trash = MAPS.filter(m => m.deleted_at);
  const q = QS.trim().toLowerCase(), list = (TAB === 'maps' ? live : trash).filter(m => !q || m.title.toLowerCase().includes(q));
  $('home').innerHTML = `<header class="hd"><div><p class="eyebrow">Marketing · ideias e planejamento</p><h1 class="display">Mapas mentais</h1>
  <p class="sub">Organize campanhas, pautas e estratégias em mapas. Todo o marketing enxerga e edita os mesmos mapas; o sistema guarda o histórico de versões e uma lixeira por 30 dias.</p></div>
  <div class="act"><button class="btn-g" id="hImport">Importar</button><button class="btn-y" id="hNew">+ Novo mapa</button></div></header>
  <div class="bar"><div class="seg" role="group" aria-label="Lista"><button data-tab="maps" aria-pressed="${TAB === 'maps'}">Mapas ${live.length}</button><button data-tab="trash" aria-pressed="${TAB === 'trash'}">Lixeira ${trash.length}</button></div>
  <input class="inp search" id="hq" type="search" placeholder="Buscar mapa" value="${esc(QS)}" aria-label="Buscar mapa"></div>
  <div class="mgrid" id="mgrid">${list.length ? list.map(cardHTML).join('') : `<div class="empty">${TAB === 'trash' ? '<b>A lixeira está vazia.</b>Mapas excluídos ficam aqui por 30 dias.' : (QS ? '<b>Nenhum mapa com esse nome.</b>' : '<b>Nenhum mapa ainda.</b>Clique em “Novo mapa” e escolha um modelo para começar.')}</div>`}</div>`;
}
function cardHTML(m) {
  const t = m.deleted_at;
  return `<article class="mcard" data-open="${m.id}" tabindex="0"><div class="th">${thumbImg(m)}</div><div class="cb"><b class="tt">${esc(m.title)}</b>
  <span class="mt">${t ? 'Excluído ' + ago(m.deleted_at) : 'Editado ' + ago(m.updated_at) + (m.updated_by ? ' por ' + esc(first(m.updated_by)) : '')} · ${m.node_count} tópico${m.node_count === 1 ? '' : 's'}</span>
  <div class="row">${t ? `<button data-restore="${m.id}">Restaurar</button><button class="danger" data-purge="${m.id}">Excluir de vez</button>`
    : `<button data-open="${m.id}">Abrir</button><button data-rename="${m.id}">Renomear</button><button data-dup="${m.id}">Duplicar</button><button data-exp="${m.id}">Backup</button><button class="danger" data-trash="${m.id}">Lixeira</button>`}</div></div></article>`;
}
async function fetchMap(id) {
  const r = await C().from('boha_mindmaps').select('id,title,data,updated_at,updated_by,deleted_at').eq('id', id).single();
  if (r.error || !r.data) throw new Error('Mapa não encontrado.');
  return r.data;
}
async function createMap(title, doc) {
  const r = await C().rpc('boha_mm_create', { p_title: title, p_data: doc, p_count: MM.count(doc), p_thumb: safeThumb(doc) });
  if (r.error) throw r.error;
  const row = Array.isArray(r.data) ? r.data[0] : r.data; return row;
}
function safeThumb(doc) { try { const t = MM.thumb(doc); return t.length <= 38000 ? t : null; } catch (e) { return null; } }
function openNew() {
  $('nTitle').value = ''; $('nErr').textContent = ''; NEWTPL = 'blank';
  $('nTpls').innerHTML = `<button class="tpl" data-tpl="blank" aria-pressed="true"><span class="i">🧠</span><b>Em branco</b><small>Só a ideia central.</small></button>` +
    MM.TEMPLATES.map(t => `<button class="tpl" data-tpl="${t.id}" aria-pressed="false"><span class="i">${t.icon}</span><b>${esc(t.name)}</b><small>${esc(t.desc)}</small></button>`).join('');
  $('dNew').showModal(); setTimeout(() => $('nTitle').focus(), 60);
}
async function doCreate() {
  const title = $('nTitle').value.trim() || (NEWTPL === 'blank' ? 'Novo mapa' : MM.TEMPLATES.find(t => t.id === NEWTPL).name);
  const b = $('nGo'); b.disabled = true;
  try {
    const doc = NEWTPL === 'blank' ? MM.newDoc(title) : MM.fromTemplate(NEWTPL, title);
    doc.nodes[doc.root].text = title;
    const row = await createMap(title, doc);
    $('dNew').close(); await loadList(); await openMap(row.id);
  } catch (e) { $('nErr').textContent = 'Não foi possível criar o mapa. Tente de novo.'; } finally { b.disabled = false; }
}
async function importFile(file) {
  if (!file) return;
  if (file.size > 3e6) { toast('Arquivo grande demais (máximo 3 MB).'); return; }
  try {
    const txt = await file.text(); let doc, title;
    if (/\.json$/i.test(file.name) || /^\s*[\[{]/.test(txt)) { const j = JSON.parse(txt); doc = MM.sanitize(j.doc || j); title = j.title || file.name.replace(/\.[^.]+$/, ''); }
    else { const p = MM.parseOutline(txt); if (!p.trees.length) throw new Error('vazio'); title = p.title || file.name.replace(/\.[^.]+$/, ''); doc = MM.fromTree(p.trees, title); }
    if (!doc.nodes[doc.root].text) doc.nodes[doc.root].text = title;
    const row = await createMap(title.slice(0, 120), doc); await loadList(); toast('Mapa importado.'); await openMap(row.id);
  } catch (e) { toast('Não consegui importar esse arquivo. Use um backup .json ou um texto com tópicos em lista.'); }
}
document.addEventListener('click', async ev => {
  if (E) return;
  const t = ev.target; let b;
  if (t.closest('#hNew')) { openNew(); return; }
  if (t.closest('#hImport')) { $('fImp').click(); return; }
  if ((b = t.closest('[data-tab]'))) { TAB = b.dataset.tab; renderHome(); return; }
  if ((b = t.closest('[data-rename]'))) { ev.stopPropagation(); renameStart(b.dataset.rename); return; }
  if ((b = t.closest('[data-dup]'))) { ev.stopPropagation(); try { const m = await fetchMap(b.dataset.dup); const doc = MM.sanitize(m.data); const row = await createMap((m.title + ' (cópia)').slice(0, 120), doc); await loadList(); toast('Mapa duplicado.'); } catch (e) { toast('Não foi possível duplicar.'); } return; }
  if ((b = t.closest('[data-exp]'))) { ev.stopPropagation(); try { const m = await fetchMap(b.dataset.exp); download(new Blob([JSON.stringify({ boha: 'mapa', v: 1, title: m.title, doc: m.data }, null, 1)], { type: 'application/json' }), slug(m.title) + '.boha-mapa.json'); } catch (e) { toast('Não foi possível exportar.'); } return; }
  if ((b = t.closest('[data-trash]'))) { ev.stopPropagation(); const r = await C().rpc('boha_mm_trash', { p_id: b.dataset.trash, p_on: true }); if (r.error) { toast('Não foi possível excluir.'); return; } await loadList(); toast('Mapa movido para a lixeira. Dá para restaurar por 30 dias.'); return; }
  if ((b = t.closest('[data-restore]'))) { ev.stopPropagation(); const r = await C().rpc('boha_mm_trash', { p_id: b.dataset.restore, p_on: false }); if (r.error) { toast('Não foi possível restaurar.'); return; } await loadList(); toast('Mapa restaurado.'); return; }
  if ((b = t.closest('[data-purge]'))) { ev.stopPropagation(); if (!confirm('Excluir este mapa de vez? Isso apaga também todo o histórico de versões e não pode ser desfeito.')) return; const r = await C().from('boha_mindmaps').delete().eq('id', b.dataset.purge); if (r.error) { toast('Não foi possível excluir.'); return; } await loadList(); toast('Mapa excluído de vez.'); return; }
  if ((b = t.closest('.mcard[data-open]'))) { if (ev.target.closest('input')) return; await openMap(b.dataset.open); return; }
});
function renameStart(id) {
  const card = document.querySelector('.mcard[data-open="' + id + '"] .tt'); if (!card) return; const m = MAPS.find(x => x.id === id);
  card.innerHTML = '<input class="inp" id="rnIn" maxlength="120" value="' + esc(m.title) + '" aria-label="Novo nome do mapa">'; const i = $('rnIn'); i.focus(); i.select();
  const done = async ok => { i.onblur = null; const v = i.value.trim(); if (ok && v && v !== m.title) { const r = await C().rpc('boha_mm_rename', { p_id: id, p_title: v }); if (r.error) toast('Não foi possível renomear.'); else { m.title = v; toast('Mapa renomeado.'); } } renderHome(); };
  i.onkeydown = e => { if (e.key === 'Enter') done(true); else if (e.key === 'Escape') done(false); e.stopPropagation(); }; i.onblur = () => done(true); i.onclick = e => e.stopPropagation();
}
document.addEventListener('input', ev => { if (ev.target.id === 'hq') { QS = ev.target.value; const g = $('mgrid'); const live = MAPS.filter(m => !m.deleted_at), trash = MAPS.filter(m => m.deleted_at); const q = QS.trim().toLowerCase(); const list = (TAB === 'maps' ? live : trash).filter(m => !q || m.title.toLowerCase().includes(q)); g.innerHTML = list.length ? list.map(cardHTML).join('') : '<div class="empty"><b>Nenhum mapa com esse nome.</b></div>'; } });
document.querySelectorAll('dialog [data-close]').forEach(b => b.addEventListener('click', () => b.closest('dialog').close()));
document.addEventListener('click', ev => { const b = ev.target.closest('#nTpls [data-tpl]'); if (!b) return; NEWTPL = b.dataset.tpl; document.querySelectorAll('#nTpls .tpl').forEach(x => x.setAttribute('aria-pressed', x === b)); });
$('nGo').addEventListener('click', doCreate);
$('nTitle').addEventListener('keydown', e => { if (e.key === 'Enter') doCreate(); });
$('fImp').addEventListener('change', e => { importFile(e.target.files[0]); e.target.value = ''; });
document.querySelectorAll('dialog').forEach(d => d.addEventListener('click', e => { if (e.target === d) d.close(); }));

/* =====================================================================  EDITOR  */
let E = null;
const THEME = () => MM.THEMES[E.doc.settings.theme] || MM.THEMES.boha;
const mobile = () => matchMedia('(max-width:900px)').matches;

async function openMap(id) {
  try {
    const m = await fetchMap(id); if (m.deleted_at) { toast('Esse mapa está na lixeira. Restaure para abrir.'); return; }
    const doc = MM.sanitize(m.data);
    E = { id, title: m.title, doc, expected: m.updated_at, by: m.updated_by, sel: new Set(), primary: null, view: { x: 0, y: 0, k: 1 }, hist: [], hi: -1, dirty: false, changed: false, saving: false, rev: 0, snapDone: false,
      focus: null, matchSet: new Set(), matches: [], mi: -1, mode: null, linkFrom: null, selLink: null, selGroup: null, editing: null, panelOpen: !mobile(), drop: null, dragSet: null, L: {} };
    E.hist = [JSON.stringify(doc)]; E.hi = 0;
    $('home').hidden = true; $('ed').hidden = false;
    $('title').value = E.title; fillSelects(); setStatus('ok', 'Salvo');
    $('panel').hidden = !E.panelOpen;
    render(); requestAnimationFrame(() => { fit(); updatePanel(); updateUndoUI(); });
    startPolling();
  } catch (e) { toast('Não foi possível abrir o mapa.'); }
}
function fillSelects() {
  $('selLayout').innerHTML = Object.entries(MM.LAYOUTS).map(([k, v]) => `<option value="${k}">${v}</option>`).join('');
  $('selTheme').innerHTML = Object.entries(MM.THEMES).map(([k, v]) => `<option value="${k}">${v.name}</option>`).join('');
  $('selLayout').value = E.doc.settings.layout; $('selTheme').value = E.doc.settings.theme;
}
function setStatus(cls, txt) { const s = $('status'); s.className = cls; s.textContent = txt; }

/* ----- documento visível (modo foco) ----- */
function viewDoc() {
  const d = E.doc; if (!E.focus || !d.nodes[E.focus]) return d;
  const ids = [E.focus].concat(MM.descendants(d, E.focus)), nodes = {}; ids.forEach(i => { nodes[i] = d.nodes[i]; });
  nodes[E.focus] = Object.assign({}, d.nodes[E.focus], { parent: null });
  return { root: E.focus, nodes, settings: d.settings, links: d.links.filter(l => nodes[l.from] && nodes[l.to]), groups: d.groups.map(g => Object.assign({}, g, { ids: g.ids.filter(i => nodes[i]) })).filter(g => g.ids.length) };
}

/* ----- desenho ----- */
let rq = 0;
function rqRender() { if (rq) return; rq = requestAnimationFrame(() => { rq = 0; render(); }); }
function render() {
  if (!E) return;
  const vd = viewDoc(); E.L = MM.layout(vd);
  const th = THEME();
  const p = MM.parts(vd, E.L, { live: true, selected: E.sel, match: E.matchSet, drop: E.drop, selLink: E.selLink, selGroup: E.selGroup });
  $('defs').innerHTML = p.defs; $('gGroups').innerHTML = p.groups; $('gEdges').innerHTML = p.edges; $('gLinks').innerHTML = p.links; $('gNodes').innerHTML = p.nodes;
  if (E.dragSet) E.dragSet.forEach(id => { const el = $('gNodes').querySelector('[data-id="' + id + '"]'); if (el) el.classList.add('dragging'); });
  $('stage').style.background = th.bg; $('gridDot').setAttribute('fill', th.grid); $('gridRect').style.display = E.doc.settings.grid ? '' : 'none';
  applyView(); drawMini(); drawBanner();
}
function applyView() {
  const v = E.view; $('world').setAttribute('transform', 'translate(' + v.x + ' ' + v.y + ') scale(' + v.k + ')');
  $('grid').setAttribute('patternTransform', 'translate(' + v.x + ' ' + v.y + ') scale(' + v.k + ')');
  $('zPct').textContent = Math.round(v.k * 100) + '%'; updateMiniView();
  if (E.editing) positionTA();
}
const stageRect = () => $('stage').getBoundingClientRect();
const toWorld = (cx, cy) => { const r = stageRect(); return { x: (cx - r.left - E.view.x) / E.view.k, y: (cy - r.top - E.view.y) / E.view.k }; };
function zoomAt(f, cx, cy) {
  const r = stageRect(), v = E.view, nk = Math.max(0.15, Math.min(3, v.k * f)); if (nk === v.k) return;
  const px = (cx == null ? r.width / 2 : cx - r.left), py = (cy == null ? r.height / 2 : cy - r.top);
  v.x = px - (px - v.x) * (nk / v.k); v.y = py - (py - v.y) * (nk / v.k); v.k = nk; applyView();
}
function fit(pad) {
  const L = E.L, ids = Object.keys(L); if (!ids.length) return;
  const b = MM.bounds(viewDoc(), L), r = stageRect(), m = pad == null ? 70 : pad;
  const k = Math.max(0.15, Math.min(1.25, Math.min((r.width - m * 2) / b.w, (r.height - m * 2) / b.h)));
  E.view.k = k; E.view.x = r.width / 2 - (b.x + b.w / 2) * k; E.view.y = r.height / 2 - (b.y + b.h / 2) * k; applyView();
}
function centerOn(id, keepZoom) {
  const l = E.L[id]; if (!l) return; const r = stageRect(); if (!keepZoom && E.view.k < 0.6) E.view.k = 0.9;
  E.view.x = r.width / 2 - (l.x + l.w / 2) * E.view.k; E.view.y = r.height / 2 - (l.y + l.h / 2) * E.view.k; applyView();
}
function ensureVisible(id) {
  const l = E.L[id]; if (!l) return; const r = stageRect(), v = E.view, m = 60;
  const x0 = l.x * v.k + v.x, x1 = (l.x + l.w) * v.k + v.x, y0 = l.y * v.k + v.y, y1 = (l.y + l.h) * v.k + v.y;
  if (x0 < m) v.x += m - x0; else if (x1 > r.width - m) v.x -= x1 - (r.width - m);
  if (y0 < m) v.y += m - y0; else if (y1 > r.height - m) v.y -= y1 - (r.height - m);
  applyView();
}
/* minimapa */
let MINI = null;
function drawMini() {
  const L = E.L, b = MM.bounds(viewDoc(), L, false), W = 190, H = 124, s = Math.min(W / (b.w + 60), H / (b.h + 60));
  MINI = { s, ox: (W - b.w * s) / 2 - b.x * s, oy: (H - b.h * s) / 2 - b.y * s };
  const th = THEME(); let h = '<svg viewBox="0 0 ' + W + ' ' + H + '">';
  Object.keys(L).slice(0, 500).forEach(id => { const l = L[id]; h += '<rect x="' + (l.x * s + MINI.ox).toFixed(1) + '" y="' + (l.y * s + MINI.oy).toFixed(1) + '" width="' + Math.max(2, l.w * s).toFixed(1) + '" height="' + Math.max(2, l.h * s).toFixed(1) + '" rx="1.5" fill="' + (l.lk.fill === 'none' ? l.lk.col : l.lk.fill) + '" opacity=".9"/>'; });
  h += '<rect id="mvp" fill="rgba(255,240,0,.10)" stroke="#fff000" stroke-width="1.4"/></svg>'; $('mini').innerHTML = h; updateMiniView();
}
function updateMiniView() {
  const vp = $('mvp'); if (!vp || !MINI || !E) return; const r = stageRect(), v = E.view;
  const x = (-v.x / v.k) * MINI.s + MINI.ox, y = (-v.y / v.k) * MINI.s + MINI.oy;
  vp.setAttribute('x', x.toFixed(1)); vp.setAttribute('y', y.toFixed(1)); vp.setAttribute('width', (r.width / v.k * MINI.s).toFixed(1)); vp.setAttribute('height', (r.height / v.k * MINI.s).toFixed(1));
}
$('mini').addEventListener('pointerdown', ev => {
  if (!E || !MINI) return; const mv = e => { const r = $('mini').getBoundingClientRect(), mx = (e.clientX - r.left) * 190 / r.width, my = (e.clientY - r.top) * 124 / r.height;
    const wx = (mx - MINI.ox) / MINI.s, wy = (my - MINI.oy) / MINI.s, sr = stageRect(); E.view.x = sr.width / 2 - wx * E.view.k; E.view.y = sr.height / 2 - wy * E.view.k; applyView(); };
  mv(ev); const up = () => { removeEventListener('pointermove', mv); removeEventListener('pointerup', up); }; addEventListener('pointermove', mv); addEventListener('pointerup', up);
});
function drawBanner() {
  const b = $('banner');
  if (E.mode === 'link') { b.hidden = false; b.innerHTML = 'Clique no tópico de <b>destino</b> da relação <button class="btn-g" data-bn="cancel">Cancelar</button>'; }
  else if (E.focus && E.doc.nodes[E.focus]) { b.hidden = false; b.innerHTML = 'Modo foco: só o ramo “' + esc((E.doc.nodes[E.focus].text || 'Tópico').slice(0, 40)) + '” <button class="btn-g" data-bn="unfocus">Sair do foco</button>'; }
  else b.hidden = true;
}
$('banner').addEventListener('click', e => { const b = e.target.closest('[data-bn]'); if (!b) return; if (b.dataset.bn === 'cancel') endLink(); else { E.focus = null; render(); requestAnimationFrame(() => fit()); } });

/* ----- histórico (desfazer/refazer) ----- */
function commit() {
  E.hist = E.hist.slice(0, E.hi + 1); E.hist.push(JSON.stringify(E.doc)); if (E.hist.length > 90) E.hist.shift(); E.hi = E.hist.length - 1;
  markDirty(); render(); updatePanel(); updateUndoUI();
}
function restoreSnap(json) {
  E.doc = MM.sanitize(JSON.parse(json));
  [...E.sel].forEach(i => { if (!E.doc.nodes[i]) E.sel.delete(i); }); if (!E.doc.nodes[E.primary]) E.primary = [...E.sel][0] || null;
  if (E.focus && !E.doc.nodes[E.focus]) E.focus = null; E.selLink = null; E.selGroup = null;
  $('selLayout').value = E.doc.settings.layout; $('selTheme').value = E.doc.settings.theme;
  markDirty(); render(); updatePanel(); updateUndoUI();
}
function undo() { if (E.editing || E.hi <= 0) return; E.hi--; restoreSnap(E.hist[E.hi]); }
function redo() { if (E.editing || E.hi >= E.hist.length - 1) return; E.hi++; restoreSnap(E.hist[E.hi]); }
function updateUndoUI() { $('bUndo').disabled = E.hi <= 0; $('bRedo').disabled = E.hi >= E.hist.length - 1; const has = E.sel.size > 0, one = E.sel.size === 1;
  $('tChild').disabled = !(one || !has); $('tSib').disabled = !one; $('tDup').disabled = !has || (one && E.primary === E.doc.root); $('tDel').disabled = !has && !E.selLink && !E.selGroup; $('tLink').disabled = !one; $('tGroup').disabled = !has; $('bFocus').disabled = !one && !E.focus; $('bFocus').setAttribute('aria-pressed', !!E.focus);
  $('tLink').setAttribute('aria-pressed', E.mode === 'link'); $('tPanel').setAttribute('aria-pressed', E.panelOpen); }

/* ----- gravação automática ----- */
function markDirty() { E.dirty = true; E.changed = true; E.rev++; setStatus('wait', 'Não salvo'); clearTimeout(E.t); E.t = setTimeout(() => save(), 1500); }
async function snapshot(note) { try { await C().rpc('boha_mm_snapshot', { p_id: E.id, p_note: note || null }); LASTSNAP[E.id] = Date.now(); } catch (e) { /* o histórico é um extra: não atrapalha a edição */ } }
async function save(o) {
  o = o || {};
  if (!E) return true;
  if (E.saving) { E.again = true; return false; }
  if (!E.dirty && !o.force) return true;
  clearTimeout(E.t); E.saving = true; setStatus('wait', 'Salvando…');
  const rev = E.rev, doc = clone(E.doc), title = E.title;
  try {
    if (!E.snapDone) { E.snapDone = true; if (!LASTSNAP[E.id] || Date.now() - LASTSNAP[E.id] > 10 * 60e3) await snapshot('Antes da edição de ' + fmtDT(new Date().toISOString())); }
    const r = await C().rpc('boha_mm_save', { p_id: E.id, p_expected: E.expected, p_title: title, p_data: doc, p_count: MM.count(doc), p_thumb: safeThumb(doc) });
    if (r.error) throw r.error;
    E.expected = r.data; E.by = ME(); if (E.rev === rev) { E.dirty = false; setStatus('ok', 'Salvo ' + new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit', timeZone: TZ })); }
    if (E.changed && Date.now() - (LASTSNAP[E.id] || 0) > 10 * 60e3) { E.changed = false; await snapshot(null); }
    E.saving = false; if (E.again || E.rev !== rev) { E.again = false; E.t = setTimeout(() => save(), 300); }
    return true;
  } catch (e) {
    E.saving = false;
    if (/CONFLITO/.test(String(e && e.message))) { await handleConflict(); return false; }
    setStatus('bad', 'Falha ao salvar'); E.t = setTimeout(() => save(), 8000); return false;
  }
}
async function handleConflict() {
  setStatus('bad', 'Conflito');
  let who = 'Outra pessoa', when = '';
  try { const m = await fetchMap(E.id); who = first(m.updated_by) || who; when = ' às ' + fmtDT(m.updated_at); E.remote = m; } catch (e) { /* segue com texto padrão */ }
  $('cMsg').textContent = who + ' alterou este mapa' + when + ' enquanto você editava. Escolha o que fazer com as suas mudanças.';
  if (!$('dConf').open) $('dConf').showModal();
}
$('cTheirs').addEventListener('click', async () => { $('dConf').close(); await reloadFromDb(true); });
$('cMine').addEventListener('click', async () => { $('dConf').close(); try { const m = E.remote || await fetchMap(E.id); E.expected = m.updated_at; await snapshot('Versão de ' + (first(m.updated_by) || 'outra pessoa') + ' antes de sobrescrever'); E.snapDone = true; E.dirty = true; await save(); } catch (e) { toast('Não foi possível sobrescrever.'); } });
$('cCopy').addEventListener('click', async () => { $('dConf').close(); try { const row = await createMap((E.title + ' (minhas mudanças)').slice(0, 120), clone(E.doc)); E.dirty = false; clearTimeout(E.t); toast('Suas mudanças foram salvas em uma cópia.'); await closeEditor(true); await loadList(); await openMap(row.id); } catch (e) { toast('Não foi possível salvar a cópia.'); } });
async function reloadFromDb(announce) {
  try {
    const m = await fetchMap(E.id); if (m.deleted_at) { toast('Este mapa foi para a lixeira.'); await closeEditor(true); return; }
    E.doc = MM.sanitize(m.data); E.title = m.title; E.expected = m.updated_at; E.dirty = false; E.hist = [JSON.stringify(E.doc)]; E.hi = 0;
    [...E.sel].forEach(i => { if (!E.doc.nodes[i]) E.sel.delete(i); }); if (!E.doc.nodes[E.primary]) E.primary = null; E.selLink = null; E.selGroup = null;
    $('title').value = E.title; $('selLayout').value = E.doc.settings.layout; $('selTheme').value = E.doc.settings.theme;
    setStatus('ok', 'Atualizado'); render(); updatePanel(); updateUndoUI();
    if (announce) toast('Mapa atualizado com a versão mais recente.');
  } catch (e) { toast('Não foi possível atualizar o mapa.'); }
}
let pollT = null;
function startPolling() { clearInterval(pollT); pollT = setInterval(async () => {
  if (!E || E.dirty || E.saving || E.editing || document.hidden || document.querySelector('dialog[open]')) return;
  try { const r = await C().from('boha_mindmaps').select('updated_at,updated_by,deleted_at').eq('id', E.id).single();
    if (r.error || !r.data) return;
    if (r.data.deleted_at) { toast('Este mapa foi movido para a lixeira.'); await closeEditor(true); return; }
    if (r.data.updated_at !== E.expected) { await reloadFromDb(false); toast(first(r.data.updated_by) + ' atualizou este mapa. Você já está vendo a versão mais recente.'); }
  } catch (e) { /* tenta de novo no próximo ciclo */ } }, 25000); }
async function closeEditor(skipSave) {
  if (!E) return;
  if (!skipSave) { E.editing && finishEdit(true); const ok = await save({ force: E.dirty }); if (!ok && E.dirty && !confirm('Não foi possível salvar as últimas mudanças. Sair mesmo assim?')) return;
    if (E.changed && Date.now() - (LASTSNAP[E.id] || 0) > 2 * 60e3) await snapshot(null); }
  clearInterval(pollT); clearTimeout(E.t); closeMenu(); E = null; $('ed').hidden = true; $('home').hidden = false; $('ta').hidden = true;
  await loadList().catch(() => renderHome());
}
$('bBack').addEventListener('click', () => closeEditor());
addEventListener('beforeunload', ev => { if (E && E.dirty) { ev.preventDefault(); ev.returnValue = ''; } });
document.addEventListener('visibilitychange', () => { if (document.hidden && E && E.dirty) save(); });
addEventListener('pagehide', () => { if (E && E.dirty) save(); });
$('title').addEventListener('input', () => { E.title = $('title').value.slice(0, 120); markDirty(); });
$('title').addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); $('cv').focus(); } e.stopPropagation(); });

/* ----- seleção ----- */
function select(ids, add) {
  if (!add) E.sel.clear(); ids.forEach(i => { if (E.doc.nodes[i]) E.sel.add(i); });
  E.primary = ids.length ? ids[ids.length - 1] : (add ? E.primary : null); if (E.primary && !E.sel.has(E.primary)) E.primary = [...E.sel][0] || null;
  E.selLink = null; E.selGroup = null; render(); updatePanel(); updateUndoUI();
}
const topSelected = () => [...E.sel].filter(i => { let p = E.doc.nodes[i] && E.doc.nodes[i].parent; while (p) { if (E.sel.has(p)) return false; p = E.doc.nodes[p].parent; } return true; });

/* ----- criar / apagar ----- */
function freezeNow() { const L = E.L; Object.keys(L).forEach(id => { const n = E.doc.nodes[id]; if (n && n.x == null) { n.x = Math.round(L[id].x); n.y = Math.round(L[id].y); } }); }
function freezeFree() { if (E.doc.settings.layout === 'free') freezeNow(); }
function newNodeAnd(fn) {
  const id = fn(); if (!id) return; E.sel = new Set([id]); E.primary = id; E.selLink = null; E.selGroup = null; render(); ensureVisible(id); updateUndoUI(); startEdit(id, { fresh: true });
}
function addChild() { const pid = E.primary || (E.focus || E.doc.root); newNodeAnd(() => { freezeFree(); return MM.addChild(E.doc, pid, ''); }); }
function addSibling() { if (!E.primary) return addChild(); newNodeAnd(() => { freezeFree(); return MM.addSibling(E.doc, E.primary, true, ''); }); }
function addParent() { const id = E.primary; if (!id || !E.doc.nodes[id].parent) return; newNodeAnd(() => { const n = E.doc.nodes[id], p = E.doc.nodes[n.parent], idx = p.children.indexOf(id); const np = MM.addChild(E.doc, n.parent, '', idx); MM.move(E.doc, id, np); return np; }); }
function addFloating(x, y) { newNodeAnd(() => MM.addFloating(E.doc, Math.round(x), Math.round(y), '')); }
function deleteSel() {
  if (E.selLink) { E.doc.links = E.doc.links.filter(l => l.id !== E.selLink); E.selLink = null; commit(); return; }
  if (E.selGroup) { E.doc.groups = E.doc.groups.filter(g => g.id !== E.selGroup); E.selGroup = null; commit(); return; }
  const ids = topSelected().filter(i => i !== E.doc.root); if (!ids.length) { if (E.sel.has(E.doc.root)) toast('O tópico central não pode ser excluído. Edite o texto ou apague os ramos.'); return; }
  const first = E.doc.nodes[ids[0]], next = first.parent && E.doc.nodes[first.parent] ? first.parent : null; const n = ids.reduce((a, i) => a + 1 + MM.descendants(E.doc, i).length, 0);
  MM.removeNodes(E.doc, ids); E.sel.clear(); E.primary = null; if (next && E.doc.nodes[next]) { E.sel.add(next); E.primary = next; }
  commit(); toast(n + ' tópico' + (n === 1 ? '' : 's') + ' excluído' + (n === 1 ? '' : 's') + '. Ctrl+Z desfaz.');
}
function toggleCollapse(ids) { let any = false; ids.forEach(i => { const n = E.doc.nodes[i]; if (n && n.children.length) { n.collapsed = !n.collapsed; any = true; } }); if (any) commit(); }
function setLevels(max) { Object.keys(E.doc.nodes).forEach(id => { const n = E.doc.nodes[id]; if (!n.children.length) return; n.collapsed = max != null && MM.depthOf(E.doc, id) >= max; }); commit(); requestAnimationFrame(() => fit()); }
function endLink() { E.mode = null; $('stage').classList.remove('linking'); drawBanner(); updateUndoUI(); }
function startLink() { if (E.sel.size !== 1) { toast('Selecione o tópico de origem e use Relação.'); return; } E.mode = 'link'; E.linkFrom = E.primary; $('stage').classList.add('linking'); drawBanner(); updateUndoUI(); }
function makeGroup() { const ids = topSelected(); if (!ids.length) return; const th = THEME(); const g = { id: MM.uid(), ids, label: '', color: th.palette[E.doc.groups.length % th.palette.length] }; E.doc.groups.push(g); E.selGroup = g.id; E.sel.clear(); E.primary = null; commit(); toast('Fronteira criada. Dê um nome a ela no painel.'); }

/* ----- edição de texto no próprio tópico ----- */
function positionTA() {
  const ed = E.editing; if (!ed) return; const l = E.L[ed.id]; if (!l) return; const ta = $('ta'), v = E.view, k = v.k;
  const w = Math.max(l.w, 120) * k; ta.style.left = (l.x * k + v.x - (Math.max(l.w, 120) - l.w) * k / 2) + 'px'; ta.style.top = (l.y * k + v.y) + 'px'; ta.style.width = w + 'px';
  ta.style.fontSize = (l.lk.fs * k) + 'px'; ta.style.fontWeight = l.lk.bold ? 700 : 500; ta.style.fontStyle = l.lk.italic ? 'italic' : 'normal';
  ta.style.height = 'auto'; ta.style.height = Math.max(l.h * k, ta.scrollHeight + 4) + 'px';
}
function startEdit(id, o) {
  o = o || {}; const n = E.doc.nodes[id]; if (!n) return; if (E.editing) finishEdit(true);
  E.editing = { id, orig: n.text, fresh: !!o.fresh }; const ta = $('ta'); ta.hidden = false; ta.value = o.replace != null ? o.replace : n.text;
  const lk = (E.L[id] && E.L[id].lk) || {}; ta.style.background = lk.fill && lk.fill !== 'none' ? lk.fill : '#fff'; ta.style.color = lk.fill && lk.fill !== 'none' ? lk.text : '#111';
  positionTA(); ta.focus(); if (o.replace != null) ta.setSelectionRange(ta.value.length, ta.value.length); else ta.select();
}
function finishEdit(ok) {
  const ed = E.editing; if (!ed) return; E.editing = null; const ta = $('ta'), n = E.doc.nodes[ed.id]; ta.hidden = true; if (!n) { render(); return; }
  const val = ta.value.replace(/\s+$/g, '').slice(0, 2000);
  if (ok) {
    if (ed.fresh && !val.trim()) { MM.removeNodes(E.doc, [ed.id]); E.sel.delete(ed.id); E.primary = null; render(); updatePanel(); updateUndoUI(); }
    else if (val !== ed.orig || ed.fresh) { n.text = val; commit(); } else render();
  } else { n.text = ed.orig; if (ed.fresh && !ed.orig) { MM.removeNodes(E.doc, [ed.id]); E.sel.delete(ed.id); E.primary = null; } render(); updatePanel(); updateUndoUI(); }
  $('cv').focus({ preventScroll: true });
}
$('ta').addEventListener('input', () => { const ed = E.editing; if (!ed) return; E.doc.nodes[ed.id].text = $('ta').value; render(); positionTA(); });
$('ta').addEventListener('keydown', e => {
  e.stopPropagation(); const ed = E.editing;
  if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); finishEdit(true); }
  else if (e.key === 'Escape') { e.preventDefault(); finishEdit(false); }
  else if (e.key === 'Tab') { e.preventDefault(); const id = ed.id; finishEdit(true); if (E.doc.nodes[id]) { E.primary = id; e.shiftKey ? addSibling() : addChild(); } }
});
$('ta').addEventListener('blur', () => { if (E && E.editing) finishEdit(true); });

/* ----- ponteiro: mover a tela, selecionar, arrastar tópicos ----- */
const PT = new Map(); let G = null, lastTap = { t: 0, x: 0, y: 0, id: null };
const cv = $('cv');
function hitNode(wx, wy, excl) { const L = E.L; let best = null; Object.keys(L).forEach(id => { if (excl && excl.has(id)) return; const l = L[id]; if (wx >= l.x - 4 && wx <= l.x + l.w + 4 && wy >= l.y - 4 && wy <= l.y + l.h + 4) best = id; }); return best; }
cv.addEventListener('pointerdown', ev => {
  if (!E) return; if (E.editing) finishEdit(true);
  $('hint').style.opacity = 0; closeMenu();
  cv.focus({ preventScroll: true }); PT.set(ev.pointerId, { x: ev.clientX, y: ev.clientY });
  if (PT.size === 2) { const [a, b] = [...PT.values()]; G = { type: 'pinch', d: Math.hypot(a.x - b.x, a.y - b.y), k: E.view.k, cx: (a.x + b.x) / 2, cy: (a.y + b.y) / 2, vx: E.view.x, vy: E.view.y }; return; }
  if (PT.size > 2) return;
  cv.setPointerCapture(ev.pointerId);
  const t = ev.target, act = t.closest('[data-act]'), nodeEl = t.closest('.node'), linkEl = t.closest('[data-link]'), groupEl = t.closest('[data-group]');
  const id = nodeEl && nodeEl.dataset.id;
  if (E.mode === 'link') { if (id && id !== E.linkFrom) { E.doc.links.push({ id: MM.uid(), from: E.linkFrom, to: id, label: '', color: '', dash: true }); endLink(); E.selLink = E.doc.links[E.doc.links.length - 1].id; E.sel.clear(); commit(); toast('Relação criada. Dê um nome a ela no painel (opcional).'); } else if (!id) endLink(); G = null; return; }
  if (act && id) {
    const a = act.dataset.act;
    if (a === 'toggle') { toggleCollapse([id]); G = null; return; }
    if (a === 'link') { const u = MM.okUrl(E.doc.nodes[id].link); if (u) window.open(u, '_blank', 'noopener,noreferrer'); G = null; return; }
    if (a === 'note') { select([id]); if (!E.panelOpen) togglePanel(true); setTimeout(() => { const n = $('pNote'); if (n) n.focus(); }, 50); G = null; return; }
  }
  if (id) {
    if (ev.shiftKey || ev.ctrlKey || ev.metaKey) { if (E.sel.has(id)) { E.sel.delete(id); if (E.primary === id) E.primary = [...E.sel][0] || null; render(); updatePanel(); updateUndoUI(); } else select([id], true); G = null; return; }
    if (!E.sel.has(id) || E.sel.size === 1) select([id]); else { E.primary = id; }
    G = { type: 'node', id, px: ev.clientX, py: ev.clientY, moved: false, pid: ev.pointerId };
    // duplo toque/clique para editar
    const now = Date.now(); if (now - lastTap.t < 380 && lastTap.id === id && Math.hypot(ev.clientX - lastTap.x, ev.clientY - lastTap.y) < 12) { G = null; lastTap = { t: 0 }; setTimeout(() => { if (E && E.doc.nodes[id]) startEdit(id); }, 0); return; }
    lastTap = { t: now, x: ev.clientX, y: ev.clientY, id }; return;
  }
  if (linkEl) { E.selLink = linkEl.dataset.link; E.selGroup = null; E.sel.clear(); E.primary = null; render(); updatePanel(); updateUndoUI(); G = null; return; }
  if (groupEl) { E.selGroup = groupEl.dataset.group; E.selLink = null; E.sel.clear(); E.primary = null; render(); updatePanel(); updateUndoUI(); G = null; return; }
  // fundo
  const now = Date.now();
  if (now - lastTap.t < 380 && !lastTap.id && Math.hypot(ev.clientX - lastTap.x, ev.clientY - lastTap.y) < 12) { lastTap = { t: 0 }; const w = toWorld(ev.clientX, ev.clientY); freezeFree(); setTimeout(() => { if (E) addFloating(w.x - 60, w.y - 18); }, 0); G = null; return; }
  lastTap = { t: now, x: ev.clientX, y: ev.clientY, id: null };
  if (ev.shiftKey) { G = { type: 'marquee', sx: ev.clientX, sy: ev.clientY }; }
  else { G = { type: 'pan', px: ev.clientX, py: ev.clientY, vx: E.view.x, vy: E.view.y, moved: false }; $('stage').classList.add('panning'); }
});
cv.addEventListener('pointermove', ev => {
  if (!E) return; const p = PT.get(ev.pointerId); if (p) { p.x = ev.clientX; p.y = ev.clientY; }
  if (!G) return;
  if (G.type === 'pinch') { if (PT.size < 2) return; const [a, b] = [...PT.values()], d = Math.hypot(a.x - b.x, a.y - b.y), cx = (a.x + b.x) / 2, cy = (a.y + b.y) / 2, r = stageRect();
    const nk = Math.max(0.15, Math.min(3, G.k * d / G.d)), px = G.cx - r.left, py = G.cy - r.top;
    E.view.k = nk; E.view.x = (cx - r.left) - (px - G.vx) * (nk / G.k); E.view.y = (cy - r.top) - (py - G.vy) * (nk / G.k); applyView(); return; }
  if (G.type === 'pan') { const dx = ev.clientX - G.px, dy = ev.clientY - G.py; if (!G.moved && Math.hypot(dx, dy) > 3) G.moved = true; E.view.x = G.vx + dx; E.view.y = G.vy + dy; applyView(); return; }
  if (G.type === 'marquee') { drawMarquee(ev); return; }
  if (G.type === 'node') { if (!G.moved && Math.hypot(ev.clientX - G.px, ev.clientY - G.py) > 6) { startNodeDrag(); } if (G && G.type === 'drag') moveDrag(ev); return; }
  if (G.type === 'drag') moveDrag(ev);
});
function endPointer(ev) {
  if (!E) return; PT.delete(ev.pointerId);
  if (G && G.type === 'pinch') { if (PT.size < 2) G = null; return; }
  const g = G; G = null; $('stage').classList.remove('panning');
  if (!g) return;
  if (g.type === 'pan') { if (!g.moved && !ev.shiftKey) { if (E.sel.size || E.selLink || E.selGroup) { E.sel.clear(); E.primary = null; E.selLink = null; E.selGroup = null; render(); updatePanel(); updateUndoUI(); } } return; }
  if (g.type === 'marquee') { finishMarquee(ev, g); return; }
  if (g.type === 'drag') { finishDrag(ev, g); return; }
}
cv.addEventListener('pointerup', endPointer); cv.addEventListener('pointercancel', ev => { if (G && G.type === 'drag') cancelDrag(); endPointer(ev); });
cv.addEventListener('wheel', ev => { if (!E) return; ev.preventDefault(); if (ev.shiftKey && !ev.ctrlKey) { E.view.x -= ev.deltaY; E.view.y -= ev.deltaX; applyView(); return; }
  zoomAt(Math.exp(-ev.deltaY * (ev.ctrlKey ? 0.01 : 0.0016)), ev.clientX, ev.clientY); }, { passive: false });
function drawMarquee(ev) {
  const r = stageRect(), a = toWorld(G.sx, G.sy), b = toWorld(ev.clientX, ev.clientY);
  $('gOver').innerHTML = '<rect class="marq" x="' + Math.min(a.x, b.x) + '" y="' + Math.min(a.y, b.y) + '" width="' + Math.abs(a.x - b.x) + '" height="' + Math.abs(a.y - b.y) + '"/>';
}
function finishMarquee(ev, g) {
  $('gOver').innerHTML = ''; const a = toWorld(g.sx, g.sy), b = toWorld(ev.clientX, ev.clientY), x0 = Math.min(a.x, b.x), x1 = Math.max(a.x, b.x), y0 = Math.min(a.y, b.y), y1 = Math.max(a.y, b.y);
  const ids = Object.keys(E.L).filter(id => { const l = E.L[id]; return l.x < x1 && l.x + l.w > x0 && l.y < y1 && l.y + l.h > y0; }); select(ids, true);
}
/* arrastar tópicos */
function startNodeDrag() {
  const free = E.doc.settings.layout === 'free'; let ids = topSelected(); if (!free) ids = ids.filter(i => i !== E.doc.root);
  if (!ids.length) { G = { type: 'pan', px: G.px, py: G.py, vx: E.view.x, vy: E.view.y, moved: true }; $('stage').classList.add('panning'); return; }
  if (E.focus) { ids = ids.filter(i => i !== E.focus); if (!ids.length) { G = null; return; } }
  const excl = new Set(); ids.forEach(i => { excl.add(i); MM.descendants(E.doc, i).forEach(d => excl.add(d)); });
  G = { type: 'drag', ids, excl, px: G.px, py: G.py, dx: 0, dy: 0, target: null, zone: null };
  E.dragSet = excl; render();
  let h = ''; ids.forEach(id => { const l = E.L[id], n = E.doc.nodes[id]; if (l) h += '<g class="node">' + MM.nodeSVG(E.doc, n, l, { live: false }).replace(/<g class="mk">|<g class="tg[^"]*">/g, '<g>') + '</g>'; });
  $('gOver').innerHTML = '<g class="ghost" id="ghost">' + h + '</g>';
}
function moveDrag(ev) {
  if (!G || G.type !== 'drag') return; const k = E.view.k; G.dx = (ev.clientX - G.px) / k; G.dy = (ev.clientY - G.py) / k;
  const gh = $('ghost'); if (gh) gh.setAttribute('transform', 'translate(' + G.dx + ' ' + G.dy + ')');
  const free = E.doc.settings.layout === 'free', w = toWorld(ev.clientX, ev.clientY);
  G.target = null; G.zone = null; $('gOver').querySelectorAll('.ind').forEach(e => e.remove());
  const prev = $('gNodes').querySelector('.drop'); if (prev) prev.classList.remove('drop');
  if (!free || ev.altKey) {
    const t = hitNode(w.x, w.y, G.excl);
    if (t) {
      const l = E.L[t], down = E.doc.settings.layout === 'down', radial = E.doc.settings.layout === 'radial';
      const f = down ? (w.x - l.x) / l.w : (w.y - l.y) / l.h; let zone = 'child';
      if (E.doc.nodes[t].parent && !radial) { if (f < 0.28) zone = 'before'; else if (f > 0.72) zone = 'after'; }
      if (E.focus === t && zone !== 'child') zone = 'child';
      G.target = t; G.zone = zone;
      if (zone === 'child') { const el = $('gNodes').querySelector('[data-id="' + t + '"]'); if (el) el.classList.add('drop'); }
      else { const x0 = down ? (zone === 'before' ? l.x - 8 : l.x + l.w + 8) : l.x, x1 = down ? x0 : l.x + l.w, y0 = down ? l.y : (zone === 'before' ? l.y - 8 : l.y + l.h + 8), y1 = down ? l.y + l.h : y0;
        $('gOver').insertAdjacentHTML('beforeend', '<line class="ind" x1="' + x0 + '" y1="' + y0 + '" x2="' + x1 + '" y2="' + y1 + '"/>'); }
    }
  }
}
function cancelDrag() { E.dragSet = null; $('gOver').innerHTML = ''; render(); }
function finishDrag(ev, g) {
  E.dragSet = null; $('gOver').innerHTML = ''; const doc = E.doc, free = doc.settings.layout === 'free', L = E.L;
  const moved = Math.hypot(g.dx, g.dy) * E.view.k > 4; if (!moved) { render(); return; }
  if (g.target) {
    const t = g.target, ids = g.ids.filter(i => i !== t && !MM.isAncestor(doc, i, t)); let ok = false;
    if (g.zone === 'child') ids.forEach(i => { ok = MM.move(doc, i, t, null) || ok; });
    else { const p = doc.nodes[t].parent; let ref = t; if (g.zone === 'after') { const sib = doc.nodes[p].children, j = sib.indexOf(t); ref = sib.slice(j + 1).find(s => !ids.includes(s)) || null; }
      ids.forEach(i => { const idx = ref ? doc.nodes[p].children.indexOf(ref) : null; ok = MM.move(doc, i, p, idx) || ok; }); }
    if (ok) { select(ids); commit(); } else render(); return;
  }
  if (free) {
    freezeFree(); g.ids.forEach(i => { [i].concat(MM.descendants(doc, i)).forEach(d => { const n = doc.nodes[d], l = L[d]; if (!l) return; n.x = Math.round((n.x != null ? n.x : l.x) + g.dx); n.y = Math.round((n.y != null ? n.y : l.y) + g.dy); }); }); commit(); return;
  }
  // modos automáticos: soltar sobre ele mesmo ou sobre os próprios filhos não faz nada (não destaca sem querer)
  { const w = toWorld(ev.clientX, ev.clientY), over = hitNode(w.x, w.y, null); if (over && g.excl.has(over)) { render(); return; } }
  // soltar no vazio
  g.ids.forEach(i => { const n = doc.nodes[i], l = L[i]; if (!l) return;
    if (!n.parent) { n.x = Math.round(l.x + g.dx); n.y = Math.round(l.y + g.dy); }
    else if (Math.hypot(g.dx, g.dy) * E.view.k > 70) MM.move(doc, i, null, null, Math.round(l.x + g.dx), Math.round(l.y + g.dy)); });
  commit();
}

/* ----- teclado ----- */
document.addEventListener('keydown', ev => {
  if (!E || E.editing) return; const t = ev.target; if (t.matches && t.matches('input,textarea,select')) { if (ev.key === 'Escape' && t.id === 'q') { t.value = ''; searchRun(''); $('cv').focus(); } return; }
  if (document.querySelector('dialog[open]')) return;
  const mod = ev.ctrlKey || ev.metaKey, k = ev.key, one = E.sel.size === 1;
  if (k === 'Escape') { if (closeMenu()) return; if (E.mode === 'link') { endLink(); return; } if (E.focus) { E.focus = null; render(); fit(); return; } if (E.matchSet.size) { $('q').value = ''; searchRun(''); return; } if (E.sel.size || E.selLink || E.selGroup) { E.sel.clear(); E.primary = null; E.selLink = null; E.selGroup = null; render(); updatePanel(); updateUndoUI(); } return; }
  if (mod && !ev.shiftKey && k.toLowerCase() === 'z') { ev.preventDefault(); undo(); return; }
  if (mod && (k.toLowerCase() === 'y' || (ev.shiftKey && k.toLowerCase() === 'z'))) { ev.preventDefault(); redo(); return; }
  if (mod && k.toLowerCase() === 'a') { ev.preventDefault(); select(Object.keys(E.L)); return; }
  if (mod && k.toLowerCase() === 'd') { ev.preventDefault(); duplicateSel(); return; }
  if (mod && k.toLowerCase() === 'f') { ev.preventDefault(); $('q').focus(); $('q').select(); return; }
  if (mod && k.toLowerCase() === 's') { ev.preventDefault(); save({ force: true }); return; }
  if (ev.altKey && !mod && (ev.code === 'KeyR' || ev.code === 'KeyG')) { ev.preventDefault(); if (ev.code === 'KeyR') startLink(); else makeGroup(); return; }
  if (mod) return;
  if (k === 'Tab') { ev.preventDefault(); if (ev.shiftKey) addParent(); else if (one || !E.sel.size) addChild(); return; }
  if (k === 'Enter') { ev.preventDefault(); if (one) { if (ev.shiftKey) addSibling(); else addSibling(); } else if (!E.sel.size) addChild(); return; }
  if (k === 'F2') { ev.preventDefault(); if (one) startEdit(E.primary); return; }
  if (k === 'Delete' || k === 'Backspace') { ev.preventDefault(); deleteSel(); return; }
  if (k === ' ') { ev.preventDefault(); if (E.sel.size) toggleCollapse([...E.sel]); return; }
  if (k === '+' || k === '=') { zoomAt(1.2); return; } if (k === '-' || k === '_') { zoomAt(1 / 1.2); return; }
  if (k === 'Home') { fit(); return; }
  if (k === '?') { $('dHelp').showModal(); return; }
  if (k.startsWith('Arrow')) { ev.preventDefault();
    if (ev.altKey && one && (k === 'ArrowUp' || k === 'ArrowDown')) { if (MM.reorder(E.doc, E.primary, k === 'ArrowUp' ? -1 : 1)) commit(); return; }
    if (!E.primary) { const r = E.doc.root; if (E.L[r]) select([r]); return; } navArrow(k); return; }
  if (one && k.length === 1 && !ev.altKey && /[\p{L}\p{N}]/u.test(k)) { ev.preventDefault(); startEdit(E.primary, { replace: k }); }
});
function navArrow(k) {
  const cur = E.L[E.primary]; if (!cur) return; const cx = cur.x + cur.w / 2, cy = cur.y + cur.h / 2; let best = null, bs = Infinity;
  Object.keys(E.L).forEach(id => { if (id === E.primary) return; const l = E.L[id], x = l.x + l.w / 2 - cx, y = l.y + l.h / 2 - cy; let main, off;
    if (k === 'ArrowRight') { main = x; off = y; } else if (k === 'ArrowLeft') { main = -x; off = y; } else if (k === 'ArrowDown') { main = y; off = x; } else { main = -y; off = x; }
    if (main <= 4) return; const sc = main + 2.2 * Math.abs(off); if (sc < bs) { bs = sc; best = id; } });
  if (best) { select([best]); ensureVisible(best); }
}
function duplicateSel() { const ids = topSelected().filter(i => i !== E.doc.root); if (!ids.length) return; freezeFree(); const nw = ids.map(i => MM.duplicate(E.doc, i)).filter(Boolean); if (nw.length) { E.sel = new Set(nw); E.primary = nw[nw.length - 1]; commit(); } }
/* copiar, recortar e colar (inclui colar texto em lista) */
document.addEventListener('copy', ev => { if (!E || E.editing || (ev.target.matches && ev.target.matches('input,textarea'))) return; const ids = topSelected(); if (!ids.length) return; ev.preventDefault();
  ev.clipboardData.setData('application/x-boha-mm', JSON.stringify(MM.extract(E.doc, ids))); ev.clipboardData.setData('text/plain', MM.toOutline(E.doc, ids)); toast('Copiado.'); });
document.addEventListener('cut', ev => { if (!E || E.editing || (ev.target.matches && ev.target.matches('input,textarea'))) return; const ids = topSelected().filter(i => i !== E.doc.root); if (!ids.length) return; ev.preventDefault();
  ev.clipboardData.setData('application/x-boha-mm', JSON.stringify(MM.extract(E.doc, ids))); ev.clipboardData.setData('text/plain', MM.toOutline(E.doc, ids)); deleteSel(); });
document.addEventListener('paste', ev => {
  if (!E || E.editing || (ev.target.matches && ev.target.matches('input,textarea,select')) || document.querySelector('dialog[open]')) return; ev.preventDefault();
  let payload = null; const raw = ev.clipboardData.getData('application/x-boha-mm');
  if (raw) { try { const j = JSON.parse(raw); if (j && j.boha === 'mm1' && Array.isArray(j.trees)) payload = j; } catch (e) { payload = null; } }
  if (!payload) { const txt = ev.clipboardData.getData('text/plain'); if (!txt.trim()) return; const p = MM.parseOutline(txt); let trees = p.trees; if (p.title) trees = [{ text: p.title, children: p.trees }]; if (!trees.length) return; payload = { trees }; }
  const pid = E.primary || (E.focus || E.doc.root); freezeFree(); const nw = MM.insert(E.doc, pid, payload, null); E.sel = new Set(nw); E.primary = nw[nw.length - 1]; commit(); ensureVisible(E.primary); toast(nw.length + ' item' + (nw.length === 1 ? '' : 's') + ' colado' + (nw.length === 1 ? '' : 's') + '.');
});

/* ----- busca ----- */
function searchRun(q) {
  E.matches = MM.search(E.doc, q); E.matchSet = new Set(E.matches); E.mi = -1; if (E.matches.length) searchNext(1, true); else render();
  const s = $('status'); if (q) { s.className = ''; s.textContent = E.matches.length ? E.matches.length + ' encontrado' + (E.matches.length === 1 ? '' : 's') : 'Nada encontrado'; } else setStatus(E.dirty ? 'wait' : 'ok', E.dirty ? 'Não salvo' : 'Salvo');
}
function searchNext(d, silent) {
  if (!E.matches.length) return; E.mi = (E.mi + d + E.matches.length) % E.matches.length; const id = E.matches[E.mi];
  let p = E.doc.nodes[id].parent, open = false; while (p) { if (E.doc.nodes[p].collapsed) { E.doc.nodes[p].collapsed = false; open = true; } p = E.doc.nodes[p].parent; } if (open) markDirty();
  E.sel = new Set([id]); E.primary = id; render(); centerOn(id, true); updatePanel(); updateUndoUI();
  if (!silent || true) $('status').textContent = (E.mi + 1) + ' de ' + E.matches.length;
}
$('q').addEventListener('input', () => searchRun($('q').value));
$('q').addEventListener('keydown', ev => { ev.stopPropagation(); if (ev.key === 'Enter') { ev.preventDefault(); searchNext(ev.shiftKey ? -1 : 1); } else if (ev.key === 'Escape') { $('q').value = ''; searchRun(''); $('cv').focus(); } });

/* ----- menus ----- */
let MENU = null;
function closeMenu() { if (!MENU) return false; MENU.remove(); MENU = null; return true; }
function openMenu(btn, items) {
  if (closeMenu() && MENU === null && btn.dataset.open === '1') { btn.dataset.open = ''; return; }
  const m = document.createElement('div'); m.className = 'menu'; const pop = document.createElement('div'); pop.className = 'pop';
  items.forEach(it => { if (it === '-') { pop.appendChild(document.createElement('hr')); return; } const b = document.createElement('button'); b.innerHTML = it[0]; b.onclick = () => { closeMenu(); it[1](); }; pop.appendChild(b); });
  m.appendChild(pop); document.body.appendChild(m); const r = btn.getBoundingClientRect(); pop.style.top = (r.bottom + 6) + 'px'; pop.style.left = Math.max(8, Math.min(innerWidth - 230, r.left)) + 'px'; MENU = m;
  setTimeout(() => { const off = ev => { if (!m.contains(ev.target)) { closeMenu(); removeEventListener('pointerdown', off, true); } }; addEventListener('pointerdown', off, true); }, 0);
}
$('bLevels').addEventListener('click', ev => openMenu(ev.currentTarget, [['Expandir tudo', () => setLevels(null)], ['Recolher tudo', () => setLevels(0)], '-', ['Mostrar até o nível 1', () => setLevels(1)], ['Mostrar até o nível 2', () => setLevels(2)], ['Mostrar até o nível 3', () => setLevels(3)]]));

/* ----- exportar ----- */
async function svgToPng(svg, w, h, scale) {
  const img = new Image(), url = URL.createObjectURL(new Blob([svg], { type: 'image/svg+xml;charset=utf-8' }));
  await new Promise((res, rej) => { img.onload = res; img.onerror = rej; img.src = url; });
  const c = document.createElement('canvas'); c.width = Math.round(w * scale); c.height = Math.round(h * scale); const x = c.getContext('2d'); x.drawImage(img, 0, 0, c.width, c.height); URL.revokeObjectURL(url);
  return new Promise(res => c.toBlob(res, 'image/png'));
}
async function exportPNG() { try { const o = MM.toSVG(viewDoc()), sc = Math.min(2, 7000 / Math.max(o.w, o.h)), b = await svgToPng(o.svg, o.w, o.h, sc); download(b, slug(E.title) + '.png'); toast('Imagem PNG baixada.'); } catch (e) { toast('Não foi possível gerar a imagem. Tente o SVG.'); } }
function exportSVG() { const o = MM.toSVG(viewDoc()); download(new Blob([o.svg], { type: 'image/svg+xml' }), slug(E.title) + '.svg'); toast('SVG baixado.'); }
function exportPDF() {
  const o = MM.toSVG(viewDoc()), land = o.w >= o.h, f = document.createElement('iframe'); f.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0';
  f.srcdoc = '<!doctype html><meta charset="utf-8"><title>' + esc(E.title) + '</title><style>@page{size:A4 ' + (land ? 'landscape' : 'portrait') + ';margin:8mm}html,body{margin:0;background:#fff}svg{width:100%;height:auto;max-height:190mm;display:block;-webkit-print-color-adjust:exact;print-color-adjust:exact}</style>' + o.svg;
  f.onload = () => { try { f.contentWindow.focus(); f.contentWindow.print(); } catch (e) { toast('Não foi possível abrir a impressão.'); } setTimeout(() => f.remove(), 60000); }; document.body.appendChild(f); toast('Na janela de impressão, escolha “Salvar como PDF”.');
}
function exportMD() { download(new Blob([MM.toOutline(viewDoc())], { type: 'text/markdown' }), slug(E.title) + '.md'); toast('Texto baixado.'); }
function exportJSON() { download(new Blob([JSON.stringify({ boha: 'mapa', v: 1, title: E.title, doc: E.doc }, null, 1)], { type: 'application/json' }), slug(E.title) + '.boha-mapa.json'); toast('Backup baixado. Dá para importar de novo na lista de mapas.'); }
async function copyText(t) { try { await navigator.clipboard.writeText(t); return true; } catch (e) { try { const ta = document.createElement('textarea'); ta.value = t; ta.style.cssText = 'position:fixed;opacity:0;left:-999px'; document.body.appendChild(ta); ta.select(); const ok = document.execCommand('copy'); ta.remove(); return ok; } catch (e2) { return false; } } }
$('bExport').addEventListener('click', ev => openMenu(ev.currentTarget, [['🖼️ Imagem PNG', exportPNG], ['📐 Imagem vetorial SVG', exportSVG], ['📄 PDF (imprimir)', exportPDF], '-', ['📝 Texto em lista (.md)', exportMD], ['📋 Copiar como texto', async () => toast((await copyText(MM.toOutline(viewDoc()))) ? 'Texto copiado.' : 'Não foi possível copiar.')], '-', ['💾 Backup do mapa (.json)', exportJSON]]));

/* ----- mapa como texto ----- */
$('bText').addEventListener('click', () => { $('txBody').value = MM.toOutline(E.doc); $('txErr').textContent = ''; document.querySelector('input[name=txMode][value=replace]').checked = true; $('dText').showModal(); });
$('txCopy').addEventListener('click', async () => toast((await copyText($('txBody').value)) ? 'Texto copiado.' : 'Não foi possível copiar.'));
$('txApply').addEventListener('click', () => {
  const p = MM.parseOutline($('txBody').value); if (!p.trees.length && !p.title) { $('txErr').textContent = 'Escreva pelo menos um tópico.'; return; }
  const mode = document.querySelector('input[name=txMode]:checked').value;
  if (mode === 'add') { const pid = E.primary || E.doc.root; let trees = p.trees; if (p.title) trees = [{ text: p.title, children: p.trees }]; const nw = MM.insert(E.doc, pid, { trees }, null); E.sel = new Set(nw); E.primary = nw[nw.length - 1]; }
  else { const keep = E.doc.settings; const nd = MM.fromTree(p.trees, p.title || E.doc.nodes[E.doc.root].text); nd.settings = keep; if (nd.nodes[nd.root].text === '') nd.nodes[nd.root].text = E.title; E.doc = nd; E.sel.clear(); E.primary = null; E.focus = null; }
  $('dText').close(); commit(); requestAnimationFrame(() => fit()); toast('Mapa atualizado a partir do texto. Ctrl+Z desfaz.');
});

/* ----- histórico de versões ----- */
$('bHist').addEventListener('click', async () => { $('hErr').textContent = ''; $('hPrev').hidden = true; $('hName').value = ''; $('dHist').showModal(); await loadVersions(); });
async function loadVersions() {
  const box = $('hList'); box.innerHTML = '<div class="state" style="padding:20px">Carregando…</div>';
  const r = await C().from('boha_mindmap_versions').select('id,title,node_count,note,created_by,created_at').eq('map_id', E.id).order('created_at', { ascending: false }).limit(80);
  if (r.error) { box.innerHTML = ''; $('hErr').textContent = 'Não foi possível carregar o histórico.'; return; }
  const rows = r.data || [];
  box.innerHTML = rows.length ? rows.map(v => `<div class="vrow"><div><b>${esc(v.note || 'Versão automática')}</b><small>${fmtDT(v.created_at)} · ${esc(first(v.created_by))} · ${v.node_count} tópico${v.node_count === 1 ? '' : 's'}</small></div><div class="b"><button class="btn-g" data-vprev="${v.id}">Ver</button><button class="btn-g" data-vrest="${v.id}">Restaurar</button><button class="btn-g" data-vcopy="${v.id}">Abrir como novo</button><button class="btn-g danger" data-vdel="${v.id}" aria-label="Excluir versão">✕</button></div></div>`).join('')
    : '<div class="state" style="padding:20px">Ainda não há versões. Elas aparecem sozinhas conforme você edita, ou salve uma agora.</div>';
}
async function versionDoc(id) { const r = await C().from('boha_mindmap_versions').select('data,title').eq('id', id).single(); if (r.error || !r.data) throw new Error('x'); return { doc: MM.sanitize(r.data.data), title: r.data.title }; }
$('hSave').addEventListener('click', async () => {
  const b = $('hSave'); b.disabled = true; $('hErr').textContent = '';
  try { E.editing && finishEdit(true); const ok = await save({ force: true }); if (!ok) throw new Error('save'); await snapshot($('hName').value.trim() || 'Versão salva manualmente'); $('hName').value = ''; await loadVersions(); toast('Versão salva no histórico.'); }
  catch (e) { $('hErr').textContent = 'Não foi possível salvar a versão agora.'; } finally { b.disabled = false; }
});
$('hList').addEventListener('click', async ev => {
  const b = ev.target.closest('button'); if (!b) return; $('hErr').textContent = '';
  try {
    if (b.dataset.vprev) { const v = await versionDoc(b.dataset.vprev); const p = $('hPrev'); p.hidden = false; p.innerHTML = MM.thumb(v.doc); p.scrollIntoView({ block: 'nearest' }); }
    else if (b.dataset.vrest) {
      if (!confirm('Restaurar esta versão? A versão atual do mapa também será guardada no histórico, então nada se perde.')) return;
      const v = await versionDoc(b.dataset.vrest); E.editing && finishEdit(true); await save({ force: true }); await snapshot('Antes de restaurar uma versão antiga');
      E.doc = v.doc; E.sel.clear(); E.primary = null; E.focus = null; $('selLayout').value = E.doc.settings.layout; $('selTheme').value = E.doc.settings.theme; $('dHist').close(); commit(); requestAnimationFrame(() => fit()); toast('Versão restaurada. Ctrl+Z desfaz.');
    }
    else if (b.dataset.vcopy) { const v = await versionDoc(b.dataset.vcopy); const row = await createMap((v.title + ' (versão antiga)').slice(0, 120), v.doc); $('dHist').close(); toast('Versão aberta como um mapa novo.'); await closeEditor(); await openMap(row.id); }
    else if (b.dataset.vdel) { if (!confirm('Excluir esta versão do histórico?')) return; const r = await C().from('boha_mindmap_versions').delete().eq('id', b.dataset.vdel); if (r.error) throw r.error; await loadVersions(); }
  } catch (e) { $('hErr').textContent = 'Não foi possível concluir. Tente de novo.'; }
});
$('bHelp').addEventListener('click', () => $('dHelp').showModal());

/* ----- barra de ferramentas ----- */
$('bUndo').addEventListener('click', undo); $('bRedo').addEventListener('click', redo);
$('tChild').addEventListener('click', addChild); $('tSib').addEventListener('click', addSibling);
$('tFloat').addEventListener('click', () => { const r = stageRect(), w = toWorld(r.left + r.width / 2, r.top + r.height / 2); freezeFree(); addFloating(w.x - 60, w.y - 18); });
$('tLink').addEventListener('click', () => { if (E.mode === 'link') endLink(); else startLink(); });
$('tGroup').addEventListener('click', makeGroup); $('tDup').addEventListener('click', duplicateSel); $('tDel').addEventListener('click', deleteSel);
function togglePanel(on) { E.panelOpen = on == null ? !E.panelOpen : on; $('panel').hidden = !E.panelOpen; updateUndoUI(); requestAnimationFrame(() => { applyView(); }); }
$('tPanel').addEventListener('click', () => togglePanel());
$('zIn').addEventListener('click', () => zoomAt(1.2)); $('zOut').addEventListener('click', () => zoomAt(1 / 1.2)); $('zFit').addEventListener('click', () => fit());
$('bFocus').addEventListener('click', () => { if (E.focus) { E.focus = null; render(); fit(); } else if (E.sel.size === 1) { E.focus = E.primary; E.sel = new Set([E.primary]); render(); fit(); } updateUndoUI(); });
$('selLayout').addEventListener('change', () => { const v = $('selLayout').value; if (v === 'free') freezeNow(); E.doc.settings.layout = v; commit(); requestAnimationFrame(() => fit()); });
$('selTheme').addEventListener('change', () => { E.doc.settings.theme = $('selTheme').value; commit(); });
addEventListener('resize', () => { if (E) { applyView(); } });
new ResizeObserver(() => { if (E) applyView(); }).observe($('stage'));

/* ----- painel de estilo ----- */
function swatches(kind, cur, colors, allowNone) {
  return '<div class="sw">' + (allowNone ? '<button class="none" data-sw="' + kind + '" data-c="" aria-pressed="' + !cur + '" title="Automático"></button>' : '') +
    colors.map(c => '<button data-sw="' + kind + '" data-c="' + c + '" style="background:' + c + '" aria-pressed="' + (!!cur && cur.toLowerCase() === c.toLowerCase()) + '" title="' + c + '" aria-label="Cor ' + c + '"></button>').join('') +
    '<input type="color" data-cc="' + kind + '" value="' + (cur || '#ffffff') + '" aria-label="Escolher outra cor"></div>';
}
function updatePanel() {
  if (!E) return; const P = $('panel'), d = E.doc, th = THEME(), pal = th.palette.concat(['#ffffff', '#111111']);
  if (E.selLink) { const l = d.links.find(x => x.id === E.selLink); if (!l) { P.innerHTML = ''; return; }
    P.innerHTML = `<h3>Relação</h3><p class="sub">Liga dois tópicos de ramos diferentes.</p><input class="inp" id="lkLabel" maxlength="80" placeholder="Nome da relação (opcional)" value="${esc(l.label)}" aria-label="Nome da relação">
      <h3>Cor</h3>${swatches('lcolor', l.color, th.palette.concat(['#ffffff', '#111111']), true)}<h3>Traço</h3><div class="chips"><button data-lk="dash" aria-pressed="${l.dash !== false}">Tracejado</button><button data-lk="solid" aria-pressed="${l.dash === false}">Contínuo</button></div>
      <div class="pa"><button data-pa="swap">⇄ Inverter a seta</button><button class="danger" data-pa="del">Remover relação</button></div>`; return; }
  if (E.selGroup) { const g = d.groups.find(x => x.id === E.selGroup); if (!g) { P.innerHTML = ''; return; }
    P.innerHTML = `<h3>Fronteira</h3><p class="sub">Destaca um conjunto de tópicos e seus ramos.</p><input class="inp" id="grLabel" maxlength="60" placeholder="Nome da fronteira" value="${esc(g.label)}" aria-label="Nome da fronteira">
      <h3>Cor</h3>${swatches('gcolor', g.color, th.palette, false)}<div class="pa"><button class="danger" data-pa="delgroup">Remover fronteira</button></div>`; return; }
  if (!E.sel.size) {
    P.innerHTML = `<h3>Mapa</h3><p class="sub">Selecione um tópico para mudar o estilo dele. Aqui ficam os ajustes do mapa todo.</p>
      <h3>Tema de cores</h3><div class="thm">${Object.entries(MM.THEMES).map(([k, t]) => `<button data-theme="${k}" aria-pressed="${d.settings.theme === k}" style="background:${t.bg};color:${t.text}"><i>${t.palette.slice(0, 4).map(c => `<b style="background:${c}"></b>`).join('')}</i>${t.name}</button>`).join('')}</div>
      <h3>Organização</h3><div class="chips">${Object.entries(MM.LAYOUTS).map(([k, v]) => `<button data-layout="${k}" aria-pressed="${d.settings.layout === k}">${v.replace(' (posição manual)', '')}</button>`).join('')}</div>
      <h3>Linhas</h3><div class="chips">${Object.entries(MM.LINES).map(([k, v]) => `<button data-line="${k}" aria-pressed="${d.settings.line === k}">${v}</button>`).join('')}</div>
      <h3>Espessura</h3><div class="chips">${[1, 2, 3, 4].map(w => `<button data-lw="${w}" aria-pressed="${d.settings.lineW === w}">${w}</button>`).join('')}</div>
      <h3>Opções</h3><div class="row2"><label><input type="checkbox" data-st="branchColors" ${d.settings.branchColors ? 'checked' : ''}> Cor diferente em cada ramo</label><label><input type="checkbox" data-st="grid" ${d.settings.grid ? 'checked' : ''}> Mostrar grade de pontos</label></div>
      <h3>Informações</h3><p class="sub">${MM.count(d)} tópicos · ${d.links.length} relações · ${d.groups.length} fronteiras</p>`; return; }
  const n = d.nodes[E.primary]; if (!n) { P.innerHTML = ''; return; } const st = n.style || {}, l = E.L[E.primary] || {}, lk = l.lk || {}, multi = E.sel.size > 1;
  const isRoot = E.primary === d.root, topKid = n.parent === d.root;
  P.innerHTML = `<h3>${multi ? E.sel.size + ' tópicos selecionados' : 'Tópico'}</h3><p class="sub">${multi ? 'As mudanças valem para todos os selecionados.' : esc((n.text || 'Tópico').slice(0, 60))}</p>
  <h3>Texto</h3><div class="chips">${[['Auto', 0], ['P', 12], ['M', 14], ['G', 19], ['GG', 28]].map(([t, v]) => `<button data-fs="${v}" aria-pressed="${(st.fs || 0) === v}">${t}</button>`).join('')}<button data-tg="b" aria-pressed="${!!lk.bold}" style="font-weight:800">N</button><button data-tg="i" aria-pressed="${!!st.i}" style="font-style:italic">I</button></div>
  <div style="height:7px"></div>${swatches('color', st.color, ['#ffffff', '#111111', '#ff4d4d', '#ffd93d', '#4da3ff', '#3ddc84'], true)}
  <h3>Forma</h3><div class="chips">${Object.entries(MM.SHAPES).map(([k, v]) => `<button data-shape="${k}" aria-pressed="${(st.shape || '') === k}">${v}</button>`).join('')}<button data-shape="" aria-pressed="${!st.shape}">Auto</button></div>
  <h3>Preenchimento</h3>${swatches('fill', st.fill, pal, true)}<h3>Borda</h3>${swatches('stroke', st.stroke, pal, true)}
  <h3>Ícone</h3><div class="emo">${MM.ICONS.map(i => `<button data-icon="${i}" aria-pressed="${n.icon === i}">${i}</button>`).join('')}<button data-icon="" aria-pressed="${!n.icon}" title="Sem ícone" style="font-size:12px">✕</button></div>
  <h3>Prioridade</h3><div class="chips">${[1, 2, 3, 4, 5].map(p => `<button data-pri="${p}" aria-pressed="${n.pri === p}" style="${n.pri === p ? '' : 'border-color:' + MM.PRI_COLORS[p - 1]}">${p}</button>`).join('')}<button data-pri="0" aria-pressed="${!n.pri}">Sem</button></div>
  <h3>Tarefa e progresso</h3><div class="chips"><button data-tg="task" aria-pressed="${!!n.task}">☑ Tarefa</button>${n.task ? `<button data-tg="done" aria-pressed="${!!n.done}">Concluída</button>` : ''}</div><div style="height:6px"></div>
  <div class="chips">${[['Sem', ''], ['0%', 0], ['25%', 25], ['50%', 50], ['75%', 75], ['100%', 100]].map(([t, v]) => `<button data-prog="${v}" aria-pressed="${(n.prog == null ? '' : n.prog) === v}">${t}</button>`).join('')}</div>
  <h3>Etiquetas</h3><input class="inp" id="pTag" maxlength="24" placeholder="Digite e tecle Enter" aria-label="Nova etiqueta"><div class="tagl">${(n.tags || []).map((t, i) => `<span>${esc(t)}<button data-rmtag="${i}" aria-label="Remover etiqueta ${esc(t)}">×</button></span>`).join('')}</div>
  <h3>Nota</h3><textarea class="inp" id="pNote" maxlength="6000" placeholder="Detalhes, ideias, observações…" aria-label="Nota do tópico">${esc(n.note || '')}</textarea>
  <h3>Link</h3><input class="inp" id="pLink" type="url" inputmode="url" maxlength="500" placeholder="https://…" value="${esc(n.link || '')}" aria-label="Link do tópico">
  ${topKid && d.settings.layout === 'both' ? `<h3>Lado do mapa</h3><div class="chips"><button data-side="" aria-pressed="${!n.side}">Auto</button><button data-side="l" aria-pressed="${n.side === 'l'}">Esquerda</button><button data-side="r" aria-pressed="${n.side === 'r'}">Direita</button></div>` : ''}
  <h3>Ações</h3><div class="pa"><button data-pa="child">➕ Novo tópico filho</button>${!multi ? '<button data-pa="link">⤳ Criar relação com outro tópico</button><button data-pa="focus">◎ Focar neste ramo</button>' : ''}<button data-pa="group">▭ Agrupar em fronteira</button>${!isRoot ? '<button data-pa="detach">◌ Destacar como tópico solto</button><button data-pa="dup">⧉ Duplicar</button><button class="danger" data-pa="del">🗑 Excluir</button>' : ''}</div>`;
}
const styleOf = n => n.style || (n.style = {});
function forSel(fn) { const ids = [...E.sel]; if (!ids.length) return; ids.forEach(i => { const n = E.doc.nodes[i]; if (n) fn(n); }); ids.forEach(i => { const n = E.doc.nodes[i]; if (n && n.style && !Object.keys(n.style).length) delete n.style; }); commit(); }
function setColor(kind, c, ev) {
  if (kind === 'lcolor') { const l = E.doc.links.find(x => x.id === E.selLink); if (l) { l.color = c; commit(); } return; }
  if (kind === 'gcolor') { const g = E.doc.groups.find(x => x.id === E.selGroup); if (g) { g.color = c; commit(); } return; }
  forSel(n => { const s = styleOf(n); if (c) s[kind] = c; else delete s[kind]; });
}
$('panel').addEventListener('click', ev => {
  if (!E) return; const t = ev.target, b = t.closest('button'); if (!b) return; const D = b.dataset, doc = E.doc;
  if (D.sw !== undefined) { setColor(D.sw, D.c); return; }
  if (D.fs !== undefined) { const v = +D.fs; forSel(n => { const s = styleOf(n); if (v) s.fs = v; else delete s.fs; }); return; }
  if (D.tg) { const k = D.tg, cur = doc.nodes[E.primary]; if (k === 'b') { const on = !(E.L[E.primary] && E.L[E.primary].lk.bold); forSel(n => { styleOf(n).b = on; }); }
    else if (k === 'i') { const on = !(cur.style && cur.style.i); forSel(n => { const s = styleOf(n); if (on) s.i = true; else delete s.i; }); }
    else if (k === 'task') { const on = !cur.task; forSel(n => { if (on) n.task = true; else { delete n.task; delete n.done; } }); }
    else if (k === 'done') { const on = !cur.done; forSel(n => { if (n.task) { if (on) n.done = true; else delete n.done; } }); } return; }
  if (D.shape !== undefined) { forSel(n => { const s = styleOf(n); if (D.shape) s.shape = D.shape; else delete s.shape; }); return; }
  if (D.icon !== undefined) { forSel(n => { if (D.icon) n.icon = D.icon; else delete n.icon; }); return; }
  if (D.pri !== undefined) { const v = +D.pri; forSel(n => { if (v) n.pri = v; else delete n.pri; }); return; }
  if (D.prog !== undefined) { forSel(n => { if (D.prog === '') delete n.prog; else n.prog = +D.prog; }); return; }
  if (D.rmtag !== undefined) { forSel(n => { if (n.tags) { n.tags.splice(+D.rmtag, 1); if (!n.tags.length) delete n.tags; } }); return; }
  if (D.side !== undefined) { forSel(n => { if (D.side) n.side = D.side; else delete n.side; }); return; }
  if (D.theme) { doc.settings.theme = D.theme; $('selTheme').value = D.theme; commit(); return; }
  if (D.layout) { if (D.layout === 'free') freezeNow(); doc.settings.layout = D.layout; $('selLayout').value = D.layout; commit(); requestAnimationFrame(() => fit()); return; }
  if (D.line) { doc.settings.line = D.line; commit(); return; } if (D.lw) { doc.settings.lineW = +D.lw; commit(); return; }
  if (D.lk) { const l = doc.links.find(x => x.id === E.selLink); if (l) { l.dash = D.lk === 'dash'; commit(); } return; }
  if (D.pa) {
    const a = D.pa;
    if (a === 'child') addChild(); else if (a === 'link') startLink(); else if (a === 'focus') { E.focus = E.primary; render(); fit(); updateUndoUI(); }
    else if (a === 'group') makeGroup(); else if (a === 'dup') duplicateSel(); else if (a === 'del') deleteSel();
    else if (a === 'delgroup') deleteSel();
    else if (a === 'swap') { const l = doc.links.find(x => x.id === E.selLink); if (l) { const f = l.from; l.from = l.to; l.to = f; commit(); } }
    else if (a === 'detach') { const ids = topSelected().filter(i => i !== doc.root && doc.nodes[i].parent); if (!ids.length) return; freezeFree(); ids.forEach(i => { const l = E.L[i]; MM.move(doc, i, null, null, Math.round(l.x + 40), Math.round(l.y + 60)); }); commit(); toast('Tópico solto. Arraste sobre outro tópico para ligá-lo de novo.'); }
  }
});
$('panel').addEventListener('input', ev => {
  if (!E) return; const t = ev.target;
  if (t.id === 'lkLabel') { const l = E.doc.links.find(x => x.id === E.selLink); if (l) { l.label = t.value; render(); } }
  if (t.id === 'grLabel') { const g = E.doc.groups.find(x => x.id === E.selGroup); if (g) { g.label = t.value; render(); } }
});
$('panel').addEventListener('change', ev => {
  if (!E) return; const t = ev.target;
  if (t.id === 'lkLabel' || t.id === 'grLabel') { commit(); return; }
  if (t.id === 'pNote') { const v = t.value; forSel(n => { if (v.trim()) n.note = v; else delete n.note; }); return; }
  if (t.id === 'pLink') { const v = t.value.trim(); if (v && !MM.okUrl(v)) { toast('Use um link que comece com http:// ou https://'); t.value = (E.doc.nodes[E.primary] || {}).link || ''; return; } forSel(n => { if (v) n.link = MM.okUrl(v); else delete n.link; }); return; }
  if (t.dataset.cc) { setColor(t.dataset.cc, t.value); return; }
  if (t.dataset.st) { E.doc.settings[t.dataset.st] = t.checked; commit(); }
});
$('panel').addEventListener('keydown', ev => {
  ev.stopPropagation(); const t = ev.target;
  if (t.id === 'pTag' && ev.key === 'Enter') { ev.preventDefault(); const v = t.value.trim().slice(0, 24); if (!v) return; forSel(n => { n.tags = n.tags || []; if (!n.tags.includes(v) && n.tags.length < 8) n.tags.push(v); }); const i = $('pTag'); if (i) i.focus(); }
  if (ev.key === 'Escape') { ev.target.blur(); $('cv').focus(); }
});
$('stage').addEventListener('contextmenu', ev => ev.preventDefault());

/* ----- início ----- */
window.bohaReload = () => { if (!E) loadList().catch(() => {}); };
(async () => {
  if (!CTX || !CTX.client) { $('home').innerHTML = '<div class="state">Abra este módulo pelo <a href="../equipe.html#mapas" style="color:var(--y)">sistema interno da Boha</a>.</div>'; return; }
  if (CTX.canModule && !CTX.canModule('mapas')) { $('home').innerHTML = '<div class="state">Este módulo é só para o perfil de marketing.</div>'; return; }
  if (!['marketing', 'admin'].includes(CTX.profile && CTX.profile.role)) { $('home').innerHTML = '<div class="state">Este módulo é só para o perfil de marketing.</div>'; return; }
  try { await loadList(); setInterval(() => { if (!E && !document.hidden && !document.querySelector('dialog[open]')) loadList().catch(() => {}); }, 40000); }
  catch (e) { $('home').innerHTML = '<div class="state">Não foi possível carregar os mapas. Atualize a página.</div>'; }
})();
})();
