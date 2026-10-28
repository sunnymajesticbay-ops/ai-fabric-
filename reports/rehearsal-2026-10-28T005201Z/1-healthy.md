# Fabric doctor report, 2026-10-28T005219Z

**Checker verdict:** HEALTHY (0 critical, 0 warnings). Switches read: 9 of 9.

## AI diagnosis (claude-sonnet-5-5)

**Verdict:** Healthy. All 9 switches are reachable, with every link, BGP session and BFD session up and no routes missing.

### What's wrong
Nothing in the snapshot indicates a fault. The checker also reports `HEALTHY` with no findings, and the data agrees.

One item is worth noting, but it is not a fault:

1. **Leaf5 swp1 (to Spine1 swp5) shows `drops: 1`.**
   - Evidence: Leaf5 swp1 has `errors: 0, drops: 1`. The counters are cumulative since boot (`uptime_min: 326`), so a single drop over about 5.4 hours is not meaningful.
   - Other signals on that link are clean: BGP `established` and BFD `up` on both ends, and Spine1 swp5 shows `errors: 0, drops: 0`.
   - Impact: none visible. Rail 5 still has all 4 spine paths (`ecmp_lost_paths` is empty).
   - The snapshot cannot say when the drop happened or what caused it. It is a single sample with no rate. Only a later snapshot showing the counter increasing would make it a concern.

### What looks healthy
- Fabric ports are 5/5 on every spine and 4/4 on every leaf, and all 20 leaf-spine BGP sessions and their BFD sessions are up. No leaf has lost an ECMP path, and `routes_missing` is 0 everywhere.
- Server ports are 4/4 on all five leaves, and `frr` and `nvued` are active on every switch.
- Cumulus VX has no hardware QoS, so the RoCE lossless settings cannot be verified from this data.

_7263 tokens in, 560 out. The AI summary is generated from the evidence below; check it against the findings._

## Findings

No problems found.

## Switches

| Switch | Read | Fabric ports up | Server ports up | BGP | BFD | Routes missing | Uptime (min) | Load |
|---|---|---|---|---|---|---|---|---|
| Spine1 | yes | 5/5 | - | 5/5 | 5/5 | 0 | 326 | 0.08 |
| Spine2 | yes | 5/5 | - | 5/5 | 5/5 | 0 | 326 | 0.12 |
| Spine3 | yes | 5/5 | - | 5/5 | 5/5 | 0 | 326 | 0.03 |
| Spine4 | yes | 5/5 | - | 5/5 | 5/5 | 0 | 326 | 0.11 |
| Leaf1 | yes | 4/4 | 4/4 | 4/4 | 4/4 | 0 | 326 | 0.08 |
| Leaf2 | yes | 4/4 | 4/4 | 4/4 | 4/4 | 0 | 326 | 0.07 |
| Leaf3 | yes | 4/4 | 4/4 | 4/4 | 4/4 | 0 | 326 | 0.07 |
| Leaf4 | yes | 4/4 | 4/4 | 4/4 | 4/4 | 0 | 326 | 0.09 |
| Leaf5 | yes | 4/4 | 4/4 | 4/4 | 4/4 | 0 | 326 | 0.07 |

Raw outputs: `state/2026-10-28T005219Z/`
