/*
 * Arkher AI — aplicação web (vanilla JS, zero dependências).
 * Funciona conectado ao servidor Python (geração completa) ou 100% offline
 * no aparelho via window.ArkherOffline (APK / PWA sem rede).
 */
"use strict";

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => Array.from(document.querySelectorAll(sel));

const State = {
  server: localStorage.getItem("arkher_server") || "",
  offline: localStorage.getItem("arkher_offline") === "1",
  status: null,
  materials: [],
  lastAssets: {},
};

function apiBase() {
  return State.offline ? "" : (State.server || "").replace(/\/+$/, "");
}

async function api(path, opts = {}) {
  const base = apiBase();
  const res = await fetch(base + path, {
    headers: { "Content-Type": "application/json" },
    ...opts,
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const ctype = res.headers.get("content-type") || "";
  if (ctype.includes("json")) return res.json();
  return res;
}

async function runJob(kind, body, onPoll) {
  // Geração assíncrona: POST /api/jobs -> poll /api/jobs/<id>.
  // Evita "failed to fetch" em gerações longas (SDF, mo-cap, texturas 4k+)
  // que derrubavam o timeout do fetch no celular.
  const created = await api("/api/jobs", { method: "POST", body: JSON.stringify({ kind, body }) });
  if (!created || !created.job_id) throw new Error("servidor não criou o job (atualize o server.py)");
  const t0 = Date.now();
  for (;;) {
    await sleep(900);
    const j = await api("/api/jobs/" + created.job_id);
    const secs = (Date.now() - t0) / 1000;
    if (onPoll) onPoll(j, secs);
    if (j.status === "done") return j.result;
    if (j.status === "error") throw new Error(j.error || ("erro no job (" + (j.error_type || "?") + ")"));
    if (secs > 1800) throw new Error("job excedeu 30 min — tente reduzir resolução/detalhe");
  }
}

function fileToB64(file) {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(String(r.result).split(",")[1] || "");
    r.onerror = () => reject(new Error("falha ao ler o arquivo"));
    r.readAsDataURL(file);
  });
}

function fileToText(file) {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(String(r.result));
    r.onerror = () => reject(new Error("falha ao ler o arquivo"));
    r.readAsText(file);
  });
}

function fmtBytes(n) {
  if (n > 1024 * 1024) return (n / 1024 / 1024).toFixed(1) + " MB";
  if (n > 1024) return (n / 1024).toFixed(1) + " KB";
  return n + " B";
}

// ============================================================ boot
async function boot() {
  if ("serviceWorker" in navigator && location.protocol.startsWith("http")) {
    navigator.serviceWorker.register("sw.js").catch(() => {});
  }
  // Dentro do APK (Capacitor): recupera a URL salva nas prefs nativas
  try {
    const plugin = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.ServerConfig;
    if (plugin) {
      const cfg = await plugin.getServerUrl();
      if (cfg && cfg.mode === "offline") {
        State.offline = true;
        localStorage.setItem("arkher_offline", "1");
      } else if (cfg && cfg.url && !localStorage.getItem("arkher_server")) {
        State.server = cfg.url;
      }
      State.inApk = true;
    }
  } catch (e) {
    /* fora do APK */
  }
  bindNav();
  bindChat();
  bindGodot();
  bindRoblox();
  bindModel();
  bindTextures();
  bindAnimation();
  bindCode();
  bindSettings();
  await refreshStatus();
  addBotMessage(null, welcomeText(), [
    { label: "Gerar projeto Godot", tab: "godot" },
    { label: "Gerar projeto Roblox", tab: "roblox" },
    { label: "Gerar modelo 3D", tab: "model" },
  ]);
}

function welcomeText() {
  if (State.offline) {
    return "Modo OFFLINE ativo: eu gero projetos, modelos e texturas aqui no aparelho.\nConecte ao servidor do PC (⚙ Servidor) para o arsenal completo.";
  }
  if (State.status) {
    return `Olá! Sou o time Arkher AI — 9 especialistas em Godot 4 e Roblox.\n\nBackend conectado: texturas até ${State.status.texture_max >= 8192 ? "16k" : "2k"}${State.status.numpy ? " (numpy acelerado)" : ""}, modelos .glb com LODs, rig de 22 ossos com animações e export R15 para Roblox.\n\nMe diga o que você quer construir, ou use os botões abaixo.`;
  }
  return "Não achei o servidor de geração. Ativo os geradores offline do aparelho (projetos, modelos e texturas até 1k). Para tudo: configure ⚙ Servidor com o endereço do seu PC.";
}

async function refreshStatus() {
  const badge = $("#connBadge"), text = $("#connText"), pill = $("#numpyPill");
  try {
    if (State.offline) throw new Error("offline");
    State.status = await api("/api/status");
    badge.className = "conn online";
    text.textContent = State.server ? "servidor: " + State.server : "servidor local";
    const prov = (State.status.capabilities && State.status.capabilities.mesh_ai_providers) || {};
    const provTxt = prov.active ? ("mesh IA: " + prov.active) : "mesh IA: offline (SDF/relevo)";
    pill.textContent = (State.status.numpy ? "numpy ✔" : "python puro") + " · até " + (State.status.texture_max >= 16384 ? "16k" : "2k") + " · " + provTxt;
    const bl = (State.status.capabilities && State.status.capabilities.blender_kernel) || {};
    const blEl = $("#mBlenderState");
    if (blEl) {
      blEl.textContent = bl.available
        ? ("Blender " + (bl.version || "") + " detectado ✔ (kernel nativo ativo)")
        : "Blender não instalado no servidor (o refino fica desativado; ARKHER_BLENDER ou `pip install bpy` ativam)";
      blEl.style.color = bl.available ? "var(--ok, #4ade80)" : "";
    }
    const agents = await api("/api/agents");
    renderAgents(agents.agents);
  } catch (e) {
    State.status = null;
    if (!State.offline) State.offline = true;
    badge.className = "conn offline";
    text.textContent = "offline (no aparelho)";
    pill.textContent = "geradores JS no aparelho";
    renderAgents(null);
  }
}

function renderAgents(agents) {
  const el = $("#agentsList");
  if (!agents) {
    el.innerHTML = '<div class="muted">Time em modo offline — respostas e geração local.</div>';
    return;
  }
  el.innerHTML = agents
    .map(
      (a) => `<div class="agent-row"><span class="dot2"></span><div><b>${a.name}</b><span>${a.role} · ${a.years} anos</span></div></div>`
    )
    .join("");
}

// ============================================================ navegação
const TAB_TITLES = {
  chat: "Chat com o time",
  godot: "Projeto Godot 4",
  roblox: "Projeto Roblox (Rojo)",
  model: "Modelo 3D (.glb)",
  textures: "Texturas PBR",
  animation: "Rig + Animações",
  code: "Biblioteca de código",
  about: "Sobre / honestidade",
};

function bindNav() {
  $$(".nav-btn").forEach((btn) => {
    btn.addEventListener("click", () => switchTab(btn.dataset.tab));
  });
  $("#menuToggle").addEventListener("click", () => $("#sidebar").classList.toggle("open"));
}

function switchTab(tab) {
  $$(".nav-btn").forEach((b) => b.classList.toggle("active", b.dataset.tab === tab));
  $$(".view").forEach((v) => v.classList.toggle("active", v.id === "view-" + tab));
  $("#pageTitle").textContent = TAB_TITLES[tab] || tab;
  $("#sidebar").classList.remove("open");
}

// ============================================================ chat
function addMessage(who, text, isUser, actions) {
  const log = $("#chatLog");
  const div = document.createElement("div");
  div.className = "msg" + (isUser ? " user" : "");
  const initials = isUser ? "VC" : (who ? who.name.split(" ").map((p) => p[0]).join("").slice(0, 2) : "AK");
  div.innerHTML = `<div class="avatar">${initials}</div><div><div class="who">${
    isUser ? "Você" : who ? `${who.name} — ${who.role}` : "Arkher AI"
  }</div><div class="bubble"></div>${actions && actions.length ? '<div class="actions"></div>' : ""}</div>`;
  div.querySelector(".bubble").textContent = text;
  if (actions && actions.length) {
    const box = div.querySelector(".actions");
    actions.forEach((a) => {
      const b = document.createElement("button");
      b.textContent = a.label;
      b.onclick = () => switchTab(a.tab);
      box.appendChild(b);
    });
  }
  log.appendChild(div);
  log.scrollTop = log.scrollHeight;
  return div;
}

function addBotMessage(who, text, actions) {
  return addMessage(who, text, false, actions);
}

function bindChat() {
  const form = $("#chatForm");
  const input = $("#chatText");
  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      form.requestSubmit();
    }
  });
  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const text = input.value.trim();
    if (!text) return;
    input.value = "";
    addMessage(null, text, true);
    const typing = addMessage({ name: "• •", role: "digitando" }, "", false);
    typing.classList.add("typing");
    try {
      let out;
      if (State.offline || !State.status) {
        await new Promise((r) => setTimeout(r, 350));
        out = ArkherOffline.chatRespond(text);
      } else {
        out = await api("/api/chat", { method: "POST", body: JSON.stringify({ message: text }) });
      }
      typing.remove();
      addBotMessage(out.agent || null, out.text, out.actions || []);
    } catch (err) {
      typing.remove();
      const out = ArkherOffline.chatRespond(text);
      addBotMessage(null, out.text + "\n\n(fallback offline: " + err.message + ")", out.actions);
    }
  });
}

// ============================================================ projetos
function renderProjectResult(container, data) {
  const badgeOk =
    data.engine === "godot"
      ? Object.keys(data.validation.errors || {}).length === 0
        ? '<span class="badge ok">✔ formato .tscn validado</span>'
        : '<span class="badge warn">⚠ ver validação</span>'
      : data.validation.json_ok
      ? '<span class="badge ok">✔ JSON Rojo válido</span>'
      : '<span class="badge warn">⚠ JSON</span>';
  const tree = data.tree
    .map((f) => {
      const isDir = f.path.includes("/");
      return `<div><span class="${f.binary ? "bin" : isDir ? "dir" : ""}">${f.binary ? "◈" : "·"} ${f.path}</span> <span class="muted">${fmtBytes(f.bytes)}</span></div>`;
    })
    .join("");
  container.innerHTML = `
    <h2>Projeto pronto 🎉</h2>
    <div>${badgeOk}<span class="badge info">${data.files_count} arquivos</span><span class="badge info">${fmtBytes(data.total_bytes)}</span>${data.offline ? '<span class="badge warn">modo offline</span>' : ""}</div>
    <div class="dl-row">
      <button class="dl-btn" id="dlProject">⬇ Baixar .zip do projeto</button>
    </div>
    <div class="tree">${tree}</div>
    ${data.readme ? `<h3>README (prévia)</h3><pre class="readme">${escapeHtml(data.readme)}</pre>` : ""}
  `;
  container.querySelector("#dlProject").addEventListener("click", () => {
    if (data.offline) {
      const entry = State.lastAssets[data.asset_id];
      downloadBytes(entry.zip, (entry.name || "projeto").replace(/\s+/g, "_") + "_" + data.engine + "_arkher.zip");
    } else {
      location.href = apiBase() + "/api/download/project/" + data.asset_id;
    }
  });
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
}

function bindGodot() {
  $("#gGenerate").addEventListener("click", async () => {
    const btn = $("#gGenerate");
    const progress = $("#gProgress");
    btn.disabled = true;
    progress.hidden = false;
    $("#gProgressText").textContent = "montando cenas, scripts e lighting…";
    try {
      const body = {
        engine: "godot",
        name: $("#gName").value,
        description: $("#gDesc").value,
        genre: $("#gGenre").value,
        features: $$("#view-godot .checks input:checked").map((i) => i.value),
      };
      let data;
      if (State.offline || !State.status) {
        await sleep(400);
        const files = ArkherOffline.godotProject(body);
        data = offlineProjectResult(files, "godot", body.name);
      } else {
        data = await runJob("project", body);
      }
      renderProjectResult($("#gResult"), data);
    } catch (e) {
      $("#gResult").innerHTML = `<div class="empty-state">Erro: ${escapeHtml(e.message)}</div>`;
    } finally {
      btn.disabled = false;
      progress.hidden = true;
    }
  });
}

function bindRoblox() {
  $("#rGenerate").addEventListener("click", async () => {
    const btn = $("#rGenerate");
    btn.disabled = true;
    $("#rProgress").hidden = false;
    try {
      const body = { engine: "roblox", name: $("#rName").value, description: $("#rDesc").value, genre: $("#rGenre").value };
      let data;
      if (State.offline || !State.status) {
        await sleep(400);
        const files = ArkherOffline.robloxProject(body);
        data = offlineProjectResult(files, "roblox", body.name);
      } else {
        data = await runJob("project", body);
      }
      renderProjectResult($("#rResult"), data);
    } catch (e) {
      $("#rResult").innerHTML = `<div class="empty-state">Erro: ${escapeHtml(e.message)}</div>`;
    } finally {
      btn.disabled = false;
      $("#rProgress").hidden = true;
    }
  });
}

function offlineProjectResult(files, engine, name) {
  const zip = ArkherOffline.makeZip(files);
  const id = "off" + Date.now().toString(36);
  State.lastAssets[id] = { zip, name };
  return {
    asset_id: id,
    engine,
    files_count: Object.keys(files).length,
    total_bytes: zip.length,
    tree: Object.entries(files).map(([p, c]) => ({ path: p, bytes: c.length, binary: false })),
    validation: engine === "godot" ? { errors: {} } : { json_ok: true },
    readme: files["README.md"] || "",
    offline: true,
  };
}

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

// ============================================================ modelo 3D
const MATERIAL_CHOICES = [
  ["generic", "Genérico"], ["stone", "Pedra"], ["brick", "Tijolo"], ["metal", "Metal"],
  ["steel_brushed", "Aço escovado"], ["gold", "Ouro"], ["wood", "Madeira"], ["leather", "Couro"],
  ["fabric", "Tecido"], ["grass", "Grama"], ["dirt", "Terra"], ["sand", "Areia"], ["ice", "Gelo"],
  ["marble", "Mármore"], ["lava", "Lava"], ["concrete", "Concreto"], ["asphalt", "Asfalto"],
  ["skin", "Pele"], ["crystal", "Cristal"],
];
const ANIM_CHOICES = ["idle", "walk", "run", "sprint", "jump", "attack_melee", "wave", "dance", "death", "crouch"];

function bindModel() {
  const sel = $("#mMaterial");
  sel.innerHTML = MATERIAL_CHOICES.map(([v, l]) => `<option value="${v}">${l}</option>`).join("");
  const chips = $("#mAnims");
  chips.innerHTML = ANIM_CHOICES.map((a, i) => `<button type="button" class="chip ${i < 4 ? "on" : ""}" data-anim="${a}">${a}</button>`).join("");
  chips.addEventListener("click", (e) => {
    if (e.target.classList.contains("chip")) e.target.classList.toggle("on");
  });
  $("#mDetail").addEventListener("input", (e) => ($("#mDetailOut").textContent = e.target.value));
  const srcSel = $("#mSource");
  const syncSource = () => {
    const v = srcSel.value;
    $("#mAiFields").hidden = (v === "primitives");
    $("#mType").closest("label").hidden = (v !== "primitives");
    const rigRow = $("#mRigRow");
    if (rigRow) rigRow.hidden = false;
  };
  if (srcSel) {
    srcSel.addEventListener("change", syncSource);
    syncSource();
    $("#mSdfRes").addEventListener("input", (e) => ($("#mSdfOut").textContent = e.target.value));
  }

  $("#mGenerate").addEventListener("click", async () => {
    const btn = $("#mGenerate");
    btn.disabled = true;
    $("#mProgress").hidden = false;
    $("#mProgressText").textContent = "gerando malha, UVs e material…";
    try {
      const anims = $$("#mAnims .chip.on").map((c) => c.dataset.anim);
      const source = ($("#mSource") || {}).value || "primitives";
      const body = {
        type: $("#mType").value,
        name: $("#mName").value || $("#mType").value,
        detail: +$("#mDetail").value,
        lods: $("#mLods").checked,
        rig: $("#mRig").checked && (source !== "primitives" || ["hero", "humanoid", "npc", "creature"].includes($("#mType").value)),
        animations: anims,
        material: $("#mMaterial").value,
        source,
      };
      const refineBl = ($("#mRefineBlender") || {}).checked;
      if (refineBl) {
        body.refine_blender = true;
        if (body.rig) {
          throw new Error("Refinar no Blender faz Voxel Remesh, que destrói o rig/skinning. " +
            "Desmarque 'Com rig + animações' para refinar a malha estática no Blender.");
        }
      }
      if (source !== "primitives") {
        body.prompt = ($("#mPrompt").value || "").trim();
        body.sdf_resolution = +$("#mSdfRes").value;
        const f = $("#mImage").files && $("#mImage").files[0];
        if (f) {
          $("#mProgressText").textContent = "enviando imagem (" + fmtBytes(f.size) + ")…";
          body.image_b64 = await fileToB64(f);
        }
        if (!body.prompt && !body.image_b64) {
          throw new Error("Escreva uma descrição ou envie uma imagem (ou escolha 'Primitivas').");
        }
      }
      let result;
      if (State.offline || !State.status) {
        if (body.source && body.source !== "primitives") {
          throw new Error("Escultura SDF, IA generativa e relevo de imagem rodam no servidor Python. " +
            "Offline eu gero modelos por primitivas — conecte o servidor (aba Configurações) para malha orgânica.");
        }
        await sleep(300);
        const mesh = ArkherOffline.buildModel(body.type, body.detail);
        const glb = ArkherOffline.buildGlb(mesh, { name: body.name + "_mat" }, body.name);
        const id = "offm" + Date.now().toString(36);
        State.lastAssets[id] = { files: { [body.name + ".glb"]: glb } };
        result = {
          asset_id: id,
          offline: true,
          stats: {
            triangles: mesh.idx.length / 3,
            vertices: mesh.pos.length / 3,
            bones: 0,
            animations: [],
            files: [body.name + ".glb"],
            bytes: glb.length,
          },
          glbInline: glb,
        };
      } else if (body.source && body.source !== "primitives") {
        result = await runJob("model", body, (j, secs) => {
          $("#mProgressText").textContent = j.status === "running"
            ? `esculpindo malha orgânica… ${secs.toFixed(0)}s (job ${j.status})`
            : `na fila… ${secs.toFixed(0)}s`;
        });
      } else {
        result = await api("/api/generate/model", { method: "POST", body: JSON.stringify(body) });
      }
      await renderModelResult(result);
    } catch (e) {
      $("#mResult").innerHTML = `<div class="empty-state">Erro: ${escapeHtml(e.message)}</div>`;
    } finally {
      btn.disabled = false;
      $("#mProgress").hidden = true;
    }
  });
}

async function renderModelResult(result) {
  const s = result.stats;
  const container = $("#mResult");
  const animList = Array.isArray(s.animations) && s.animations.length
    ? s.animations.map((a) => `<span class="badge info">${a.name} ${a.duration}s</span>`).join(" ")
    : "";
  const lods = s.lods ? s.lods.map((l) => `<span class="badge info">LOD${l.level}: ${l.triangles} tris</span>`).join(" ") : "";
  const originBadge = s.origin
    ? `<span class="badge ${String(s.origin).startsWith("provider") ? "ok" : "info"}">origem: ${escapeHtml(String(s.origin))}${s.sculpt_kind ? " · " + escapeHtml(s.sculpt_kind) : ""}</span>`
    : "";
  const provErr = s.provider_error ? `<div class="info-box">⚠️ Provedor de IA indisponível (${escapeHtml(String(s.provider_error))}) — usei a rota offline (escultura/relevo).</div>` : "";
  const rigSkip = s.rig_skipped ? `<div class="info-box">${escapeHtml(String(s.rig_skipped))}</div>` : "";
  const originNote = s.origin === "sculpt" || s.origin === "relief"
    ? `<div class="info-box">Malha orgânica real (SDF/surface nets ou relevo da sua imagem) — sem primitivas. Para IA generativa de nuvem, configure MESHY_API_KEY / TRIPO_API_KEY / ARKHER_MESH_AI_URL no servidor.</div>`
    : "";
  const blenderBadge = s.blender
    ? `<span class="badge ok">refinado no Blender ${escapeHtml(String(s.blender.blender_version || ""))} · ${s.blender.tris_before || "?"}→${s.blender.tris_after || "?"} tris · Remesh+SmartUV</span>`
    : "";
  const blenderNote = s.blender_skipped
    ? `<div class="info-box">🔧 Blender: ${escapeHtml(String(s.blender_skipped))}</div>`
    : (s.blender_error ? `<div class="info-box">⚠️ Blender falhou (${escapeHtml(String(s.blender_error))}) — malha Arkher mantida.</div>` : "");
  container.innerHTML = `
    <h2>Modelo pronto 🎉</h2>
    <div>${originBadge}${blenderBadge}</div>
    ${provErr}${rigSkip}${blenderNote}${originNote}
    <canvas class="viewer" id="glbViewer"></canvas>
    <div class="muted" style="margin:6px 0">arraste para girar · role para zoom</div>
    <div class="stats-grid">
      <div class="stat"><b>${(s.triangles || 0).toLocaleString("pt-BR")}</b><span>triângulos</span></div>
      <div class="stat"><b>${(s.vertices || 0).toLocaleString("pt-BR")}</b><span>vértices</span></div>
      <div class="stat"><b>${s.bones || 0}</b><span>ossos</span></div>
      <div class="stat"><b>${fmtBytes(s.bytes || 0)}</b><span>total</span></div>
    </div>
    <div>${animList}${lods}</div>
    <div class="dl-row" id="mDownloads"></div>
  `;
  const dl = container.querySelector("#mDownloads");
  const files = s.files || [];
  files.forEach((f) => {
    const b = document.createElement("button");
    b.className = "dl-btn";
    b.textContent = "⬇ " + f;
    b.onclick = () => {
      if (result.offline) downloadBytes(State.lastAssets[result.asset_id].files[f], f);
      else location.href = apiBase() + "/api/asset/" + result.asset_id + "/" + f;
    };
    dl.appendChild(b);
  });
  const zb = document.createElement("button");
  zb.className = "dl-btn";
  zb.textContent = "⬇ tudo (.zip)";
  zb.onclick = () => {
    if (result.offline) {
      downloadBytes(ArkherOffline.makeZip(State.lastAssets[result.asset_id].files), "arkher_model.zip");
    } else location.href = apiBase() + "/api/download/model/" + result.asset_id;
  };
  dl.appendChild(zb);

  // preview — com verificação robusta (antes, erro do servidor virava "não é glb")
  let glbBytes = result.glbInline;
  if (!glbBytes) {
    const mainFile = files.find((f) => f.endsWith(".glb") && !f.includes("lods")) || files.find((f) => f.endsWith(".glb"));
    if (mainFile) {
      try {
        const res = await fetch(apiBase() + "/api/asset/" + result.asset_id + "/" + mainFile);
        if (!res.ok) throw new Error("HTTP " + res.status + " ao baixar " + mainFile);
        glbBytes = new Uint8Array(await res.arrayBuffer());
        const isGlb = glbBytes.length > 20 && glbBytes[0] === 0x67 && glbBytes[1] === 0x6c
          && glbBytes[2] === 0x54 && glbBytes[3] === 0x46;
        if (!isGlb) {
          let msg = "resposta não é um GLB";
          try { msg = JSON.parse(new TextDecoder().decode(glbBytes)).error || msg; } catch (_) {}
          throw new Error(msg + " (o asset pode ter expirado — gere novamente)");
        }
      } catch (e) {
        const cv = $("#glbViewer");
        if (cv) cv.outerHTML = `<div class="info-box">⚠️ Preview indisponível: ${escapeHtml(e.message)}. Os downloads abaixo continuam válidos.</div>`;
        return;
      }
    }
  }
  if (glbBytes) {
    try {
      startViewer($("#glbViewer"), glbBytes);
    } catch (e) {
      const cv = $("#glbViewer");
      if (cv) cv.outerHTML = `<div class="info-box">⚠️ Viewer: ${escapeHtml(e.message)}</div>`;
    }
  }
}

function downloadBytes(bytes, name) {
  const blob = new Blob([bytes], { type: "application/octet-stream" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 4000);
}

// ------------------------------------------------- visualizador glTF (software)
function parseGlb(bytes) {
  const dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  if (dv.getUint32(0, true) !== 0x46546c67) throw new Error("não é glb");
  let off = 12, json = null, bin = null;
  while (off < dv.byteLength) {
    const len = dv.getUint32(off, true);
    const type = dv.getUint32(off + 4, true);
    const chunk = bytes.subarray(off + 8, off + 8 + len);
    if (type === 0x4e4f534a) json = JSON.parse(new TextDecoder().decode(chunk));
    else if (type === 0x004e4942) bin = chunk;
    off += 8 + len;
  }
  return { json, bin };
}

function startViewer(canvas, glbBytes) {
  const { json, bin } = parseGlb(glbBytes);
  const mesh = json.meshes[0];
  const prim = mesh.primitives[0];
  const posAcc = json.accessors[prim.attributes.POSITION];
  const nrmAcc = json.accessors[prim.attributes.NORMAL];
  const idxAcc = json.accessors[prim.indices];

  function readAccessor(acc) {
    const bv = json.bufferViews[acc.bufferView];
    const byteOff = (bv.byteOffset || 0) + (acc.byteOffset || 0);
    if (acc.componentType === 5126) return new Float32Array(bin.buffer, bin.byteOffset + byteOff, acc.count * (acc.type === "VEC3" ? 3 : acc.type === "VEC2" ? 2 : 4));
    if (acc.componentType === 5123) return new Uint16Array(bin.buffer, bin.byteOffset + byteOff, acc.count);
    if (acc.componentType === 5125) return new Uint32Array(bin.buffer, bin.byteOffset + byteOff, acc.count);
    throw new Error("componentType não suportado no viewer");
  }
  const pos = readAccessor(posAcc);
  const nrm = readAccessor(nrmAcc);
  const idx = readAccessor(idxAcc);

  // limita triângulos para o rasterizador de software
  const MAX_TRIS = 40000;
  const triCount = Math.min(idx.length / 3, MAX_TRIS);

  const ctx = canvas.getContext("2d");
  let rotY = 0.6, rotX = -0.25, zoom = 1, dragging = false, lx = 0, ly = 0;
  let auto = true;

  function resize() {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    canvas.width = canvas.clientWidth * dpr;
    canvas.height = canvas.clientHeight * dpr;
  }
  resize();
  window.addEventListener("resize", resize);

  function bounds() {
    let mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
    for (let i = 0; i < pos.length; i += 3) for (let c = 0; c < 3; c++) {
      mn[c] = Math.min(mn[c], pos[i + c]); mx[c] = Math.max(mx[c], pos[i + c]);
    }
    return { mn, mx, center: mn.map((v, i) => (v + mx[i]) / 2), radius: Math.hypot(mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2]) / 2 };
  }
  const B = bounds();

  canvas.addEventListener("pointerdown", (e) => { dragging = true; auto = false; lx = e.clientX; ly = e.clientY; canvas.setPointerCapture(e.pointerId); });
  canvas.addEventListener("pointerup", () => (dragging = false));
  canvas.addEventListener("pointermove", (e) => {
    if (!dragging) return;
    rotY += (e.clientX - lx) * 0.008;
    rotX += (e.clientY - ly) * 0.006;
    rotX = Math.max(-1.4, Math.min(1.4, rotX));
    lx = e.clientX; ly = e.clientY;
  });
  canvas.addEventListener("wheel", (e) => { e.preventDefault(); zoom = Math.max(0.3, Math.min(4, zoom * (e.deltaY > 0 ? 0.92 : 1.08))); }, { passive: false });

  function frame() {
    if (auto) rotY += 0.006;
    const W = canvas.width, H = canvas.height;
    ctx.clearRect(0, 0, W, H);
    const cy = Math.cos(rotY), sy = Math.sin(rotY), cx = Math.cos(rotX), sx = Math.sin(rotX);
    const scale = (Math.min(W, H) / (B.radius * 2.6)) * zoom;
    const light = normalize3([0.4, 0.8, 0.45]);

    const tris = [];
    for (let t = 0; t < triCount; t++) {
      const a = idx[t * 3], b = idx[t * 3 + 1], c = idx[t * 3 + 2];
      const pts = [a, b, c].map((i) => {
        let x = pos[i * 3] - B.center[0], y = pos[i * 3 + 1] - B.center[1], z = pos[i * 3 + 2] - B.center[2];
        let x1 = x * cy + z * sy, z1 = -x * sy + z * cy;
        let y1 = y * cx - z1 * sx, z2 = y * sx + z1 * cx;
        return [W / 2 + x1 * scale, H / 2 - y1 * scale, z2];
      });
      const depth = (pts[0][2] + pts[1][2] + pts[2][2]) / 3;
      let nx = nrm[a * 3], ny = nrm[a * 3 + 1], nz = nrm[a * 3 + 2];
      const nx1 = nx * cy + nz * sy, nz1 = -nx * sy + nz * cy;
      const ny1 = ny * cx - nz1 * sx, nz2 = ny * sx + nz1 * cx;
      const lum = Math.max(0.12, nx1 * light[0] + ny1 * light[1] + nz2 * light[2]);
      tris.push({ pts, depth, lum });
    }
    tris.sort((p, q) => p.depth - q.depth);
    for (const tr of tris) {
      const g = Math.round(70 + tr.lum * 150);
      ctx.fillStyle = `rgb(${Math.round(g * 0.62)},${Math.round(g * 0.82)},${g})`;
      ctx.beginPath();
      ctx.moveTo(tr.pts[0][0], tr.pts[0][1]);
      ctx.lineTo(tr.pts[1][0], tr.pts[1][1]);
      ctx.lineTo(tr.pts[2][0], tr.pts[2][1]);
      ctx.closePath();
      ctx.fill();
    }
    requestAnimationFrame(frame);
  }
  frame();
}

function normalize3(v) {
  const l = Math.hypot(v[0], v[1], v[2]) || 1;
  return [v[0] / l, v[1] / l, v[2] / l];
}

// ============================================================ texturas
function bindTextures() {
  const grid = $("#matGrid");
  const swatches = {
    stone: "#706e6b", brick: "#8c4534", metal: "#9ea1a8", steel_brushed: "#b8bac0", gold: "#ffc656",
    wood: "#78502e", leather: "#543421", fabric: "#6b4d4d", grass: "#3d6b29", dirt: "#57402b",
    sand: "#d1bd94", ice: "#b8dbf2", marble: "#e6e4e0", lava: "#2a1714", concrete: "#9e9e9b",
    asphalt: "#29292b", skin: "#c2917a", crystal: "#5a9ef2", generic: "#999aa0",
  };
  const labels = {
    stone: "Pedra", brick: "Tijolo", metal: "Metal", steel_brushed: "Aço escovado", gold: "Ouro",
    wood: "Madeira", leather: "Couro", fabric: "Tecido", grass: "Grama", dirt: "Terra", sand: "Areia",
    ice: "Gelo", marble: "Mármore", lava: "Lava", concrete: "Concreto", asphalt: "Asfalto",
    skin: "Pele", crystal: "Cristal", generic: "Genérico",
  };
  grid.innerHTML = Object.keys(swatches)
    .map((k, i) => `<div class="mat-card ${i === 0 ? "selected" : ""}" data-mat="${k}"><div class="swatch" style="background:linear-gradient(135deg, ${swatches[k]}, ${shade(swatches[k], -30)})"></div><b>${labels[k]}</b></div>`)
    .join("");
  grid.addEventListener("click", (e) => {
    const card = e.target.closest(".mat-card");
    if (!card) return;
    $$(".mat-card").forEach((c) => c.classList.remove("selected"));
    card.classList.add("selected");
  });

  $("#tGenerate").addEventListener("click", async () => {
    const btn = $("#tGenerate");
    btn.disabled = true;
    $("#tProgress").hidden = false;
    const mat = ($(".mat-card.selected") || {}).dataset?.mat || "stone";
    const resSel = $("#tRes").value;
    const imgFile = ($("#tImage").files && $("#tImage").files[0]) || null;
    $("#tProgressText").textContent = imgFile
      ? `derivando PBR da sua foto em ${resSel}…`
      : `gerando ${resSel} de ${mat}… (mapas PBR)`;
    const t0 = performance.now();
    try {
      if (imgFile && imgFile.size > 40 * 1024 * 1024) throw new Error("imagem grande demais (máx 40 MB)");
      if (imgFile && (State.offline || !State.status)) {
        throw new Error("Derivar PBR da sua foto roda no servidor Python. Conecte o servidor (aba Configurações) — offline eu gero texturas procedurais.");
      }
      if (!imgFile && (State.offline || !State.status)) {
        const size = Math.min(1024, { "512": 512, "1k": 1024, "2k": 1024, "4k": 1024, "8k": 1024, "16k": 1024 }[resSel]);
        await sleep(50);
        const maps = ArkherOffline.generateTextures(mat, size, +$("#tSeed").value || 7);
        renderTexturePreviewOffline(mat, size, maps);
      } else {
        const body = { material: mat, resolution: resSel, seed: +$("#tSeed").value || 1337, tile: $("#tTile").checked };
        let data;
        if (imgFile) {
          body.image_b64 = await fileToB64(imgFile);
          data = await runJob("textures", body, (j, secs) => {
            $("#tProgressText").textContent = `derivando PBR da foto… ${secs.toFixed(0)}s`;
          });
        } else if (resSel === "4k" || resSel === "8k" || resSel === "16k") {
          data = await runJob("textures", body, (j, secs) => {
            $("#tProgressText").textContent = `gerando ${resSel} de ${mat}… ${secs.toFixed(0)}s`;
          });
        } else {
          data = await api("/api/generate/textures", { method: "POST", body: JSON.stringify(body) });
        }
        renderTexturePreview(imgFile ? "foto" : mat, data);
      }
    } catch (e) {
      $("#tPreview").innerHTML = `<div class="empty-state">Erro: ${escapeHtml(e.message)}</div>`;
    } finally {
      btn.disabled = false;
      $("#tProgress").hidden = true;
      $("#tEta").textContent = `${((performance.now() - t0) / 1000).toFixed(1)}s`;
    }
  });
}

function shade(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  const r = Math.max(0, Math.min(255, (n >> 16) + amt));
  const g = Math.max(0, Math.min(255, ((n >> 8) & 0xff) + amt));
  const b = Math.max(0, Math.min(255, (n & 0xff) + amt));
  return `rgb(${r},${g},${b})`;
}

function renderTexturePreview(mat, data) {
  const box = $("#tPreview");
  const caps = data.maps.map((m) => {
    const url = apiBase() + "/api/asset/" + data.asset_id + "/" + m.file;
    return `<div class="tex-item"><img loading="lazy" src="${url}" alt="${m.channel}"><div class="cap"><b>${m.channel}</b><span>${m.color_space} · ${fmtBytes(m.bytes)}</span></div></div>`;
  }).join("");
  const secs = data.stats.seconds != null ? data.stats.seconds : data.stats.elapsed_s;
  const mp = data.stats.megapixels != null ? data.stats.megapixels
    : (data.stats.source ? data.stats.source.megapixels + " MP (foto original)" : "?");
  const derived = data.derived_from_image ? `<span class="badge ok">derivado da sua foto (${escapeHtml(String((data.stats.source || {}).format || "?"))} ${((data.stats.source || {}).width || "?")}×${((data.stats.source || {}).height || "?")})</span>` : "";
  box.innerHTML = `
    <div style="grid-column:1/-1">
      <span class="badge ok">${data.stats.size}px</span>
      ${secs != null ? `<span class="badge info">${secs}s</span>` : ""}
      <span class="badge info">${mp} MP/mapa</span>
      ${derived}
      ${data.capped ? `<span class="badge warn">limitado a ${data.stats.size}px: ${escapeHtml(data.limit_reason || "")}</span>` : ""}
      <div class="dl-row" style="display:inline-flex;margin-left:12px">
        <button class="dl-btn" onclick="location.href='${apiBase()}/api/download/textures/${data.asset_id}'">⬇ Baixar pacote PBR (.zip)</button>
      </div>
    </div>` + caps;
}

function renderTexturePreviewOffline(mat, size, maps) {
  const box = $("#tPreview");
  const order = ["albedo", "normal", "roughness", "metallic", "ao", "height"];
  box.innerHTML =
    `<div style="grid-column:1/-1"><span class="badge ok">${size}px (offline)</span>
     <span class="badge info">gerado no aparelho</span>
     <div class="dl-row" style="display:inline-flex;margin-left:12px"><button class="dl-btn" id="tDlZip">⬇ Baixar .zip</button></div></div>` +
    order
      .map((ch) => `<div class="tex-item"><img id="tex-${ch}" alt="${ch}"><div class="cap"><b>${ch}</b><span>offline</span></div></div>`)
      .join("");
  const files = {};
  for (const ch of order) {
    const canvas = maps[ch];
    document.getElementById("tex-" + ch).src = canvas.toDataURL("image/png");
    files[`${mat}_${ch}_${size}.png`] = dataURLBytes(canvas.toDataURL("image/png"));
  }
  $("#tDlZip").onclick = () => downloadBytes(ArkherOffline.makeZip(files), `arkher_${mat}_${size}.zip`);
}

function dataURLBytes(url) {
  const b64 = url.split(",")[1];
  const bin = atob(b64);
  const arr = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
  return arr;
}

// ============================================================ animações
function bindAnimation() {
  const chips = $("#aAnims");
  chips.innerHTML = ANIM_CHOICES.map((a, i) => `<button type="button" class="chip ${i < 4 ? "on" : ""}" data-anim="${a}">${a}</button>`).join("");
  chips.addEventListener("click", (e) => {
    if (e.target.classList.contains("chip")) e.target.classList.toggle("on");
  });
  $("#aGenerate").addEventListener("click", async () => {
    const btn = $("#aGenerate");
    btn.disabled = true;
    $("#aProgress").hidden = false;
    try {
      const anims = $$("#aAnims .chip.on").map((c) => c.dataset.anim);
      if (State.offline || !State.status) {
        throw new Error("Animações com rig completo rodam no servidor conectado. Offline eu gero o modelo base na aba Modelo 3D.");
      }
      const body = { animations: anims, fps: +$("#aFps").value, detail: +$("#aDetail").value };
      const bvhFile = ($("#aBvh").files && $("#aBvh").files[0]) || null;
      if (bvhFile) {
        if (bvhFile.size > 60 * 1024 * 1024) throw new Error("BVH grande demais (máx 60 MB)");
        $("#aProgressText").textContent = "lendo .bvh e retargetando mo-cap…";
        body.bvh = await fileToText(bvhFile);
      }
      const data = await runJob("animation", body, (j, secs) => {
        $("#aProgressText").textContent = `gerando rig + takes… ${secs.toFixed(0)}s`;
      });
      const s = data.stats;
      $("#aResult").innerHTML = `
        <h2>Rig + animações prontos 🦴</h2>
        <div class="stats-grid">
          <div class="stat"><b>${s.bones}</b><span>ossos</span></div>
          <div class="stat"><b>${(s.triangles || 0).toLocaleString("pt-BR")}</b><span>triângulos</span></div>
          <div class="stat"><b>${s.animations.length}</b><span>takes</span></div>
          <div class="stat"><b>${fmtBytes(s.bytes)}</b><span>pacote</span></div>
        </div>
        <div>${(s.animations || []).map((a) => `<span class="badge ${a.kind === "mocap" ? "ok" : "info"}">${a.name} · ${a.duration}s · ${a.frames} frames · ${a.bones_animated} ossos${a.kind === "mocap" ? " · MO-CAP REAL" : ""}</span>`).join(" ")}</div>
        ${s.mocap ? `<div class="info-box">🎬 Mo-cap importado: ${s.mocap.source_frames} frames @ ${s.mocap.source_fps}fps do seu .bvh → ${s.mocap.frames} frames retargetados com IK (escala ${s.mocap.scale}). Juntas mapeadas: ${Object.keys(s.mocap.mapped_joints || {}).length}.</div>` : ""}
        <div class="dl-row">
          <button class="dl-btn" onclick="location.href='${apiBase()}/api/asset/${data.asset_id}/character_rigged.glb'">⬇ character_rigged.glb</button>
          <button class="dl-btn" onclick="location.href='${apiBase()}/api/asset/${data.asset_id}/godot_animation_library.tres'">⬇ Godot .tres</button>
          ${(s.files || []).filter((f) => f.endsWith(".rbxlx")).map((f) => `<button class="dl-btn" onclick="location.href='${apiBase()}/api/asset/${data.asset_id}/${f}'">⬇ R15 ${f.replace("roblox_", "").replace(".rbxlx", "")}.rbxlx</button>`).join("")}
          <button class="dl-btn" onclick="location.href='${apiBase()}/api/download/animation/${data.asset_id}'">⬇ tudo (.zip)</button>
        </div>
        <div class="info-box">No Godot: importe o .glb e os takes aparecem no AnimationPlayer com esses nomes. No Roblox Studio: Animation Editor → importe o .rbxlx e publique o asset.</div>
      `;
    } catch (e) {
      $("#aResult").innerHTML = `<div class="empty-state">${escapeHtml(e.message)}</div>`;
    } finally {
      btn.disabled = false;
      $("#aProgress").hidden = true;
    }
  });
}

// ============================================================ código
let codeEngine = "";
function bindCode() {
  const search = $("#codeSearch");
  search.addEventListener("input", () => loadCode(search.value));
  $("#codeEngines").addEventListener("click", (e) => {
    if (!e.target.classList.contains("chip")) return;
    $$("#codeEngines .chip").forEach((c) => c.classList.remove("active"));
    e.target.classList.add("active");
    codeEngine = e.target.dataset.engine;
    loadCode(search.value);
  });
  loadCode("");
}

async function loadCode(q) {
  const list = $("#codeList");
  let snippets;
  if (State.offline || !State.status) {
    snippets = ArkherOffline.snippets.filter((s) => !codeEngine || s.engine === codeEngine);
  } else {
    try {
      const data = await api(`/api/code?q=${encodeURIComponent(q || "")}&engine=${codeEngine}`);
      snippets = data.snippets;
    } catch (e) {
      snippets = ArkherOffline.snippets;
    }
  }
  if (q && !State.offline) snippets = snippets.filter((s) => (s.title + s.tags.join(" ") + s.note).toLowerCase().includes(q.toLowerCase()));
  list.innerHTML = snippets
    .map(
      (s) => `
    <div class="snippet">
      <header><b>${escapeHtml(s.title)}</b><span class="tag badge ${s.engine === "godot" ? "ok" : "info"}">${s.engine}</span><span class="badge info">${s.lang}</span></header>
      <pre>${escapeHtml(s.code)}</pre>
      <div class="note">${escapeHtml(s.note)}</div>
      <div class="actions">
        <button class="dl-btn" data-copy="${s.id}">⧉ copiar</button>
        <button class="dl-btn" data-dl="${s.id}">⬇ baixar</button>
      </div>
    </div>`
    )
    .join("") || '<div class="empty-state">Nada encontrado com esses filtros.</div>';
  list.querySelectorAll("[data-copy]").forEach((b) => {
    b.onclick = () => {
      const s = snippets.find((x) => x.id === b.dataset.copy);
      navigator.clipboard.writeText(s.code);
      b.textContent = "✔ copiado";
      setTimeout(() => (b.textContent = "⧉ copiar"), 1400);
    };
  });
  list.querySelectorAll("[data-dl]").forEach((b) => {
    b.onclick = () => {
      const s = snippets.find((x) => x.id === b.dataset.dl);
      const ext = s.lang === "lua" ? ".lua" : s.lang === "glsl" ? ".gdshader" : ".gd";
      downloadBytes(new TextEncoder().encode(s.code), s.id + ext);
    };
  });
}

// ============================================================ settings
function bindSettings() {
  const modal = $("#settingsModal");
  $("#btnSettings").onclick = () => {
    $("#serverUrl").value = State.server;
    modal.hidden = false;
  };
  modal.addEventListener("click", (e) => {
    if (e.target === modal) modal.hidden = true;
  });
  const persistNative = (url, mode) => {
    try {
      const plugin = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.ServerConfig;
      if (plugin) plugin.setServerUrl({ url, mode });
    } catch (e) { /* navegador */ }
  };

  $("#settingsSave").onclick = async () => {
    const url = $("#serverUrl").value.trim();
    State.server = url;
    State.offline = false;
    localStorage.setItem("arkher_server", url);
    localStorage.removeItem("arkher_offline");
    persistNative(url, "server");
    $("#settingsMsg").textContent = "testando…";
    await refreshStatus();
    $("#settingsMsg").textContent = State.status ? "✔ conectado!" : "✘ não respondeu — voltando para offline";
    if (!State.status) {
      State.offline = true;
      localStorage.setItem("arkher_offline", "1");
    }
    modal.hidden = true;
    await refreshStatus();
  };
  $("#settingsOffline").onclick = () => {
    State.offline = true;
    localStorage.setItem("arkher_offline", "1");
    persistNative(State.server || "", "offline");
    modal.hidden = true;
    refreshStatus();
  };
}

boot();
