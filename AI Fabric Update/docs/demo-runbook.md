# Demo runbook

How to get the fabric ready and run the live demo. Every command runs on the
OOB server from `~/ai-fabric`. Type or paste one line at a time.

## The day before

1. Wake the simulation in DSX Air and log in to `oob-mgmt-server`.
2. `git pull` to get the latest code.
3. `scripts/demo.sh check` checks the management network, BGP and BFD, the 40
   server paths, the Anthropic API key, the fabric doctor and the GitHub sync.
   Every line should say PASS.
4. `scripts/demo.sh rehearse` runs the whole demo unattended (3-4 minutes):
   healthy fabric, Spine2 down, Spine2 restored. A doctor report is saved at
   each step in `reports/rehearsal-<time>/`, and the summary must show PASS
   three times. It then commits and pushes everything to GitHub.
5. In DSX Air, export the topology JSON and upload it to `topology/` on GitHub.
   With the playbooks, that is everything needed to rebuild the lab.
6. Download the repo as a ZIP from GitHub (Code > Download ZIP) and keep it
   with the offline pack (deck, videos, spreadsheet, Word record).

## 20 minutes before

1. Wake the simulation. Trial simulations sleep when idle.
2. `scripts/demo.sh check`

## The live demo (about 5 minutes)

| Step | Type | What to say |
|---|---|---|
| 1 | `cat inventory/hosts` and open `templates/underlay.j2` | "The whole fabric is code: inventory, templates and playbooks in Git." |
| 2 | `scripts/demo.sh check` | "One command checks the management network, 20 BGP sessions with BFD, 40 server paths and the AI pipeline." |
| 3 | `python3 scripts/fabric_doctor.py` | "It snapshots every switch, checks it against the design in the inventory, then Claude explains the result." |
| 4 | `scripts/demo.sh break` | "Now I take Spine2's five fabric links down, like a failed spine." |
| 5 | `python3 scripts/fabric_doctor.py` | "The checker correlates all five leaves and names Spine2 as the root cause. Claude explains the impact: each leaf lost a quarter of its paths, but traffic still flows over three spines." |
| 6 | `scripts/demo.sh restore` | "Restore and wait until BGP and BFD are back. BFD detects failures in under a second instead of the 9 s BGP hold timer." |
| 7 | Open the latest `reports/rehearsal-*/summary.md` on GitHub | "The same test runs unattended and pushes its evidence to Git." |

If Spine2 is still down at the end for any reason: `scripts/demo.sh restore`.

## If something goes wrong

| Symptom | Fix |
|---|---|
| `No route to host` or switches missing from `ansible switches -m ping` | `sudo ip neigh flush all`, then try again (the check does this for you) |
| `ANTHROPIC_API_KEY is not set` | ` export ANTHROPIC_API_KEY=<key>` (leading space keeps it out of history), then `scripts/demo.sh savekey` |
| Claude API returns HTTP 400 about `anthropic-workspace-id` | `export ANTHROPIC_WORKSPACE_ID=wrkspc_...` (Console > Settings > Workspaces) |
| Claude API is down or slow | `python3 scripts/fabric_doctor.py --no-llm` still shows every finding |
| Pasted commands come out scrambled | The DSX Air console mixes multi-line pastes: paste one line at a time |
| Prompt is just `$` | You are in `sh`: type `exit` |
| The simulation will not wake or the network is down | Use the offline pack and the reports on GitHub |
