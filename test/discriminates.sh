#!/bin/sh
# Mutation check: reintroduce each bug and assert the suite goes RED.
# A green suite proves nothing until a broken build fails it.
cd "$(dirname "$0")/.." || exit 1
PASS=0; FAIL=0

mutate() {
  desc=$1; file=$2; from=$3; to=$4
  cp "$file" "$file.bak"
  python3 - "$file" "$from" "$to" <<'PY'
import sys
p,f,t=sys.argv[1],sys.argv[2],sys.argv[3]
s=open(p).read()
if f not in s:
    print("MUTATION-NOOP"); sys.exit(9)
open(p,'w').write(s.replace(f,t,1))
PY
  if [ $? -eq 9 ]; then
    echo "  SKIP (pattern absent — mutation is a no-op): $desc"
    mv "$file.bak" "$file"; FAIL=$((FAIL+1)); return
  fi
  if node --test 'utils/*.test.js' 'logic/*.test.js' 'ui/*.test.js' >/dev/null 2>&1; then
    echo "  NOT CAUGHT: $desc"; FAIL=$((FAIL+1))
  else
    echo "  caught:     $desc"; PASS=$((PASS+1))
  fi
  mv "$file.bak" "$file"
}

echo "Mutation testing (each must be CAUGHT):"

# ── utils/failsafe.js ─────────────────────────────────────────────────────

mutate "failsafe stops recording failures" utils/failsafe.js \
  "  recent.push({ at: Date.now(), op, message, context });" \
  "  ;"

mutate "failsafe buffer becomes unbounded" utils/failsafe.js \
  "  if (recent.length > MAX_RECENT) recent.splice(0, recent.length - MAX_RECENT);" \
  "  ;"

mutate "recentFailures exposes the live buffer" utils/failsafe.js \
  "  return recent.slice();" \
  "  return recent;"

# ── utils/env.js ──────────────────────────────────────────────────────────

mutate "PATH appended instead of prepended (system copies win)" utils/env.js \
  "  return base ? extra.join(sep) + sep + base : extra.join(sep);" \
  "  return base ? base + sep + extra.join(sep) : extra.join(sep);"

mutate "empty-PATH guard dropped (trailing separator = cwd on PATH)" utils/env.js \
  "  const base = envPath || (isWin ? '' : '/usr/bin:/bin');" \
  "  const base = envPath;"

mutate "extra can no longer override the base environment" utils/env.js \
  "    ...baseEnv,
    ...extra," \
  "    ...extra,
    ...baseEnv,"

mutate "tryRun rethrows instead of returning null" utils/env.js \
  "  return quiet(op, () => run(bin, args, opts), null);" \
  "  return run(bin, args, opts);"


# ── utils/proc.js ─────────────────────────────────────────────────────────

mutate "kill targets the pid instead of the process group" utils/proc.js \
  "      kill(-proc.pid, 'SIGTERM');" \
  "      kill(proc.pid, 'SIGTERM');"

mutate "no SIGKILL follow-up (a hung child survives shutdown)" utils/proc.js \
  "        if (platform !== 'win32') kill(-proc.pid, 'SIGKILL');" \
  "        ;"

mutate "taskkill loses /T (Windows grandchildren survive)" utils/proc.js \
  "      if (runFn) runFn('taskkill', ['/pid', String(proc.pid), '/T', '/F'], { stdio: 'ignore' });" \
  "      if (runFn) runFn('taskkill', ['/pid', String(proc.pid), '/F'], { stdio: 'ignore' });"

mutate "cleanup runs more than once (double-kills every child)" utils/proc.js \
  "    if (done) return undefined;
    done = true;" \
  "    ;"


# ── logic/settings.js ─────────────────────────────────────────────────────

mutate "a missing settings file is recorded as a failure (floods the buffer)" logic/settings.js \
  "    if (!fs.existsSync(filePath)) return {};" \
  "    ;"

mutate "save replaces the document instead of merging a patch" logic/settings.js \
  "    const merged = { ...load(), ...patch };" \
  "    const merged = { ...patch };"

mutate "a failed write is silent" logic/settings.js \
  "    attempt('settings.write', () => {" \
  "    (() => {"

mutate "settings:set accepts a non-object patch" logic/settings.js \
  "    if (!patch || typeof patch !== 'object' || Array.isArray(patch)) {" \
  "    if (false) {"


echo
echo "caught $PASS / $((PASS+FAIL))"
[ "$FAIL" -eq 0 ] || exit 1
