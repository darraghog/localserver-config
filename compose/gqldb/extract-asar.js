// Extract an Electron asar archive without needing Electron or the network.
//
// Why not `npx @electron/asar extract`: that tool also copies entries flagged "unpacked",
// reading them from the sibling app.asar.unpacked/ tree - and this .deb does not ship all of
// them. electron-builder pruned the non-Linux platform binaries (koffi's win32_arm64
// koffi.exp/.lib) from disk while leaving them listed in the archive index, so the official
// extractor aborts with ENOENT on files Electron itself would never open on Linux.
//
// This skips unpacked entries by design: the Dockerfile lays app.asar.unpacked/ over the
// output afterwards, which is exactly how Electron resolves them at runtime. Whatever the
// package actually ships wins; what it omits was never loadable on this platform anyway.
//
// Header layout (verified against the archive): uint32 LE at 4 = header pickle size;
// uint32 LE at 12 = JSON length; JSON starts at 16; file data begins at 8 + headerSize,
// which accounts for the pickle's 4-byte alignment padding.
const fs = require('fs');
const path = require('path');

const [, , asarPath, outDir] = process.argv;
if (!asarPath || !outDir) {
  console.error('usage: extract-asar.js <app.asar> <outdir>');
  process.exit(2);
}

const fd = fs.openSync(asarPath, 'r');
const head = Buffer.alloc(16);
fs.readSync(fd, head, 0, 16, 0);
const headerSize = head.readUInt32LE(4);
const jsonLen = head.readUInt32LE(12);
const jbuf = Buffer.alloc(jsonLen);
fs.readSync(fd, jbuf, 0, jsonLen, 16);
const index = JSON.parse(jbuf.toString('utf8'));
const base = 8 + headerSize;

let written = 0, skipped = 0, bytes = 0;

function walk(node, rel) {
  for (const [name, meta] of Object.entries(node.files || {})) {
    const rp = path.join(rel, name);
    const abs = path.join(outDir, rp);
    if (meta.files) {
      fs.mkdirSync(abs, { recursive: true });
      walk(meta, rp);
    } else if (meta.unpacked) {
      skipped++;
    } else {
      const size = Number(meta.size || 0);
      const offset = Number(meta.offset || 0);
      fs.mkdirSync(path.dirname(abs), { recursive: true });
      const buf = Buffer.alloc(size);
      if (size > 0) {
        const got = fs.readSync(fd, buf, 0, size, base + offset);
        if (got !== size) throw new Error(`short read for ${rp}: ${got} of ${size}`);
      }
      fs.writeFileSync(abs, buf);
      if (meta.executable) fs.chmodSync(abs, 0o755);
      written++; bytes += size;
    }
  }
}

fs.mkdirSync(outDir, { recursive: true });
walk(index, '');
fs.closeSync(fd);
console.error(`extract-asar: ${written} files (${bytes} bytes), ${skipped} unpacked entries left to the overlay`);
