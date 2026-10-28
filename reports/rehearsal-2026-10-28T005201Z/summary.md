# Rehearsal 2026-10-28T005201Z

Automated with `scripts/demo.sh rehearse` on the OOB server. Total time 2 min 6 s.

| Step | What happened | Doctor verdict | Expected | Result | Report |
|---|---|---|---|---|---|
| 1 | Healthy fabric | HEALTHY | HEALTHY | PASS | [1-healthy.md](1-healthy.md) |
| 2 | `nv set interface swp1-5 link state down` on Spine2 | PROBLEMS FOUND | PROBLEMS FOUND | PASS | [2-spine2-down.md](2-spine2-down.md) |
| 3 | Links restored, verify.yml passed | HEALTHY | HEALTHY | PASS | [3-restored.md](3-restored.md) |

Preflight and restore checks that failed: 0
