# Fabric doctor report, 2026-10-28T005347Z

**Checker verdict:** HEALTHY (0 critical, 0 warnings). Switches read: 9 of 9.

## AI diagnosis (claude-sonnet-5-5)

**Verdict:** Healthy. All 9 switches are reachable, with every fabric link, BGP session and BFD session up and no routes missing.

### What's wrong
Nothing in the snapshot indicates a fault, and the checker's `HEALTHY` verdict with an empty findings list agrees with it.

- Spine1 to Spine4: `fabric_ports_up` 5/5, `bgp_established` 5/5, `bfd_up` 5/5.
- Leaf1 to Leaf5: fabric ports 4/4, server ports 4/4, BGP 4/4, BFD 4/4.
- `routes_missing` is 0 on every switch, and `ecmp_lost_paths` is empty everywhere.
- `frr` and `nvued` are active on all switches. Uptime is 327 min everywhere, so no device has rebooted recently. Load is low (0.04 to 0.27).

Only a few drop counters are non-zero, and they are not a concern:
- Spine2 shows `drops: 2` on each of swp1 to swp5. The identical value on every port points to a common cause, such as a one-time event at boot. It is not tied to a single link.
- Leaf5 swp1 shows `drops: 1` (towards Spine1 swp5).
- Errors are 0 on every port. Counters are cumulative since boot, and the snapshot has no earlier sample, so I cannot tell whether these drops are still growing.

The snapshot cannot tell me whether RoCE/lossless settings are correct, because Cumulus VX has no hardware QoS. It also does not show whether the servers can reach each other end to end, only the switch-side state.

### What looks healthy
The whole underlay matches the design: full leaf-spine BGP unnumbered with BFD, all 4 servers attached on all 5 rails, and every leaf has 4 spine paths. No fix is needed. If you want to be thorough, you can re-check the few drop counters later to confirm they are static (read-only):

- Spine2: `nv show interface swp1 counters`, then run it again after a few minutes and compare.
- Leaf5: `nv show interface swp1 counters`.
- Whole fabric: `ansible-playbook playbooks/verify.yml`.

_7263 tokens in, 745 out. The AI summary is generated from the evidence below; check it against the findings._

## Findings

No problems found.

## Switches

| Switch | Read | Fabric ports up | Server ports up | BGP | BFD | Routes missing | Uptime (min) | Load |
|---|---|---|---|---|---|---|---|---|
| Spine1 | yes | 5/5 | - | 5/5 | 5/5 | 0 | 327 | 0.14 |
| Spine2 | yes | 5/5 | - | 5/5 | 5/5 | 0 | 327 | 0.27 |
| Spine3 | yes | 5/5 | - | 5/5 | 5/5 | 0 | 327 | 0.11 |
| Spine4 | yes | 5/5 | - | 5/5 | 5/5 | 0 | 327 | 0.13 |
| Leaf1 | yes | 4/4 | 4/4 | 4/4 | 4/4 | 0 | 327 | 0.17 |
| Leaf2 | yes | 4/4 | 4/4 | 4/4 | 4/4 | 0 | 327 | 0.14 |
| Leaf3 | yes | 4/4 | 4/4 | 4/4 | 4/4 | 0 | 327 | 0.04 |
| Leaf4 | yes | 4/4 | 4/4 | 4/4 | 4/4 | 0 | 327 | 0.06 |
| Leaf5 | yes | 4/4 | 4/4 | 4/4 | 4/4 | 0 | 327 | 0.09 |

Raw outputs: `state/2026-10-28T005347Z/`
