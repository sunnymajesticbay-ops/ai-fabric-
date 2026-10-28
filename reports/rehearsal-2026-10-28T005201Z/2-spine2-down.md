# Fabric doctor report, 2026-10-28T005301Z

**Checker verdict:** PROBLEMS FOUND (13 critical, 0 warnings). Switches read: 9 of 9.

## AI diagnosis (claude-sonnet-5-5)

**Verdict:** Degraded. Spine2 is cut off from the fabric, so every leaf runs on 3 of 4 spines. The snapshot shows no unreachable prefixes.

### What's wrong

1. **Spine2 has all 5 fabric ports administratively down (root cause).**
   - Evidence: on Spine2, swp1 to swp5 all show `admin: down, carrier: false`, BGP `idle` and BFD `down` on 5/5 sessions. The raw tables show the sessions were reset only 0:00:26 ago, and Spine2's uptime is 326 min. So the device did not reboot, and the ports were shut after boot, most likely by a manual `nv set interface swp1-5 link state down` or a bad config push.
   - The cause is probably a config change, but the snapshot cannot show who made it.
   - Impact: Spine2 carries no traffic. Every rail loses 1 of 4 uplinks (25% of leaf-to-spine capacity) and ECMP drops from 4 to 3 paths.

2. **All 5 leaves show the swp2 session to Spine2 down. This is a consequence of #1.**
   - Evidence: Leaf1 to Leaf5 swp2 show BGP `connect` and BFD `down`, while carrier is still `true` and admin `up`. This matches the DSX Air quirk, where the far end keeps carrier when one end is shut.
   - The leaf side is not at fault, and its ports need no change.

3. **Spine2's loopback 10.10.10.102/32 is missing on all leaves, and Spine2 is missing 25 prefixes. Both are consequences of #1.**
   - Evidence: each leaf lists `missing_routes_by_origin: Spine2: 10.10.10.102/32`. Spine2 lacks the leaf loopbacks and server subnets (for example 10.1.1.0/30).
   - Impact: only Spine2's own loopback is unreachable. The leaf and server prefixes are all still learned via Spine1, Spine3 and Spine4 (PfxRcvd 21 on each established session).

### How to confirm and fix

**Spine2**
```
nv show interface swp1-5 link
nv config diff
nv config history
```
Fix through Git: check that the Ansible inventory has these ports enabled, then run `ansible-playbook playbooks/underlay.yml --limit Spine2`. The manual equivalent (NVUE fix):
```
nv unset interface swp1-5 link state
nv set interface swp1-5 link state up
nv config apply -y
```

**Leaf1 to Leaf5 (verify only)**
```
nv show vrf default router bgp neighbor
nv show interface swp2
```

**From the control host**
```
ansible-playbook playbooks/verify.yml
```
Expect 5/5 BGP and BFD on Spine2, and 4/4 on every leaf.

### What looks healthy
Spine1, Spine3 and Spine4 have 5/5 BGP and BFD sessions, and all leaf server ports are up (4/4). Every leaf has 3 established sessions with 21 prefixes received on each. The only counter anomaly is 1 drop on Leaf5 swp1, which is negligible and cumulative since boot.

_14696 tokens in, 1096 out. The AI summary is generated from the evidence below; check it against the findings._

## Findings

| Severity | Device | Check | Detail |
|---|---|---|---|
| CRIT | Spine2 | fabric | ROOT CAUSE CANDIDATE: all 5 readable neighbors report their BGP session to Spine2 down (Leaf1 swp2: connect, Leaf2 swp2: connect, Leaf3 swp2: connect, Leaf4 swp2: connect, Leaf5 swp2: connect). Spine2 is cut off from the fabric. |
| CRIT | Spine2 | fabric | 5 switches (Leaf1, Leaf2, Leaf3, Leaf4, Leaf5) have no route to Spine2's prefixes: the problem is at or next to Spine2, not on each switch |
| CRIT | Leaf1 | bgp | BGP not established on 1 of 4 sessions: swp2 to Spine2 (connect) |
| CRIT | Leaf2 | bgp | BGP not established on 1 of 4 sessions: swp2 to Spine2 (connect) |
| CRIT | Leaf3 | bgp | BGP not established on 1 of 4 sessions: swp2 to Spine2 (connect) |
| CRIT | Leaf4 | bgp | BGP not established on 1 of 4 sessions: swp2 to Spine2 (connect) |
| CRIT | Leaf5 | bgp | BGP not established on 1 of 4 sessions: swp2 to Spine2 (connect) |
| CRIT | Spine2 | bgp | BGP not established on 5 of 5 sessions: swp1 to Leaf1 (idle); swp2 to Leaf2 (idle); swp3 to Leaf3 (idle); swp4 to Leaf4 (idle); swp5 to Leaf5 (idle) |
| CRIT | Spine2 | interfaces | swp1 (to Leaf1 swp2) is administratively down |
| CRIT | Spine2 | interfaces | swp2 (to Leaf2 swp2) is administratively down |
| CRIT | Spine2 | interfaces | swp3 (to Leaf3 swp2) is administratively down |
| CRIT | Spine2 | interfaces | swp4 (to Leaf4 swp2) is administratively down |
| CRIT | Spine2 | interfaces | swp5 (to Leaf5 swp2) is administratively down |
| INFO | Leaf1 | bfd | BFD also down where BGP is down: swp2 to Spine2 (down) |
| INFO | Leaf2 | bfd | BFD also down where BGP is down: swp2 to Spine2 (down) |
| INFO | Leaf3 | bfd | BFD also down where BGP is down: swp2 to Spine2 (down) |
| INFO | Leaf4 | bfd | BFD also down where BGP is down: swp2 to Spine2 (down) |
| INFO | Leaf5 | bfd | BFD also down where BGP is down: swp2 to Spine2 (down) |
| INFO | Spine2 | bfd | BFD also down where BGP is down: swp1 to Leaf1 (down); swp2 to Leaf2 (down); swp3 to Leaf3 (down); swp4 to Leaf4 (down); swp5 to Leaf5 (down) |
| INFO | Spine2 | routes | Spine2 has no route to 25 prefixes: expected while it has no BGP sessions |

## Switches

| Switch | Read | Fabric ports up | Server ports up | BGP | BFD | Routes missing | Uptime (min) | Load |
|---|---|---|---|---|---|---|---|---|
| Spine1 | yes | 5/5 | - | 5/5 | 5/5 | 0 | 326 | 0.13 |
| Spine2 | yes | 0/5 | - | 0/5 | 0/5 | 25 | 326 | 0.12 |
| Spine3 | yes | 5/5 | - | 5/5 | 5/5 | 0 | 326 | 0.06 |
| Spine4 | yes | 5/5 | - | 5/5 | 5/5 | 0 | 326 | 0.10 |
| Leaf1 | yes | 4/4 | 4/4 | 3/4 | 3/4 | 1 | 326 | 0.08 |
| Leaf2 | yes | 4/4 | 4/4 | 3/4 | 3/4 | 1 | 326 | 0.22 |
| Leaf3 | yes | 4/4 | 4/4 | 3/4 | 3/4 | 1 | 326 | 0.09 |
| Leaf4 | yes | 4/4 | 4/4 | 3/4 | 3/4 | 1 | 326 | 0.04 |
| Leaf5 | yes | 4/4 | 4/4 | 3/4 | 3/4 | 1 | 326 | 0.10 |

Raw outputs: `state/2026-10-28T005301Z/`
