/*
 * ArkherOffline — geradores que rodam NO APARELHO (sem servidor).
 * Usados pelo APK em modo offline e pelo site quando o servidor não responde.
 *
 * Entregáveis reais offline:
 *   - projeto Godot (zip com project.godot, cenas, scripts, README, GDD)
 *   - projeto Roblox (zip com default.project.json + Luau server-authoritative)
 *   - modelos .glb (primitivas compostas com normais/UVs/material PBR)
 *   - texturas PBR procedurais (canvas, até 1k offline)
 *   - biblioteca de código essencial
 *   - roteador de chat (intenção -> aba/ação)
 *   - writer de ZIP (método store, com CRC32)
 */
(function () {
  "use strict";

  // ============================================================ CRC32 + ZIP
  const CRC_TABLE = (() => {
    const t = new Int32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      t[n] = c;
    }
    return t;
  })();
  function crc32(bytes) {
    let c = -1;
    for (let i = 0; i < bytes.length; i++) c = CRC_TABLE[(c ^ bytes[i]) & 0xff] ^ (c >>> 8);
    return (c ^ -1) >>> 0;
  }
  function strBytes(s) { return new TextEncoder().encode(s); }

  function makeZip(files) {
    // files: { nome: Uint8Array|string }
    const chunks = [];
    const central = [];
    let offset = 0;
    const now = new Date();
    const dosTime = ((now.getHours() << 11) | (now.getMinutes() << 5) | (now.getSeconds() >> 1)) & 0xffff;
    const dosDate = (((now.getFullYear() - 1980) << 9) | ((now.getMonth() + 1) << 5) | now.getDate()) & 0xffff;

    for (const [name, content] of Object.entries(files)) {
      const data = typeof content === "string" ? strBytes(content) : content;
      const nameB = strBytes(name);
      const crc = crc32(data);
      const local = new DataView(new ArrayBuffer(30));
      local.setUint32(0, 0x04034b50, true);
      local.setUint16(4, 20, true);
      local.setUint16(6, 0x0800, true); // UTF-8
      local.setUint16(8, 0, true); // store
      local.setUint16(10, dosTime, true);
      local.setUint16(12, dosDate, true);
      local.setUint32(14, crc, true);
      local.setUint32(18, data.length, true);
      local.setUint32(22, data.length, true);
      local.setUint16(26, nameB.length, true);
      local.setUint16(28, 0, true);
      chunks.push(new Uint8Array(local.buffer), nameB, data);

      const cd = new DataView(new ArrayBuffer(46));
      cd.setUint32(0, 0x02014b50, true);
      cd.setUint16(4, 20, true);
      cd.setUint16(6, 20, true);
      cd.setUint16(8, 0x0800, true);
      cd.setUint16(10, 0, true);
      cd.setUint16(12, dosTime, true);
      cd.setUint16(14, dosDate, true);
      cd.setUint32(16, crc, true);
      cd.setUint32(20, data.length, true);
      cd.setUint32(24, data.length, true);
      cd.setUint16(28, nameB.length, true);
      cd.setUint32(42, offset, true);
      central.push(new Uint8Array(cd.buffer), nameB);
      offset += 30 + nameB.length + data.length;
    }

    let cdSize = 0;
    central.forEach((c) => (cdSize += c.length));
    const end = new DataView(new ArrayBuffer(22));
    end.setUint32(0, 0x06054b50, true);
    end.setUint16(8, Object.keys(files).length, true);
    end.setUint16(10, Object.keys(files).length, true);
    end.setUint32(12, cdSize, true);
    end.setUint32(16, offset, true);

    const total = offset + cdSize + 22;
    const out = new Uint8Array(total);
    let p = 0;
    for (const c of [...chunks, ...central, new Uint8Array(end.buffer)]) {
      out.set(c, p);
      p += c.length;
    }
    return out;
  }

  // ================================================== primitivas 3D (JS)
  function meshBuilder() {
    return { pos: [], nrm: [], uv: [], idx: [] };
  }
  function pushVert(m, p, n, uv) {
    m.pos.push(p[0], p[1], p[2]);
    m.nrm.push(n[0], n[1], n[2]);
    m.uv.push(uv[0], uv[1]);
    return m.pos.length / 3 - 1;
  }
  function addTri(m, a, b, c) { m.idx.push(a, b, c); }

  function norm(v) {
    const l = Math.hypot(v[0], v[1], v[2]) || 1;
    return [v[0] / l, v[1] / l, v[2] / l];
  }
  function cross(a, b) {
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  }
  function sub(a, b) { return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]; }

  function addBox(m, w, h, d, cx, cy, cz) {
    const x0 = cx - w / 2, y0 = cy - h / 2, z0 = cz - d / 2;
    const x1 = cx + w / 2, y1 = cy + h / 2, z1 = cz + d / 2;
    const faces = [
      [[x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1], [0, 0, 1]],
      [[x1, y0, z0], [x0, y0, z0], [x0, y1, z0], [x1, y1, z0], [0, 0, -1]],
      [[x0, y1, z1], [x1, y1, z1], [x1, y1, z0], [x0, y1, z0], [0, 1, 0]],
      [[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1], [0, -1, 0]],
      [[x1, y0, z1], [x1, y0, z0], [x1, y1, z0], [x1, y1, z1], [1, 0, 0]],
      [[x0, y0, z0], [x0, y0, z1], [x0, y1, z1], [x0, y1, z0], [-1, 0, 0]],
    ];
    for (const f of faces) {
      const base = m.pos.length / 3;
      for (let i = 0; i < 4; i++) pushVert(m, f[i], f[4], [[0, 0], [1, 0], [1, 1], [0, 1]][i]);
      addTri(m, base, base + 1, base + 2);
      addTri(m, base, base + 2, base + 3);
    }
  }

  function addSphere(m, r, cx, cy, cz, rings, sectors, squash) {
    const sq = squash || [1, 1, 1];
    const base = m.pos.length / 3;
    for (let ri = 0; ri <= rings; ri++) {
      const phi = (Math.PI * ri) / rings;
      for (let si = 0; si <= sectors; si++) {
        const th = (2 * Math.PI * si) / sectors;
        const nx = Math.sin(phi) * Math.cos(th), ny = Math.cos(phi), nz = Math.sin(phi) * Math.sin(th);
        pushVert(m, [cx + nx * r * sq[0], cy + ny * r * sq[1], cz + nz * r * sq[2]], [nx, ny, nz], [si / sectors, 1 - ri / rings]);
      }
    }
    for (let ri = 0; ri < rings; ri++) {
      for (let si = 0; si < sectors; si++) {
        const a = base + ri * (sectors + 1) + si, b = a + sectors + 1;
        if (ri !== 0) addTri(m, a, b, a + 1);
        if (ri !== rings - 1) addTri(m, a + 1, b, b + 1);
      }
    }
  }

  function addCylinder(m, r, h, cx, cy, cz, sectors, caps) {
    const base = m.pos.length / 3;
    for (let i = 0; i <= sectors; i++) {
      const th = (2 * Math.PI * i) / sectors;
      const c = Math.cos(th), s = Math.sin(th);
      pushVert(m, [cx + r * c, cy - h / 2, cz + r * s], [c, 0, s], [i / sectors, 0]);
      pushVert(m, [cx + r * c, cy + h / 2, cz + r * s], [c, 0, s], [i / sectors, 1]);
    }
    for (let i = 0; i < sectors; i++) {
      const a = base + i * 2;
      addTri(m, a, a + 2, a + 3);
      addTri(m, a, a + 3, a + 1);
    }
    if (caps !== false) {
      for (const yy of [-h / 2, h / 2]) {
        const cb = m.pos.length / 3;
        pushVert(m, [cx, cy + yy, cz], [0, yy < 0 ? -1 : 1, 0], [0.5, 0.5]);
        for (let i = 0; i < sectors; i++) {
          const th = (2 * Math.PI * i) / sectors;
          pushVert(m, [cx + r * Math.cos(th), cy + yy, cz + r * Math.sin(th)], [0, yy < 0 ? -1 : 1, 0], [0.5 + 0.5 * Math.cos(th), 0.5 + 0.5 * Math.sin(th)]);
        }
        for (let i = 0; i < sectors; i++) {
          const p = cb + 1 + i, q = cb + 1 + ((i + 1) % sectors);
          if (yy > 0) addTri(m, cb, q, p); else addTri(m, cb, p, q);
        }
      }
    }
  }

  function addCapsule(m, r, h, cx, cy, cz) {
    const cyl = Math.max(0, h - 2 * r);
    addCylinder(m, r, cyl, cx, cy, cz, 14, false);
    addSphere(m, r, cx, cy + cyl / 2, cz, 8, 14);
    addSphere(m, r, cx, cy - cyl / 2, cz, 8, 14);
  }

  // ------------------------------------------------- modelos compostos
  const MODELS = {
    hero(m, d) {
      addSphere(m, 0.115, 0, 1.62, 0, 8 + d * 3, 12 + d * 4, [0.92, 1.12, 0.98]);
      addCylinder(m, 0.055, 0.1, 0, 1.5, 0, 10);
      addBox(m, 0.42, 0.34, 0.24, 0, 1.28, 0);
      addBox(m, 0.36, 0.26, 0.22, 0, 0.99, 0);
      addBox(m, 0.4, 0.16, 0.23, 0, 0.86, 0);
      for (const s of [1, -1]) {
        addSphere(m, 0.075, 0.245 * s, 1.42, 0, 6, 10);
        addCapsule(m, 0.055, 0.3, 0.27 * s, 1.24, 0);
        addCapsule(m, 0.048, 0.28, 0.27 * s, 0.95, 0);
        addBox(m, 0.07, 0.11, 0.045, 0.27 * s, 0.78, 0);
        addCapsule(m, 0.085, 0.44, 0.115 * s, 0.6, 0);
        addCapsule(m, 0.065, 0.42, 0.115 * s, 0.22, 0);
        addBox(m, 0.1, 0.07, 0.26, 0.115 * s, 0.035, 0.05);
      }
    },
    creature(m, d) {
      addSphere(m, 0.42, 0, 0.75, 0, 8 + d * 3, 12 + d * 4, [1, 0.85, 1.35]);
      addSphere(m, 0.24, 0, 0.95, 0.62, 8, 12, [1, 0.95, 1.1]);
      for (const s of [1, -1]) {
        addCapsule(m, 0.09, 0.5, 0.32 * s, 0.45, 0.25);
        addCapsule(m, 0.09, 0.5, 0.3 * s, 0.45, -0.3);
      }
      addCapsule(m, 0.05, 0.7, 0, 0.85, -0.72);
    },
    tree(m, d) {
      addCylinder(m, 0.16, 2.2, 0, 1.1, 0, 10 + d * 3);
      addSphere(m, 0.95, 0, 2.6, 0, 8 + d * 3, 12 + d * 4, [1, 0.85, 1]);
      addSphere(m, 0.62, 0.5, 2.35, 0.2, 6, 10);
      addSphere(m, 0.55, -0.45, 2.45, -0.25, 6, 10);
    },
    rock(m, d) {
      const base = m.pos.length / 3;
      addSphere(m, 0.8, 0, 0.35, 0, 8 + d * 4, 12 + d * 5);
      let seed = 7;
      const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
      for (let i = base; i < m.pos.length / 3; i++) {
        m.pos[i * 3] *= 0.82 + rnd() * 0.36;
        m.pos[i * 3 + 1] = 0.35 + (m.pos[i * 3 + 1] - 0.35) * (0.7 + rnd() * 0.45);
        m.pos[i * 3 + 2] *= 0.82 + rnd() * 0.36;
      }
    },
    sword(m) {
      addBox(m, 0.05, 0.012, 0.95, 0, 0, 0.55);
      addBox(m, 0.26, 0.03, 0.05, 0, 0, 0.06);
      addCylinder(m, 0.022, 0.24, 0, 0, -0.08, 10);
      addSphere(m, 0.035, 0, 0, -0.22, 6, 10);
    },
    house(m) {
      addBox(m, 4, 2.6, 3.2, 0, 1.3, 0);
      addBox(m, 4.2, 0.15, 3.4, 0, 0.075, 0);
      addBox(m, 0.9, 1.8, 0.08, 0, 0.9, 1.62);
      addBox(m, 0.7, 0.7, 0.06, 1.3, 1.6, 1.62);
      addBox(m, 0.7, 0.7, 0.06, -1.3, 1.6, 1.62);
      addCylinder(m, 0.28, 1.1, 1.2, 3.1, -0.8, 10);
      // telhado (2 planos)
      const ridge = 3.9, eave = 2.6;
      const verts = [
        [[-2.2, eave, 1.8], [2.2, eave, 1.8], [2.2, ridge, 0], [-2.2, ridge, 0], [0, 0.6, 0.8]],
        [[2.2, eave, -1.8], [-2.2, eave, -1.8], [-2.2, ridge, 0], [2.2, ridge, 0], [0, 0.6, -0.8]],
      ];
      for (const f of verts) {
        const b = m.pos.length / 3;
        const n = norm(f[4]);
        for (let i = 0; i < 4; i++) pushVert(m, f[i], n, [[0, 0], [1, 0], [1, 1], [0, 1]][i]);
        addTri(m, b, b + 1, b + 2); addTri(m, b, b + 2, b + 3);
      }
    },
    prop(m) {
      addCylinder(m, 0.35, 0.9, 0, 0.45, 0, 14);
      addCylinder(m, 0.37, 0.06, 0, 0.68, 0, 14);
      addCylinder(m, 0.37, 0.06, 0, 0.22, 0, 14);
    },
    sphere(m, d) { addSphere(m, 0.6, 0, 0.6, 0, 10 + d * 4, 16 + d * 5); },
    cube(m) { addBox(m, 1, 1, 1, 0, 0.5, 0); },
    terrain(m, d) {
      const seg = 12 + d * 6, size = 24;
      const base = m.pos.length / 3;
      let seed = 3;
      const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
      const grid = [];
      for (let i = 0; i < 64; i++) grid.push(rnd());
      const sample = (u, v) => {
        const x = u * 7, y = v * 7;
        const xi = Math.floor(x) % 8, yi = Math.floor(y) % 8;
        const fx = x - Math.floor(x), fy = y - Math.floor(y);
        const g = (a, b) => grid[((b % 8) * 8 + (a % 8)) | 0];
        const t = g(xi, yi) + (g(xi + 1, yi) - g(xi, yi)) * fx;
        const b2 = g(xi, yi + 1) + (g(xi + 1, yi + 1) - g(xi, yi + 1)) * fx;
        return (t + (b2 - t) * fy) * 2 - 1;
      };
      for (let j = 0; j <= seg; j++) {
        for (let i = 0; i <= seg; i++) {
          const u = i / seg, v = j / seg;
          pushVert(m, [-size / 2 + u * size, sample(u, v) * 1.6, -size / 2 + v * size], [0, 1, 0], [u, v]);
        }
      }
      for (let j = 0; j < seg; j++) for (let i = 0; i < seg; i++) {
        const a = base + j * (seg + 1) + i, b = a + seg + 1;
        addTri(m, a, b, a + 1); addTri(m, a + 1, b, b + 1);
      }
      // normais por média
      const acc = new Float32Array((m.pos.length / 3) * 3);
      for (let t = 0; t < m.idx.length; t += 3) {
        const [ia, ib, ic] = [m.idx[t], m.idx[t + 1], m.idx[t + 2]];
        const pa = [m.pos[ia * 3], m.pos[ia * 3 + 1], m.pos[ia * 3 + 2]];
        const pb = [m.pos[ib * 3], m.pos[ib * 3 + 1], m.pos[ib * 3 + 2]];
        const pc = [m.pos[ic * 3], m.pos[ic * 3 + 1], m.pos[ic * 3 + 2]];
        const fn = cross(sub(pb, pa), sub(pc, pa));
        for (const ix of [ia, ib, ic]) { acc[ix * 3] += fn[0]; acc[ix * 3 + 1] += fn[1]; acc[ix * 3 + 2] += fn[2]; }
      }
      for (let i = 0; i < m.pos.length / 3; i++) {
        const n = norm([acc[i * 3], acc[i * 3 + 1], acc[i * 3 + 2]]);
        m.nrm[i * 3] = n[0]; m.nrm[i * 3 + 1] = n[1]; m.nrm[i * 3 + 2] = n[2];
      }
    },
  };

  // ------------------------------------------------------- writer GLB (JS)
  function buildGlb(mesh, material, name) {
    const pos = new Float32Array(mesh.pos);
    const nrm = new Float32Array(mesh.nrm);
    const uv = new Float32Array(mesh.uv);
    const use16 = pos.length / 3 <= 65535;
    const idx = use16 ? new Uint16Array(mesh.idx) : new Uint32Array(mesh.idx);

    const bin = [];
    let binLen = 0;
    function addView(typed) {
      const bytes = new Uint8Array(typed.buffer, typed.byteOffset, typed.byteLength);
      while (binLen % 4) { bin.push(new Uint8Array([0])); binLen += 1; }
      const off = binLen;
      bin.push(bytes);
      binLen += bytes.length;
      return { off, len: bytes.length };
    }
    const vPos = addView(pos), vNrm = addView(nrm), vUv = addView(uv), vIdx = addView(idx);

    const mins = [Infinity, Infinity, Infinity], maxs = [-Infinity, -Infinity, -Infinity];
    for (let i = 0; i < pos.length; i += 3) for (let c = 0; c < 3; c++) {
      mins[c] = Math.min(mins[c], pos[i + c]);
      maxs[c] = Math.max(maxs[c], pos[i + c]);
    }

    const gltf = {
      asset: { version: "2.0", generator: "Arkher AI (offline JS)" },
      scene: 0,
      scenes: [{ nodes: [0] }],
      nodes: [{ name: name || "ArkherModel", mesh: 0 }],
      meshes: [{ name: name || "mesh", primitives: [{ attributes: { POSITION: 0, NORMAL: 1, TEXCOORD_0: 2 }, indices: 3, mode: 4, material: 0 }] }],
      materials: [{
        name: (material && material.name) || "ArkherPBR",
        pbrMetallicRoughness: {
          baseColorFactor: (material && material.baseColorFactor) || [0.7, 0.55, 0.45, 1],
          metallicFactor: (material && material.metallic) ?? 0.05,
          roughnessFactor: (material && material.roughness) ?? 0.65,
        },
        doubleSided: false,
      }],
      bufferViews: [
        { buffer: 0, byteOffset: vPos.off, byteLength: vPos.len, target: 34962 },
        { buffer: 0, byteOffset: vNrm.off, byteLength: vNrm.len, target: 34962 },
        { buffer: 0, byteOffset: vUv.off, byteLength: vUv.len, target: 34962 },
        { buffer: 0, byteOffset: vIdx.off, byteLength: vIdx.len, target: 34963 },
      ],
      accessors: [
        { bufferView: 0, componentType: 5126, count: pos.length / 3, type: "VEC3", min: mins, max: maxs },
        { bufferView: 1, componentType: 5126, count: nrm.length / 3, type: "VEC3" },
        { bufferView: 2, componentType: 5126, count: uv.length / 2, type: "VEC2" },
        { bufferView: 3, componentType: use16 ? 5123 : 5125, count: idx.length, type: "SCALAR" },
      ],
      buffers: [{ byteLength: binLen }],
    };

    let json = JSON.stringify(gltf);
    while (json.length % 4) json += " ";
    const jsonB = strBytes(json);
    const total = 12 + 8 + jsonB.length + 8 + binLen;
    const out = new DataView(new ArrayBuffer(total));
    let o = 0;
    out.setUint32(o, 0x46546c67, true); o += 4;
    out.setUint32(o, 2, true); o += 4;
    out.setUint32(o, total, true); o += 4;
    out.setUint32(o, jsonB.length, true); o += 4;
    out.setUint32(o, 0x4e4f534a, true); o += 4;
    new Uint8Array(out.buffer).set(jsonB, o); o += jsonB.length;
    out.setUint32(o, binLen, true); o += 4;
    out.setUint32(o, 0x004e4942, true); o += 4;
    const bytes = new Uint8Array(out.buffer);
    for (const b of bin) { bytes.set(b, o); o += b.length; }
    return bytes;
  }

  // --------------------------------------------------- texturas (canvas)
  function makeNoise(size, seed, octaves) {
    const out = new Float32Array(size * size);
    let amp = 1, normSum = 0, gridN = 4;
    let s = seed;
    const rnd = () => (s = (s * 16807 + 13) % 2147483647) / 2147483647;
    for (let o = 0; o < octaves; o++) {
      const g = new Float32Array((gridN + 1) * (gridN + 1));
      for (let i = 0; i < g.length; i++) g[i] = rnd();
      const step = gridN / size;
      for (let y = 0; y < size; y++) {
        const fy = y * step, y0 = Math.floor(fy), ty = (fy - y0) * (fy - y0) * (3 - 2 * (fy - y0));
        for (let x = 0; x < size; x++) {
          const fx = x * step, x0 = Math.floor(fx), tx = (fx - x0) * (fx - x0) * (3 - 2 * (fx - x0));
          const x1 = (x0 + 1) % (gridN + 1), y1 = (y0 + 1) % (gridN + 1);
          const v00 = g[y0 * (gridN + 1) + x0], v10 = g[y0 * (gridN + 1) + x1];
          const v01 = g[y1 * (gridN + 1) + x0], v11 = g[y1 * (gridN + 1) + x1];
          const top = v00 + (v10 - v00) * tx, bot = v01 + (v11 - v01) * tx;
          out[y * size + x] += (top + (bot - top) * ty) * amp;
        }
      }
      normSum += amp; amp *= 0.5; gridN = Math.min(gridN * 2, size / 2);
    }
    for (let i = 0; i < out.length; i++) out[i] /= normSum;
    return out;
  }

  function generateTextures(material, size, seed) {
    const recipes = {
      stone: { base: [0.44, 0.43, 0.42], rough: 0.86, metal: 0, scale: 1.0 },
      brick: { base: [0.55, 0.27, 0.2], rough: 0.82, metal: 0, scale: 1.1 },
      metal: { base: [0.62, 0.63, 0.66], rough: 0.34, metal: 1, scale: 0.5 },
      wood: { base: [0.47, 0.31, 0.18], rough: 0.68, metal: 0, scale: 0.55 },
      grass: { base: [0.24, 0.42, 0.16], rough: 0.88, metal: 0, scale: 0.85 },
      dirt: { base: [0.34, 0.25, 0.17], rough: 0.95, metal: 0, scale: 1.0 },
      sand: { base: [0.82, 0.74, 0.58], rough: 0.9, metal: 0, scale: 0.35 },
      ice: { base: [0.72, 0.86, 0.95], rough: 0.08, metal: 0, scale: 0.5 },
      marble: { base: [0.9, 0.89, 0.87], rough: 0.18, metal: 0, scale: 0.2 },
      lava: { base: [0.16, 0.09, 0.08], rough: 0.75, metal: 0, scale: 0.9 },
      concrete: { base: [0.62, 0.62, 0.61], rough: 0.9, metal: 0, scale: 0.45 },
      leather: { base: [0.33, 0.2, 0.13], rough: 0.62, metal: 0, scale: 0.7 },
      generic: { base: [0.6, 0.6, 0.62], rough: 0.6, metal: 0.1, scale: 0.5 },
    };
    const rec = recipes[material] || recipes.generic;
    const h = makeNoise(size, seed || 7, 6);

    const canvases = {};
    function canvasFor(kind) {
      const c = document.createElement("canvas");
      c.width = c.height = size;
      const ctx = c.getContext("2d");
      const img = ctx.createImageData(size, size);
      return { c, ctx, img };
    }
    const albedo = canvasFor(), normal = canvasFor(), rough = canvasFor(), metal = canvasFor(), ao = canvasFor(), height = canvasFor();

    const lin2srgb = (v) => (v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055);
    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        const i = y * size + x;
        const hv = h[i];
        const shade = 0.78 + hv * 0.34;
        const j = i * 4;
        albedo.img.data[j] = lin2srgb(Math.min(1, rec.base[0] * shade)) * 255;
        albedo.img.data[j + 1] = lin2srgb(Math.min(1, rec.base[1] * shade)) * 255;
        albedo.img.data[j + 2] = lin2srgb(Math.min(1, rec.base[2] * shade)) * 255;
        albedo.img.data[j + 3] = 255;

        const xm = (x - 1 + size) % size, xp = (x + 1) % size;
        const ym = (y - 1 + size) % size, yp = (y + 1) % size;
        const dx = (h[y * size + xp] - h[y * size + xm]) * 2.5;
        const dy = (h[yp * size + x] - h[ym * size + x]) * 2.5;
        const nl = Math.hypot(dx, dy, 1);
        normal.img.data[j] = ((-dx / nl) * 0.5 + 0.5) * 255;
        normal.img.data[j + 1] = ((-dy / nl) * 0.5 + 0.5) * 255;
        normal.img.data[j + 2] = ((1 / nl) * 0.5 + 0.5) * 255;
        normal.img.data[j + 3] = 255;

        const rv = Math.max(0, Math.min(1, rec.rough + (0.5 - hv) * 0.3)) * 255;
        rough.img.data[j] = rough.img.data[j + 1] = rough.img.data[j + 2] = rv;
        rough.img.data[j + 3] = 255;
        const mv = rec.metal * 255;
        metal.img.data[j] = metal.img.data[j + 1] = metal.img.data[j + 2] = mv;
        metal.img.data[j + 3] = 255;
        const av = Math.max(0, Math.min(1, 1 - (1 - hv) * 0.5)) * 255;
        ao.img.data[j] = ao.img.data[j + 1] = ao.img.data[j + 2] = av;
        ao.img.data[j + 3] = 255;
        height.img.data[j] = height.img.data[j + 1] = height.img.data[j + 2] = hv * 255;
        height.img.data[j + 3] = 255;
      }
    }
    const out = {};
    for (const [k, v] of Object.entries({ albedo, normal, roughness: rough, metallic: metal, ao, height })) {
      v.ctx.putImageData(v.img, 0, 0);
      out[k] = v.c;
    }
    return out;
  }

  // ------------------------------------------------- projetos (offline)
  function godotProject(opts) {
    const name = opts.name || "Meu Jogo";
    const desc = opts.desc || "Jogo gerado pelo Arkher AI (modo offline)";
    const files = {};
    files["project.godot"] = `; Engine configuration file - Arkher AI (offline)
config_version=5

[application]

config/name="${name}"
config/description="${desc}"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")
config/icon="res://icon.svg"

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"

[input]

move_forward={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"control_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"control_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"control_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
move_back={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"control_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
jump={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"control_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}

[rendering]

renderer/rendering_method="forward_plus"
anti_aliasing/quality/msaa_3d=2
`;
    files["scripts/player.gd"] = `extends CharacterBody3D
## Player gerado pelo Arkher AI (modo offline)
@export var speed := 5.0
@export var jump_velocity := 4.8
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	if dir:
		velocity.x = move_toward(velocity.x, dir.x * speed, 40.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, 40.0 * delta)
		look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)
	move_and_slide()
`;
    files["scenes/main.tscn"] = `[gd_scene load_steps=4 format=3 uid="uid://arkheroffline1"]

[sub_resource type="CapsuleShape3D" id="col"]
radius = 0.35
height = 1.8

[sub_resource type="StandardMaterial3D" id="mat"]
albedo_color = Color(0.75, 0.5, 0.4, 1)
roughness = 0.6

[sub_resource type="CapsuleMesh" id="mesh"]
radius = 0.34
height = 1.75
material = SubResource("mat")

[node name="Main" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = null

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.766, -0.423, 0.485, 0, 0.755, 0.656, -0.643, -0.502, 0.578, 0, 24, 0)
light_energy = 1.1
shadow_enabled = true

[node name="Ground" type="StaticBody3D" parent="."]

[node name="GroundMesh" type="MeshInstance3D" parent="Ground"]
mesh = null

[node name="Player" type="CharacterBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.2, 4)
script = ExtResource("player_script")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Player"]
shape = SubResource("col")

[node name="Body" type="MeshInstance3D" parent="Player"]
mesh = SubResource("mesh")

[node name="Camera3D" type="Camera3D" parent="Player"]
transform = Transform3D(1, 0, 0, 0, 0.94, 0.34, 0, -0.34, 0.94, 0, 2.2, 6)
current = true
`;
    // corrige: main.tscn offline precisa do ext_resource do script
    files["scenes/main.tscn"] = files["scenes/main.tscn"].replace(
      '[gd_scene load_steps=4 format=3 uid="uid://arkheroffline1"]',
      '[gd_scene load_steps=5 format=3 uid="uid://arkheroffline1"]\n\n[ext_resource type="Script" path="res://scripts/player.gd" id="player_script"]'
    );
    files["icon.svg"] = `<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><rect width="128" height="128" rx="24" fill="#0b0e14"/><path d="M64 18 108 110 H84 L64 62 44 110 H20 Z" fill="url(#g)"/><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4fd8ff"/><stop offset="1" stop-color="#8b6cff"/></linearGradient></defs></svg>`;
    files["README.md"] = `# ${name}\n\nProjeto Godot 4 gerado pelo Arkher AI em **modo offline** (no aparelho).\n\n${desc}\n\nAbra com Godot 4.3+ → Import → project.godot → F5.\n\n> Conecte o app ao servidor do seu PC para o projeto COMPLETO\n> (inimigos, HUD, menu, save, shaders, lighting, GDD).\n`;
    files["docs/GDD.md"] = `# GDD — ${name}\n\n${desc}\n\n## Core loop\nExplorar → confronto → recompensa → upgrade.\n\n(GDD completo é gerado pelo servidor conectado.)\n`;
    return files;
  }

  function robloxProject(opts) {
    const name = opts.name || "Meu Jogo Roblox";
    const files = {};
    files["default.project.json"] = JSON.stringify({
      name,
      tree: {
        $className: "DataModel",
        ServerScriptService: { $className: "ServerScriptService", $path: "src/ServerScriptService" },
        ReplicatedStorage: { $className: "ReplicatedStorage", $path: "src/ReplicatedStorage" },
        StarterPlayer: {
          $className: "StarterPlayer",
          StarterPlayerScripts: { $className: "StarterPlayerScripts", $path: "src/StarterPlayerScripts" },
        },
      },
    }, null, 2);
    files["src/ServerScriptService/GameServer.server.lua"] = `-- Arkher AI (offline): servidor mínimo seguro
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = Instance.new("RemoteEvent")
remote.Name = "RequestDamage"
remote.Parent = ReplicatedStorage

local DAMAGE = 18
local RANGE = 3.4
local COOLDOWN = 0.55
local last = {}

remote.OnServerEvent:Connect(function(player, target)
	if typeof(target) ~= "Instance" then return end
	local victim = game.Players:GetPlayerFromCharacter(target) or target
	if typeof(victim) ~= "Instance" or not victim:IsA("Player") then return end
	local now = os.clock()
	if (last[player] or -9) + COOLDOWN > now then return end
	last[player] = now
	local a = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local b = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
	if not a or not b then return end
	if (a.Position - b.Position).Magnitude > RANGE then return end
	local hum = victim.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum:TakeDamage(DAMAGE) end
end)
`;
    files["src/ReplicatedStorage/Config.lua"] = `-- Balanceamento oficial (servidor)
return { DAMAGE = 18, RANGE = 3.4, COOLDOWN = 0.55 }\n`;
    files["src/StarterPlayerScripts/Client.client.lua"] = `-- Arkher AI (offline): cliente pede, servidor decide
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local remote = ReplicatedStorage:WaitForChild("RequestDamage")
local player = Players.LocalPlayer

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local target = player:GetMouse().Target
		if target then
			local model = target:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChildOfClass("Humanoid") then
				remote:FireServer(model)
			end
		end
	end
end)
`;
    files["README.md"] = `# ${name} (Roblox, modo offline)\n\nEstrutura Rojo mínima e SEGURA (dano decidido no servidor).\nConecte ao servidor do PC para o pacote completo (loja, DataStore, HUD, arena).\n\n\`\`\`bash\nrojo serve\n\`\`\`\n`;
    return files;
  }

  // ------------------------------------------------------------- chat offline
  function chatRespond(text) {
    const t = (text || "").toLowerCase();
    const go = (tab, label) => [{ label, tab }];
    if (/(roblox)/.test(t)) return { text: "Projeto Roblox offline: gero a estrutura Rojo mínima com combate server-authoritative. Conecte ao servidor do PC para o pacote completo (loja, DataStore, HUD, arena, lighting).", actions: go("roblox", "Gerar projeto Roblox") };
    if (/(godot|jogo|projeto)/.test(t)) return { text: "Projeto Godot offline: crio o skeleton jogável (player + cena + input). Conecte ao servidor para o projeto completo com inimigos, HUD, menu, save e shaders.", actions: go("godot", "Gerar projeto Godot") };
    if (/(textura|pbr|material)/.test(t)) return { text: "Texturas offline: gero no aparelho até 1k (albedo/normal/rough/metal/AO/height). Para 4k–16k e 19 materiais, conecte ao servidor.", actions: go("textures", "Gerar texturas") };
    if (/(modelo|3d|glb|mesh)/.test(t)) return { text: "Modelos offline: gero .glb com primitivas compostas (herói, árvore, pedra, espada, casa, terreno). Rig e LODs completos só no servidor.", actions: go("model", "Gerar modelo") };
    if (/(anima|rig)/.test(t)) return { text: "Animações com rig de 22 ossos e export R15 para Roblox rodam no servidor conectado. Offline eu gero o modelo base.", actions: go("animation", "Ver animações") };
    if (/(código|codigo|script|save|exploit)/.test(t)) return { text: "Tenho snippets essenciais offline (player, save, anti-exploit). A biblioteca completa com 16 padrões AAA fica no servidor.", actions: go("code", "Abrir código") };
    return { text: "Estou em MODO OFFLINE (geradores no aparelho). Posso criar projetos Godot/Roblox, modelos .glb e texturas até 1k aqui mesmo. Conecte ao servidor do PC (⚙ Servidor) para o arsenal completo: rig + animações, LODs, texturas 16k, projeto com HUD/menu/save e biblioteca de código.", actions: [ { label: "Projeto Godot", tab: "godot" }, { label: "Projeto Roblox", tab: "roblox" }, { label: "Modelo 3D", tab: "model" } ] };
  }

  const SNIPPETS_OFFLINE = [
    { id: "o1", title: "Player controller (Godot 4)", engine: "godot", lang: "gdscript", note: "Base com aceleração.", code: "extends CharacterBody3D\n@export var speed := 5.0\nvar gravity = ProjectSettings.get_setting(\"physics/3d/default_gravity\")\nfunc _physics_process(d):\n\tif not is_on_floor(): velocity.y -= gravity*d\n\tvar i = Input.get_vector(\"move_left\",\"move_right\",\"move_forward\",\"move_back\")\n\tvar dir = (transform.basis*Vector3(i.x,0,i.y)).normalized()\n\tvelocity.x = move_toward(velocity.x, dir.x*speed, 40*d)\n\tvelocity.z = move_toward(velocity.z, dir.z*speed, 40*d)\n\tmove_and_slide()\n" },
    { id: "o2", title: "Save/Load JSON (Godot)", engine: "godot", lang: "gdscript", note: "Com versão para migração.", code: "func save():\n\tvar f = FileAccess.open(\"user://save.json\", FileAccess.WRITE)\n\tf.store_string(JSON.stringify({\"version\":1,\"hp\":health}))\nfunc load_game():\n\tif not FileAccess.file_exists(\"user://save.json\"): return\n\tvar d = JSON.parse_string(FileAccess.open(\"user://save.json\", FileAccess.READ).get_as_text())\n\tif d: health = d.get(\"hp\", 100)\n" },
    { id: "o3", title: "Anti-exploit de dano (Roblox)", engine: "roblox", lang: "lua", note: "Servidor decide tudo.", code: "remote.OnServerEvent:Connect(function(player, target)\n\tlocal now = os.clock()\n\tif (last[player] or -9) + 0.55 > now then return end\n\tlast[player] = now\n\tif (a.Position - b.Position).Magnitude > 3.4 then return end\n\thum:TakeDamage(18)  -- valor do servidor, nunca do cliente\nend)\n" },
    { id: "o4", title: "DataStore com retries (Roblox)", engine: "roblox", lang: "lua", note: "Backoff exponencial.", code: "for attempt = 1, 4 do\n\tlocal ok, data = pcall(store.GetAsync, store, key)\n\tif ok then return data end\n\ttask.wait(2 ^ attempt * 0.5)\nend\n" },
  ];

  window.ArkherOffline = {
    makeZip,
    buildGlb,
    generateTextures,
    godotProject,
    robloxProject,
    chatRespond,
    snippets: SNIPPETS_OFFLINE,
    models: Object.keys(MODELS),
    buildModel(type, detail) {
      const m = meshBuilder();
      (MODELS[type] || MODELS.prop)(m, detail || 2);
      return m;
    },
  };
})();
