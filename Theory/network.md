### Docker Networking
---
### Theory: Docker Networking 

When you run a Docker container, it runs in an **isolated environment** — like an apartment in a building. Each container has:

- Its own **IP address** (like an apartment number)
- Ways to **communicate with other containers** (hallways)
- Ways to **access the internet** (external mail)
- **Ports** to receive incoming traffic (doors)

Docker Networking solves four core problems:

| Problem | Solution |
|---|---|
| Container ↔ Container | Shared Docker networks with DNS |
| Container ↔ Host Machine | Port publishing (`-p`) or host network |
| Container ↔ Internet | NAT via the bridge gateway |
| Containers on different servers | Overlay networks (multi-host) |

---

### Docker Network Drivers

Docker provides several network drivers for different use cases:

| Driver | Simple Analogy | When to Use |
|---|---|---|
| `bridge` | Apartment building with shared hallway | Default for single host, most common |
| `host` | Living in same room as host | Need max performance, no isolation needed |
| `overlay` | Underground tunnel connecting buildings | Multiple servers need to talk |
| `macvlan` | Separate house with own mailbox | Need real network IP per container |
| `none` | Isolated room with no doors | Complete isolation needed |

**we use `bridge` (the most common type) and `host`.**

---

### 3. Practical

### List Default Networks

```bash
docker network ls
```

**Output:**
```
NETWORK ID     NAME      DRIVER    SCOPE
31616f46d165   bridge    bridge    local
a949c49a1f96   host      host      local
cea44970056d   none      null      local
```

**Explanation:**  
When Docker is installed, it automatically creates three networks: `bridge` (the default), `host` (shares the host's network), and `none` (fully isolated, no networking).

---

### Inspect the Default Bridge Network

```bash
docker network inspect bridge
```

**Output (key fields):**
```json
{
    "Name": "bridge",
    "Driver": "bridge",
    "IPAM": {
        "Config": [
            {
                "Subnet": "172.17.0.0/16",
                "Gateway": "172.17.0.1"
            }
        ]
    },
    "Options": {
        "com.docker.network.bridge.name": "docker0",
        "com.docker.network.bridge.enable_ip_masquerade": "true",
        "com.docker.network.driver.mtu": "1500"
    }
}
```

**Explanation:**  
The default `bridge` network uses the `172.17.0.0/16` subnet and routes traffic through gateway `172.17.0.1`. The underlying virtual interface is named `docker0`. The `enable_ip_masquerade: true` option means containers can reach the internet via NAT.

**Important:** The default bridge network does **NOT** support DNS resolution by name. Containers can only reach each other by IP, not by container name. This is why we create a **custom bridge**.

---

### Create a Custom Bridge Network

```bash
docker network create my_bridge
```

**Output:**
```
edabda8e9816e73a6e48c82732cfb23f3bef5dfb53c25f27434121f310821baa
```

**Explanation:**  
This creates a new user-defined bridge network called `my_bridge`. Docker returns the full network ID upon creation.

```bash
docker network inspect my_bridge
```

**Key output:**
```json
{
    "Name": "my_bridge",
    "Driver": "bridge",
    "IPAM": {
        "Config": [
            {
                "Subnet": "172.18.0.0/16",
                "Gateway": "172.18.0.1"
            }
        ]
    }
}
```

**Explanation:**  
Docker automatically assigned `my_bridge` the next available subnet — `172.18.0.0/16` (since `172.17.0.0/16` was taken by the default bridge). The key advantage of a custom bridge is **automatic DNS** — containers can find each other by name, not just IP.

---

### Run Containers on the Custom Network

**Run container1 (nginx web server):**
```bash
docker run -dit --name container1 --network my_bridge nginx
```

**Output:**
```
33073f88712c85a53336a0f61d3d4de085d7ea76445654e6081535fd51d4db64
```

**Run container2 (busybox utility):**
```bash
docker run -dit --name container2 --network my_bridge busybox
```

**Output (first-time image pull):**
```
Unable to find image 'busybox:latest' locally
latest: Pulling from library/busybox
61dfb50712f5: Pull complete
Digest: sha256:b3255e7dfbcd10cb367af0d409747d511aeb66dfac98cf30e97e87e4207dd76f
Status: Downloaded newer image for busybox:latest
d525cc4a02bbee90c344acd1992c5ef81d6f005ff4c82d76600659792b486862
```

**Explanation of flags:**

| Flag | Meaning |
|---|---|
| `-d` | Detached mode — run container in background |
| `-i` | Interactive — keep STDIN open |
| `-t` | Allocate a pseudo-TTY (terminal) |
| `--name` | Assign a human-readable name to the container |
| `--network` | Connect the container to the specified network |

**Note:** The first time an image is used, Docker pulls it from Docker Hub. Subsequent runs use the local cached image.

---

### Test Container-to-Container Communication (by Name)

```bash
docker exec -it container2 ping container1
```

**Output:**
```
PING container1 (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.397 ms
64 bytes from 172.18.0.2: seq=1 ttl=64 time=0.145 ms
64 bytes from 172.18.0.2: seq=2 ttl=64 time=0.098 ms
...
44 packets transmitted, 44 packets received, 0% packet loss
round-trip min/avg/max = 0.070/0.112/0.397 ms
```

**Explanation:**  
`docker exec -it container2 ping container1` runs the `ping` command inside `container2`, targeting `container1` **by name**. Docker's embedded DNS server (running at `127.0.0.11` inside each container) resolved `container1` → `172.18.0.2` automatically.

- **0% packet loss** confirms the two containers are communicating successfully on the same custom bridge network.
- **Round-trip time ~0.112ms** — very low latency since both containers are on the same host.


**Magic moment:** This only works because both containers are on the same **user-defined bridge**. The default bridge network does NOT support this name-based DNS.

---

### Inspect container1 for Network Details

```bash
docker inspect container1
```

**Key sections from the output:**

**State:**
```json
"State": {
    "Status": "running",
    "Running": true,
    "Pid": 11359
}
```

**Network Settings:**
```json
"NetworkSettings": {
    "Networks": {
        "my_bridge": {
            "Gateway": "172.18.0.1",
            "IPAddress": "172.18.0.2",
            "MacAddress": "de:12:4c:c1:8f:3c",
            "DNSNames": ["container1", "33073f88712c"]
        }
    }
}
```

**Explanation:**  
`docker inspect` returns full JSON metadata about the container. Important fields:

| Field | Value | Meaning |
|---|---|---|
| `Status` | `running` | Container is actively running |
| `Pid` | `11359` | Host process ID of the container's main process |
| `IPAddress` | `172.18.0.2` | Container's IP on `my_bridge` |
| `MacAddress` | `de:12:4c:c1:8f:3c` | Virtual MAC address assigned by Docker |
| `Gateway` | `172.18.0.1` | Traffic to outside the network routes through this |
| `DNSNames` | `container1`, `33073f88712c` | Names usable for DNS resolution |

---

### Extract IP Address

```bash
docker inspect container1 | grep IP
```

**Output:**
```
"IPAMConfig": null,
"IPAddress": "172.18.0.2",
"IPPrefixLen": 16,
"IPv6Gateway": "",
"GlobalIPv6Address": "",
"GlobalIPv6PrefixLen": 0,
```

**Explanation:**  
This is a quick way to grep just the IP-related fields without reading the full JSON. `container1` has been assigned `172.18.0.2` on the `my_bridge` network with a `/16` prefix (subnet mask `255.255.0.0`).

> **Better alternative (from theory):**
> ```bash
> docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' container1
> ```
> This returns just the IP address cleanly.

---

### Test Cross-Network Isolation

```bash
docker exec -it container2 ping 172.17.0.2
```

**Output:**
```
PING 172.17.0.2 (172.17.0.2): 56 data bytes
--- 172.17.0.2 ping statistics ---
13 packets transmitted, 0 packets received, 100% packet loss
```

**Explanation:**  
`172.17.0.2` is an IP in the **default bridge** network (`172.17.0.0/16`). `container2` lives in `my_bridge` (`172.18.0.0/16`). Since these are **two separate networks**, Docker's isolation rules prevent communication — `100% packet loss` is the expected, correct result.

**This proves network isolation works:** Containers on different Docker networks cannot talk to each other unless explicitly connected.

---

### Host Network Mode

```bash
docker run -d --network host nginx
```

**Output:**
```
2a2b1405645cab1c4085613d4863b7826526058f45b7212ee0272201f3104b83
```

**Verify nginx is listening on the host:**
```bash
ss -tulnp | grep 80
```

**Output:**
```
tcp   LISTEN 0   100       0.0.0.0:6080     0.0.0.0:*    users:(("nova-novncproxy",...))
tcp   LISTEN 0   511             *:80             *:*
tcp   LISTEN 0   4096            *:2380           *:*
```

**Explanation:**  
`--network host` removes all network isolation between the container and the host. Nginx inside the container now binds directly to **port 80 on the host machine** — no `-p` port mapping needed.

The `ss -tulnp` command lists all listening TCP/UDP sockets:

| Column | Meaning |
|---|---|
| `tcp LISTEN` | A listening TCP socket |
| `*:80` | Listening on all interfaces on port 80 |
| `0.0.0.0:6080` | Another process on port 6080 |

**When NOT to use host network:**
- When you need isolation (containers may conflict with host services)
- On Docker Desktop for Mac/Windows (limited support)
- When running multiple containers needing the same ports

---


### Key Observations 

| Observation | What It Proves |
|---|---|
| `container2` pings `container1` by name successfully | Custom bridge networks have built-in DNS |
| `172.17.0.0/16` for default bridge, `172.18.0.0/16` for `my_bridge` | Docker auto-assigns non-overlapping subnets |
| 100% packet loss when pinging across networks | Network isolation works correctly |
| `*:80` appears in `ss` output after `--network host` | Host network shares the host's port space directly |
| busybox image pulled automatically | Docker Hub is the default image registry |

---
### MACVLAN VS IPVLAN

| Feature | MACVLAN | IPVLAN |
|---|---|---|
| MAC addresses | One per container | One shared for all |
| Network switch load | Higher | Lower |
| Scalability | Limited by switch | Much higher |
| Best for | Small deployments | Large-scale |
---

### Quick Reference Cheatsheet

### Network Management

| Command | Description |
|---|---|
| `docker network ls` | List all networks |
| `docker network create mynet` | Create a new bridge network |
| `docker network inspect mynet` | Show detailed network info |
| `docker network rm mynet` | Delete a network |
| `docker network prune` | Remove all unused networks |
| `docker network connect mynet container` | Add a running container to a network |
| `docker network disconnect mynet container` | Remove container from network |

### Running Containers with Networks

| Command | Description |
|---|---|
| `docker run --network mynet ...` | Start container in specific network |
| `docker run -p 8080:80 ...` | Map host port 8080 to container port 80 |
| `docker run -p 127.0.0.1:8080:80 ...` | Bind only to localhost |
| `docker run -P ...` | Auto-assign random host ports |
| `docker run --network host ...` | Use host's network directly |


## WSL Command 
```
aniket@Aniket:~$ docker network ls
NETWORK ID     NAME      DRIVER    SCOPE
31616f46d165   bridge    bridge    local
a949c49a1f96   host      host      local
cea44970056d   none      null      local
aniket@Aniket:~$ docker network inspect bridge
[
    {
        "Name": "bridge",
        "Id": "31616f46d165049ee9c62fd82cea0536491313c7a4bd9b63858b1849a333b663",
        "Created": "2026-02-18T14:38:09.64660814+05:30",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv4": true,
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "172.17.0.0/16",
                    "IPRange": "",
                    "Gateway": "172.17.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Options": {
            "com.docker.network.bridge.default_bridge": "true",
            "com.docker.network.bridge.enable_icc": "true",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
            "com.docker.network.bridge.name": "docker0",
            "com.docker.network.driver.mtu": "1500"
        },
        "Labels": {},
        "Containers": {},
        "Status": {
            "IPAM": {
                "Subnets": {
                    "172.17.0.0/16": {
                        "IPsInUse": 3,
                        "DynamicIPsAvailable": 65533
                    }
                }
            }
        }
    }
]
aniket@Aniket:~$ docker network create my_bridge
edabda8e9816e73a6e48c82732cfb23f3bef5dfb53c25f27434121f310821baa
aniket@Aniket:~$ docker network inspect my_bridge
[
    {
        "Name": "my_bridge",
        "Id": "edabda8e9816e73a6e48c82732cfb23f3bef5dfb53c25f27434121f310821baa",
        "Created": "2026-02-18T14:42:19.71029279+05:30",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv4": true,
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": {},
            "Config": [
                {
                    "Subnet": "172.18.0.0/16",
                    "IPRange": "",
                    "Gateway": "172.18.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Options": {},
        "Labels": {},
        "Containers": {},
        "Status": {
            "IPAM": {
                "Subnets": {
                    "172.18.0.0/16": {
                        "IPsInUse": 3,
                        "DynamicIPsAvailable": 65533
                    }
                }
            }
        }
    }
]
aniket@Aniket:~$ docker run -dit --name container1 --network my_bridge nginx
33073f88712c85a53336a0f61d3d4de085d7ea76445654e6081535fd51d4db64
aniket@Aniket:~$ docker run -dit --name container2 --network my_bridge busybox
Unable to find image 'busybox:latest' locally
latest: Pulling from library/busybox
61dfb50712f5: Pull complete
96cfb76e59bd: Download complete
Digest: sha256:b3255e7dfbcd10cb367af0d409747d511aeb66dfac98cf30e97e87e4207dd76f
Status: Downloaded newer image for busybox:latest
d525cc4a02bbee90c344acd1992c5ef81d6f005ff4c82d76600659792b486862
aniket@Aniket:~$ docker exec -it container2 ping container1
PING container1 (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.397 ms
64 bytes from 172.18.0.2: seq=1 ttl=64 time=0.145 ms
64 bytes from 172.18.0.2: seq=2 ttl=64 time=0.098 ms
64 bytes from 172.18.0.2: seq=3 ttl=64 time=0.105 ms
64 bytes from 172.18.0.2: seq=4 ttl=64 time=0.103 ms
64 bytes from 172.18.0.2: seq=5 ttl=64 time=0.117 ms
64 bytes from 172.18.0.2: seq=6 ttl=64 time=0.101 ms
64 bytes from 172.18.0.2: seq=7 ttl=64 time=0.087 ms
64 bytes from 172.18.0.2: seq=8 ttl=64 time=0.116 ms
64 bytes from 172.18.0.2: seq=9 ttl=64 time=0.096 ms
64 bytes from 172.18.0.2: seq=10 ttl=64 time=0.075 ms
64 bytes from 172.18.0.2: seq=11 ttl=64 time=0.096 ms
64 bytes from 172.18.0.2: seq=12 ttl=64 time=0.129 ms
64 bytes from 172.18.0.2: seq=13 ttl=64 time=0.120 ms
64 bytes from 172.18.0.2: seq=14 ttl=64 time=0.089 ms
64 bytes from 172.18.0.2: seq=15 ttl=64 time=0.100 ms
64 bytes from 172.18.0.2: seq=16 ttl=64 time=0.107 ms
64 bytes from 172.18.0.2: seq=17 ttl=64 time=0.126 ms
64 bytes from 172.18.0.2: seq=18 ttl=64 time=0.075 ms
64 bytes from 172.18.0.2: seq=19 ttl=64 time=0.095 ms
64 bytes from 172.18.0.2: seq=20 ttl=64 time=0.076 ms
64 bytes from 172.18.0.2: seq=21 ttl=64 time=0.116 ms
64 bytes from 172.18.0.2: seq=22 ttl=64 time=0.090 ms
64 bytes from 172.18.0.2: seq=23 ttl=64 time=0.096 ms
64 bytes from 172.18.0.2: seq=24 ttl=64 time=0.142 ms
64 bytes from 172.18.0.2: seq=25 ttl=64 time=0.116 ms
64 bytes from 172.18.0.2: seq=26 ttl=64 time=0.081 ms
64 bytes from 172.18.0.2: seq=27 ttl=64 time=0.078 ms
64 bytes from 172.18.0.2: seq=28 ttl=64 time=0.075 ms
64 bytes from 172.18.0.2: seq=29 ttl=64 time=0.079 ms
64 bytes from 172.18.0.2: seq=30 ttl=64 time=0.082 ms
^C
--- container1 ping statistics ---
44 packets transmitted, 44 packets received, 0% packet loss
round-trip min/avg/max = 0.070/0.112/0.397 ms
aniket@Aniket:~$ docker inspect container1
[
    {
        "Id": "33073f88712c85a53336a0f61d3d4de085d7ea76445654e6081535fd51d4db64",
        "Created": "2026-02-18T09:14:28.505803359Z",
        "Path": "/docker-entrypoint.sh",
        "Args": [
            "nginx",
            "-g",
            "daemon off;"
        ],
        "State": {
            "Status": "running",
            "Running": true,
            "Paused": false,
            "Restarting": false,
            "OOMKilled": false,
            "Dead": false,
            "Pid": 11359,
            "ExitCode": 0,
            "Error": "",
            "StartedAt": "2026-02-18T09:14:28.758838469Z",
            "FinishedAt": "0001-01-01T00:00:00Z"
        },
        "Image": "sha256:9dd288848f4495869f76676e419ae2d767ca99fece2ec37ec0261f9fdaab5204",
        "ResolvConfPath": "/var/lib/docker/containers/33073f88712c85a53336a0f61d3d4de085d7ea76445654e6081535fd51d4db64/resolv.conf",
        "HostnamePath": "/var/lib/docker/containers/33073f88712c85a53336a0f61d3d4de085d7ea76445654e6081535fd51d4db64/hostname",
        "HostsPath": "/var/lib/docker/containers/33073f88712c85a53336a0f61d3d4de085d7ea76445654e6081535fd51d4db64/hosts",
        "LogPath": "/var/lib/docker/containers/33073f88712c85a53336a0f61d3d4de085d7ea76445654e6081535fd51d4db64/33073f88712c85a53336a0f61d3d4de085d7ea76445654e6081535fd51d4db64-json.log",
        "Name": "/container1",
        "RestartCount": 0,
        "Driver": "overlayfs",
        "Platform": "linux",
        "MountLabel": "",
        "ProcessLabel": "",
        "AppArmorProfile": "",
        "ExecIDs": null,
        "HostConfig": {
            "Binds": null,
            "ContainerIDFile": "",
            "LogConfig": {
                "Type": "json-file",
                "Config": {}
            },
            "NetworkMode": "my_bridge",
            "PortBindings": {},
            "RestartPolicy": {
                "Name": "no",
                "MaximumRetryCount": 0
            },
            "AutoRemove": false,
            "VolumeDriver": "",
            "VolumesFrom": null,
            "ConsoleSize": [
                43,
                76
            ],
            "CapAdd": null,
            "CapDrop": null,
            "CgroupnsMode": "private",
            "Dns": null,
            "DnsOptions": [],
            "DnsSearch": [],
            "ExtraHosts": null,
            "GroupAdd": null,
            "IpcMode": "private",
            "Cgroup": "",
            "Links": null,
            "OomScoreAdj": 0,
            "PidMode": "",
            "Privileged": false,
            "PublishAllPorts": false,
            "ReadonlyRootfs": false,
            "SecurityOpt": null,
            "UTSMode": "",
            "UsernsMode": "",
            "ShmSize": 67108864,
            "Runtime": "runc",
            "Isolation": "",
            "CpuShares": 0,
            "Memory": 0,
            "NanoCpus": 0,
            "CgroupParent": "",
            "BlkioWeight": 0,
            "BlkioWeightDevice": [],
            "BlkioDeviceReadBps": [],
            "BlkioDeviceWriteBps": [],
            "BlkioDeviceReadIOps": [],
            "BlkioDeviceWriteIOps": [],
            "CpuPeriod": 0,
            "CpuQuota": 0,
            "CpuRealtimePeriod": 0,
            "CpuRealtimeRuntime": 0,
            "CpusetCpus": "",
            "CpusetMems": "",
            "Devices": [],
            "DeviceCgroupRules": null,
            "DeviceRequests": null,
            "MemoryReservation": 0,
            "MemorySwap": 0,
            "MemorySwappiness": null,
            "OomKillDisable": null,
            "PidsLimit": null,
            "Ulimits": [],
            "CpuCount": 0,
            "CpuPercent": 0,
            "IOMaximumIOps": 0,
            "IOMaximumBandwidth": 0,
            "MaskedPaths": [
                "/proc/acpi",
                "/proc/asound",
                "/proc/interrupts",
                "/proc/kcore",
                "/proc/keys",
                "/proc/latency_stats",
                "/proc/sched_debug",
                "/proc/scsi",
                "/proc/timer_list",
                "/proc/timer_stats",
                "/sys/devices/virtual/powercap",
                "/sys/firmware"
            ],
            "ReadonlyPaths": [
                "/proc/bus",
                "/proc/fs",
                "/proc/irq",
                "/proc/sys",
                "/proc/sysrq-trigger"
            ]
        },
        "Storage": {
            "RootFS": {
                "Snapshot": {
                    "Name": "overlayfs"
                }
            }
        },
        "Mounts": [],
        "Config": {
            "Hostname": "33073f88712c",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "ExposedPorts": {
                "80/tcp": {}
            },
            "Tty": true,
            "OpenStdin": true,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
                "NGINX_VERSION=1.29.4",
                "NJS_VERSION=0.9.4",
                "NJS_RELEASE=1~trixie",
                "ACME_VERSION=0.3.1",
                "PKG_RELEASE=1~trixie",
                "DYNPKG_RELEASE=1~trixie"
            ],
            "Cmd": [
                "nginx",
                "-g",
                "daemon off;"
            ],
            "Image": "nginx",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": [
                "/docker-entrypoint.sh"
            ],
            "Labels": {
                "maintainer": "NGINX Docker Maintainers <docker-maint@nginx.com>"
            },
            "StopSignal": "SIGQUIT"
        },
        "NetworkSettings": {
            "SandboxID": "50bacfd41a1239c6e9a8900b7dcdee43db55c1388b522a31f4e11b4f2542c019",
            "SandboxKey": "/var/run/docker/netns/50bacfd41a12",
            "Ports": {
                "80/tcp": null
            },
            "Networks": {
                "my_bridge": {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": null,
                    "DriverOpts": null,
                    "GwPriority": 0,
                    "NetworkID": "edabda8e9816e73a6e48c82732cfb23f3bef5dfb53c25f27434121f310821baa",
                    "EndpointID": "0921c48710f5080e4f112533ea5bbea2f2b639c1beb0848c8f5cd50b64a08d0e",
                    "Gateway": "172.18.0.1",
                    "IPAddress": "172.18.0.2",
                    "MacAddress": "de:12:4c:c1:8f:3c",
                    "IPPrefixLen": 16,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "DNSNames": [
                        "container1",
                        "33073f88712c"
                    ]
                }
            }
        },
        "ImageManifestDescriptor": {
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "digest": "sha256:7561cad9fdf9dd48792ffb11c91196b273dcac65938b43fe4d1659179f5d289d",
            "size": 2290,
            "annotations": {
                "com.docker.official-images.bashbrew.arch": "amd64",
                "org.opencontainers.image.base.digest": "sha256:346fa035ca82052ce8ec3ddb9df460b255507acdeb1dc880a8b6930e778a553c",
                "org.opencontainers.image.base.name": "debian:trixie-slim",
                "org.opencontainers.image.created": "2026-02-03T02:22:34Z",
                "org.opencontainers.image.revision": "a306285ea2e4267c63ca539c66e8bc242bdce917",
                "org.opencontainers.image.source": "https://github.com/nginx/docker-nginx.git#a306285ea2e4267c63ca539c66e8bc242bdce917:mainline/debian",
                "org.opencontainers.image.url": "https://hub.docker.com/_/nginx",
                "org.opencontainers.image.version": "1.29.4"
            },
            "platform": {
                "architecture": "amd64",
                "os": "linux"
            }
        }
    }
]
aniket@Aniket:~$ docker inspect container1 | grep IP
                    "IPAMConfig": null,
                    "IPAddress": "172.18.0.2",
                    "IPPrefixLen": 16,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
aniket@Aniket:~$ docker exec -it container2 ping 172.17.0.2
PING 172.17.0.2 (172.17.0.2): 56 data bytes
^C
--- 172.17.0.2 ping statistics ---
13 packets transmitted, 0 packets received, 100% packet loss
aniket@Aniket:~$ docker run -d --network host nginx
2a2b1405645cab1c4085613d4863b7826526058f45b7212ee0272201f3104b83
aniket@Aniket:~$ ss -tulnp | grep 80
tcp   LISTEN 0      100           0.0.0.0:6080       0.0.0.0:*    users:(("nova-novncproxy",pid=357,fd=6))
tcp   LISTEN 0      511                 *:80               *:*
tcp   LISTEN 0      4096                *:2380             *:*
aniket@Aniket:~$
```