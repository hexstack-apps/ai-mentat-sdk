# ai-mentat-sdk

Shared logic, UI and utilities for the **ai-mentat** family of Electron apps.

Consumed as a **git submodule** (mounted at `sdk/`) by:

- [ai-mentat-coolify-local](https://github.com/hexstack-apps/ai-mentat-coolify-local)
- [ai-mentat-interviews](https://github.com/hexstack-apps/ai-mentat-interviews)
- [ai-mentat-local-studio](https://github.com/hexstack-apps/ai-mentat-local-studio)
- [ai-mentat-roblox-studio](https://github.com/hexstack-apps/ai-mentat-roblox-studio)

## Structure

```
logic/   app behaviour and release orchestration
  auto-update.js       electron-updater wiring (generic provider)
  publish.js           version bump → bundle → build → update feed → itch.io
  release.js           upload dist/ to GitHub (gh) and itch.io (butler)
ui/
  update-bar.js        "Restart to update" notification bar (plain <script>)
utils/
  data-dir.js          resolves <root>/.hexstack-app/<app-name>/data
  bundle-electron.js   esbuild bundling of the Electron main process
  pty-helper.py        real PTY bridge, no native Node modules
```

Every file here was **extracted verbatim** from code that already existed
identically in 2–3 of the consuming repos — nothing was invented for the sake of
having an SDK. `utils/data-dir.js` is the sole new module: it defines the shared
data-directory contract that all four apps moved to.

There is deliberately **no shared design system**: only one app defined CSS
custom properties, so a common stylesheet would have been an abstraction with a
single user.

## The data directory contract

```js
const { resolveDataDir, dataDir, ensureDataDir } = require('./sdk/utils/data-dir');

resolveDataDir('ai-mentat-interviews');
// POSIX  -> /.hexstack-app/ai-mentat-interviews/data
// Windows-> C:\.hexstack-app\ai-mentat-interviews\data
```

The filesystem root is not writable by an unprivileged user on most systems, so:

- `dataDir(app)` is pure — it computes the path and touches nothing.
- `ensureDataDir(app)` creates it and **returns** `{ok:false, error, fallback}`
  instead of throwing, so startup can report a real message.
- `resolveDataDir(app)` returns the root path when writable and otherwise falls
  back to `~/.hexstack-app/<app>/data`, always returning a usable directory.

Run `npm run setup` in a consuming repo (or `sudo mkdir -p /.hexstack-app &&
sudo chown $(whoami) /.hexstack-app`) to make the root location writable.

## Tests

```sh
npm test        # node --test utils/*.test.js
```

`utils/data-dir.test.js` covers the path contract, the POSIX literal, the
path-traversal guard and the read-only-root fallback. The suite is
mutation-checked: pointing the root at `homedir()` fails 2 tests and removing
the traversal guard fails 1.

## License

MIT
