# AI Fabric: automated leaf-spine network on NVIDIA Cumulus Linux

A 4-spine, 5-leaf data center fabric built in NVIDIA DSX Air and configured
end to end with Ansible. One command sets the hostname, loopback, and BGP
unnumbered peering on all nine switches. A second command verifies that every
BGP session is established.

## Topology

- 4 spine and 5 leaf switches running Cumulus Linux 5.18.3
- 4 Ubuntu 24.04 servers, each connected to all five leaves
- A separate out-of-band management network (every node's eth0), so the
  switches stay reachable even if the fabric is misconfigured

| Device   | Ports         | Connect to              |
|----------|---------------|-------------------------|
| Leaf1-5  | swp1-swp4     | Spine1-Spine4           |
| Leaf1-5  | swp29-swp32   | Server4-Server1         |
| Spine1-4 | swp1-swp5     | Leaf1-Leaf5             |
| Server1-4| eth1-eth5     | Leaf1-Leaf5             |

## Addressing

| Switch | Loopback      | BGP AS |
|--------|---------------|--------|
| Spine1 | 10.10.10.101  | 65100  |
| Spine2 | 10.10.10.102  | 65100  |
| Spine3 | 10.10.10.103  | 65100  |
| Spine4 | 10.10.10.104  | 65100  |
| Leaf1  | 10.10.10.1    | 65101  |
| Leaf2  | 10.10.10.2    | 65102  |
| Leaf3  | 10.10.10.3    | 65103  |
| Leaf4  | 10.10.10.4    | 65104  |
| Leaf5  | 10.10.10.5    | 65105  |

## Design notes

- **BGP unnumbered.** Sessions are built on the interface itself, so the
  fabric links need no IP addresses. Adding a switch means adding one small
  variables file, not planning a subnet per link.
- **AS numbering.** The spines share one AS and each leaf has its own, the
  common layout for a two-tier fabric. Every leaf reaches every other leaf
  over four equal-cost paths, one through each spine.
- **Out-of-band management.** Ansible reaches the switches over eth0 in the
  management VRF, never over the fabric it is configuring.

## Repository layout

| Path                    | Contents                                         |
|-------------------------|--------------------------------------------------|
| `inventory/hosts`       | The switches, grouped into spines and leaves     |
| `inventory/group_vars/` | Fabric ports for each group                      |
| `inventory/host_vars/`  | Loopback and AS number for each switch           |
| `templates/underlay.j2` | The NVUE command template                        |
| `playbooks/underlay.yml`| Builds and applies the configuration             |
| `playbooks/verify.yml`  | Confirms every BGP session is established        |
| `configs/`              | The exact commands generated for each switch     |

## Usage

Run from the management server, inside this folder:

    ansible-playbook playbooks/underlay.yml
    ansible-playbook playbooks/verify.yml

Expected result of the verify playbook: `4 of 4 BGP sessions established` on
each leaf and `5 of 5` on each spine.

## Roadmap

- Address the server-facing ports and the servers
- Generate traffic between servers with iperf3
- Collect and graph per-port traffic across the fabric
