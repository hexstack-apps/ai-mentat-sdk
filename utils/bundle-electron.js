#!/usr/bin/env bun
/**
 * Bundle Electron main process with esbuild.
 * Resolves ESM-only dependencies at build time.
 * Also copies shared vendor files (update bar) into the app directory.
 *
 * Usage: node shared/bundle-electron.js [project-dir]   (defaults to repo root)
 */
const path = require('path');
const fs = require('fs');
const { buildSync } = require('esbuild');

const projectDir = process.argv[2] || path.resolve(__dirname, '..');

const entry = path.join(projectDir, 'electron-main.js');
const out = path.join(projectDir, 'electron-main.bundle.js');

// Copy shared vendor files into the app directory
const sharedDir = path.join(__dirname);
const vendorFiles = ['update-ui.js'];
for (const file of vendorFiles) {
  const src = path.join(sharedDir, file);
  const dst = path.join(projectDir, file);
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, dst);
    console.log(`Copied ${file} -> ${projectDir}/`);
  }
}

// Packages that must not be inlined. Beyond electron itself, this covers
// optional native/ESM dependencies: node-llama-cpp and friends ship
// platform-specific binary bindings behind dynamic imports and use top-level
// await, neither of which survives a CJS bundle. They are resolved from
// node_modules at runtime instead, and every call site already guards with
// require.resolve so the app degrades cleanly when they are absent.
//
// Each app declares its own list via "bundleExternal" in package.json.
const alwaysExternal = ['electron', 'electron-updater'];
let declaredExternal = [];
try {
  const pkg = JSON.parse(fs.readFileSync(path.join(projectDir, 'package.json'), 'utf8'));
  declaredExternal = pkg.bundleExternal || [];
  // Optional dependencies are external by definition: they may not be installed.
  declaredExternal = declaredExternal.concat(Object.keys(pkg.optionalDependencies || {}));
} catch {}

const external = [...new Set([...alwaysExternal, ...declaredExternal])];
if (external.length > alwaysExternal.length) {
  console.log(`External (resolved at runtime): ${external.slice(alwaysExternal.length).join(', ')}`);
}

const result = buildSync({
  entryPoints: [entry],
  bundle: true,
  platform: 'node',
  format: 'cjs',
  outfile: out,
  external,
  sourcemap: false,
  minify: false,
  logLevel: 'info',
});

if (result.errors.length) {
  console.error('Bundle failed');
  process.exit(1);
}
