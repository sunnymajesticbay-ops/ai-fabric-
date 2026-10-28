#!/bin/bash
# demo.sh: one short command for each interview-prep job. Run from anywhere on the OOB server.
#
#   scripts/demo.sh check            health check: management, BGP/BFD, server paths, fabric doctor, Git, API key
#   scripts/demo.sh rehearse         full rehearsal: healthy -> Spine2 down -> restored, a report at each step,
#                                    a pass/fail summary, then commit and push everything to GitHub
#   scripts/demo.sh break [Switch]   take a switch's fabric links down (default Spine2)
#   scripts/demo.sh restore [Switch] bring them back and wait until BGP and BFD are up again
#   scripts/demo.sh sync ["message"] commit and push to GitHub (refuses if an API key would be committed)
#   scripts/demo.sh savekey          keep the Anthropic API key across logouts (~/.anthropic_key, not in the repo)
#
# Options (environment): DEMO_NO_PUSH=1 skips the push at the end of a rehearsal.

cd "$(dirname "$0")/.." || exit 1
ROOT=$PWD
INV=()                                   # for testing against another inventory: DEMO_INVENTORY=path
[ -n "$DEMO_INVENTORY" ] && INV=(-i "$DEMO_INVENTORY")
LOGDIR=state/demo-logs; mkdir -p "$LOGDIR"
KEY_RE='sk-ant-[a-z0-9]+-[A-Za-z0-9_-]{30,}'
FAILS=0

if [ -t 1 ]; then G=$'\e[32m'; R=$'\e[1;31m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'; else G= R= Y= B= N=; fi
step() { printf '\n%s== %s%s\n' "$B" "$*" "$N"; }
pass() { printf '  %sPASS%s  %s\n' "$G" "$N" "$*"; }
fail() { printf '  %sFAIL%s  %s\n' "$R" "$N" "$*"; FAILS=$((FAILS+1)); }
note() { printf '  %s%s%s\n' "$Y" "$*" "$N"; }
stamp() { date -u +%Y-%m-%dT%H%M%SZ; }

load_key() {
  if [ -z "$ANTHROPIC_API_KEY" ] && [ -r ~/.anthropic_key ]; then
    ANTHROPIC_API_KEY=$(cat ~/.anthropic_key); export ANTHROPIC_API_KEY
  fi
}

# ------------------------------------------------------------------------------------------------
preflight() {
  step "Management network"
  if [ -n "$DEMO_SKIP_FLUSH" ]; then note "neighbor flush skipped"
  elif sudo -n ip neigh flush all 2>/dev/null || sudo ip neigh flush all; then pass "cleared stale ARP entries (fixes 'No route to host' after the simulation sleeps)"
  else note "could not run 'sudo ip neigh flush all'"; fi
  local want got
  want=$(ansible-inventory "${INV[@]}" --graph switches 2>/dev/null | grep -c -- '--[A-Za-z]')
  got=$(ansible switches "${INV[@]}" -m ping -o 2>/dev/null | grep -c 'SUCCESS')
  [ "$got" -eq "$want" ] && [ "$want" -gt 0 ] && pass "$got of $want switches answer Ansible" \
    || fail "$got of $want switches answer Ansible (run: ansible switches -m ping)"

  step "BGP and BFD"
  if ansible-playbook "${INV[@]}" playbooks/verify.yml > "$LOGDIR/verify.log" 2>&1; then pass "verify.yml passed"
  else fail "verify.yml failed (log: $LOGDIR/verify.log)"; fi
  grep -o '"msg": "[^"]*sessions[^"]*"' "$LOGDIR/verify.log" | sed 's/"msg": "/        /; s/"$//'

  if [ -z "$DEMO_SKIP_SERVERS" ]; then
    step "Server paths"
    if ansible-playbook "${INV[@]}" playbooks/verify-servers.yml > "$LOGDIR/verify-servers.log" 2>&1; then pass "verify-servers.yml passed"
    else fail "verify-servers.yml failed (log: $LOGDIR/verify-servers.log)"; fi
    grep -o '"msg": "[^"]*of 10[^"]*"' "$LOGDIR/verify-servers.log" | sed 's/"msg": "/        /; s/"$//'
  fi
}

check_key() {
  step "Anthropic API key"
  load_key
  if [ -z "$ANTHROPIC_API_KEY" ]; then
    fail "ANTHROPIC_API_KEY is not set: export it, then run: scripts/demo.sh savekey"; return
  fi
  local code
  code=$(curl -s -o "$LOGDIR/api-test.json" -w '%{http_code}' "${ANTHROPIC_BASE_URL:-https://api.anthropic.com}/v1/messages" \
    -H "authorization: Bearer $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
    ${ANTHROPIC_WORKSPACE_ID:+-H "anthropic-workspace-id: $ANTHROPIC_WORKSPACE_ID"} \
    -d "{\"model\":\"${FABRIC_DOCTOR_MODEL:-claude-sonnet-5-5}\",\"max_tokens\":10,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}")
  if [ "$code" = 200 ]; then pass "key works (${#ANTHROPIC_API_KEY} characters, test call returned HTTP 200)"
  else fail "test call returned HTTP $code: $(grep -o '"message":"[^"]*"' "$LOGDIR/api-test.json" | head -1)"; fi
  [ -r ~/.anthropic_key ] || note "the key is only in this session: run scripts/demo.sh savekey"
}

check_git() {
  step "GitHub"
  if ! git fetch -q 2>"$LOGDIR/git.log"; then fail "cannot reach GitHub (log: $LOGDIR/git.log)"; return; fi
  local ahead behind dirty
  read -r behind ahead < <(git rev-list --left-right --count '@{u}...HEAD' 2>/dev/null || echo "? ?")
  dirty=$(git status --porcelain | wc -l)
  if [ "$ahead" = 0 ] && [ "$behind" = 0 ] && [ "$dirty" = 0 ]; then pass "in sync with GitHub ($(git log -1 --format='%h %s'))"
  else note "not in sync: $ahead commit(s) to push, $behind to pull, $dirty changed file(s). Run: scripts/demo.sh sync"; fi
}

# runs the doctor, moves its report to $1, prints and returns its exit code (0 healthy, 1 warnings, 2 critical)
doctor() {
  local dest=$1 before after rc
  before=$(ls -t reports/fabric-doctor-*.md 2>/dev/null | head -1)
  python3 scripts/fabric_doctor.py ${DEMO_INVENTORY:+-i "$DEMO_INVENTORY"} $([ -z "$ANTHROPIC_API_KEY" ] && echo --no-llm) \
    > "$LOGDIR/doctor.log" 2>&1
  rc=$?
  after=$(ls -t reports/fabric-doctor-*.md 2>/dev/null | head -1)
  if [ -n "$dest" ] && [ -n "$after" ] && [ "$after" != "$before" ]; then mkdir -p "$(dirname "$dest")"; mv "$after" "$dest"; fi
  grep -m1 '^Checked' "$LOGDIR/doctor.log" | sed 's/^/        /'
  grep -m1 '^\*\*Verdict' "$LOGDIR/doctor.log" | sed 's/^/        AI: /'
  return $rc
}

# ------------------------------------------------------------------------------------------------
links() {   # links down|up Switch
  ansible "$2" "${INV[@]}" -m shell \
    -a "nv set interface {{ fabric_ports | join(',') }} link state $1 && nv config apply -y" > "$LOGDIR/links-$1.log" 2>&1
}

do_break() {
  local sw=${1:-Spine2}
  step "Taking $sw's fabric links down"
  if links down "$sw"; then pass "$sw: fabric ports shut (nv set interface ... link state down)"
  else fail "could not shut $sw's links (log: $LOGDIR/links-down.log)"; return 1; fi
}

do_restore() {
  local sw=${1:-Spine2}
  step "Restoring $sw's fabric links"
  if links up "$sw"; then pass "$sw: fabric ports enabled"
  else fail "could not enable $sw's links (log: $LOGDIR/links-up.log)"; return 1; fi
  note "waiting for BGP and BFD to re-establish ..."
  if ansible-playbook "${INV[@]}" playbooks/verify.yml > "$LOGDIR/verify.log" 2>&1; then pass "all BGP and BFD sessions are back up"
  else fail "verify.yml still failing (log: $LOGDIR/verify.log)"; return 1; fi
}

do_sync() {
  local msg=${1:-"Update from the OOB server $(stamp)"}
  step "Sync with GitHub"
  for line in 'state/' '__pycache__/'; do grep -qxF "$line" .gitignore 2>/dev/null || echo "$line" >> .gitignore; done
  git add -A
  if git grep --cached -qIE "$KEY_RE"; then
    fail "an API key was found in these files, so nothing was committed:"
    git grep --cached -lIE "$KEY_RE" | sed 's/^/        /'
    git reset -q
    return 1
  fi
  if git diff --cached --quiet; then pass "nothing new to commit"
  else git commit -q -m "$msg" && pass "committed: $msg"; fi
  if ! git pull -q --rebase 2>"$LOGDIR/git.log"; then fail "git pull failed (log: $LOGDIR/git.log)"; return 1; fi
  if git push -q 2>>"$LOGDIR/git.log"; then pass "pushed: GitHub now matches this server ($(git log -1 --format=%h))"
  else fail "git push failed (log: $LOGDIR/git.log)"; return 1; fi
}

do_savekey() {
  load_key
  if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "First set the key in this session (start the line with a space so it stays out of history):"
    echo "   export ANTHROPIC_API_KEY=<your key>"
    return 1
  fi
  ( umask 077; printf '%s' "$ANTHROPIC_API_KEY" > ~/.anthropic_key )
  grep -qF 'anthropic_key' ~/.bashrc 2>/dev/null || \
    echo '[ -r ~/.anthropic_key ] && export ANTHROPIC_API_KEY=$(cat ~/.anthropic_key)' >> ~/.bashrc
  pass "saved to ~/.anthropic_key (${#ANTHROPIC_API_KEY} characters, readable only by you); loaded at every login"
}

# ------------------------------------------------------------------------------------------------
rehearse() {
  local ts dir sw=Spine2 rc1 rc2 rc3 t0
  ts=$(stamp); dir=reports/rehearsal-$ts; t0=$SECONDS
  load_key
  printf '%sRehearsal %s%s: healthy -> %s down -> restored. Reports go to %s/\n' "$B" "$ts" "$N" "$sw" "$dir"
  preflight
  check_key

  step "1/3 Fabric doctor on the healthy fabric"
  doctor "$dir/1-healthy.md"; rc1=$?

  do_break "$sw" || { do_restore "$sw"; return 1; }
  trap 'echo; note "interrupted: restoring '"$sw"' first"; do_restore '"$sw"'; exit 130' INT TERM
  note "waiting 20 s for BFD and BGP to react ..."
  sleep 20
  step "2/3 Fabric doctor with $sw down"
  doctor "$dir/2-$(echo "$sw" | tr 'A-Z' 'a-z')-down.md"; rc2=$?

  do_restore "$sw"
  trap - INT TERM
  step "3/3 Fabric doctor after the restore"
  doctor "$dir/3-restored.md"; rc3=$?

  verdict() { case $1 in 0) echo HEALTHY;; 1) echo WARNINGS;; 2) echo "PROBLEMS FOUND";; *) echo "ERROR ($1)";; esac; }
  ok() { [ "$1" = "$2" ] && echo PASS || echo FAIL; }
  {
    echo "# Rehearsal $ts"
    echo
    echo "Automated with \`scripts/demo.sh rehearse\` on the OOB server. Total time $(( (SECONDS - t0) / 60 )) min $(( (SECONDS - t0) % 60 )) s."
    echo
    echo "| Step | What happened | Doctor verdict | Expected | Result | Report |"
    echo "|---|---|---|---|---|---|"
    echo "| 1 | Healthy fabric | $(verdict $rc1) | HEALTHY | $(ok $rc1 0) | [1-healthy.md](1-healthy.md) |"
    echo "| 2 | \`nv set interface swp1-5 link state down\` on $sw | $(verdict $rc2) | PROBLEMS FOUND | $(ok $rc2 2) | [2-$(echo "$sw" | tr 'A-Z' 'a-z')-down.md](2-$(echo "$sw" | tr 'A-Z' 'a-z')-down.md) |"
    echo "| 3 | Links restored, verify.yml passed | $(verdict $rc3) | HEALTHY | $(ok $rc3 0) | [3-restored.md](3-restored.md) |"
    echo
    echo "Preflight and restore checks that failed: $FAILS"
  } > "$dir/summary.md"
  step "Summary"
  sed -n '/^| 1/,/^| 3/p' "$dir/summary.md" | sed 's/^/  /'
  [ "$rc1$rc2$rc3" = 020 ] && pass "rehearsal behaved exactly as expected" || fail "see $dir/summary.md"

  if [ -z "$DEMO_NO_PUSH" ]; then do_sync "Rehearsal $ts: healthy, $sw down, restored"; fi
}

# ------------------------------------------------------------------------------------------------
case "${1:-}" in
  check)    load_key; preflight; check_key
            step "Fabric doctor"; doctor ""; rc=$?
            [ $rc = 0 ] && pass "fabric is healthy" || fail "doctor exit code $rc (report in reports/)"
            check_git ;;
  rehearse) rehearse ;;
  break)    do_break "$2" ;;
  restore)  do_restore "$2" ;;
  sync)     do_sync "$2" ;;
  savekey)  do_savekey ;;
  *)        sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
echo
[ "$FAILS" = 0 ] && printf '%sAll checks passed.%s\n' "$G" "$N" || printf '%s%s check(s) failed.%s\n' "$R" "$FAILS" "$N"
exit $(( FAILS > 0 ))
