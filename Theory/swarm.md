## Docker Swarm 

### Environment Details

| Property | Value |
|---|---|
| Host | Aniket (WSL2 / Ubuntu) |
| Docker Engine Version | 29.2.1 |
| Swarm Advertise Address | 10.255.255.254 |
| Service Published Port | 8080 → 80 (nginx) |
| Date | February 28, 2026 |

---

### Step-by-Step Procedure

### Initialize Docker Swarm


```docker swarm init```

This tells Docker to switch from "single-host mode" into Swarm Mode. Docker automatically:

* Generates a self-signed Root Certificate Authority (CA) to secure communication.

* Creates tokens for adding other nodes (workers or additional managers).

* Sets up a distributed state store (Raft) to keep track of services.

```--advertise-addr 10.255.255.254```

This is the most important flag when your machine has multiple IP addresses. It tells the rest of the cluster: "Hey, if you want to talk to the manager, reach me at this specific IP."


```bash
$ docker swarm init --advertise-addr 10.255.255.254
Swarm initialized: current node (cmm1lrih9w3ulb5tci2hwyygg) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-1f3cf3a2r8whejh8dkks603qtvdt4n2qsygpaa3l6dv5zx77v6-bcenpi1xxpfv1abjt3kv0pme2 10.255.255.254:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
```

### Verify Swarm Node Status

```bash
$ docker node ls
```

| Node ID | Hostname | Status | Availability | Manager Status | Engine Version |
|---|---|---|---|---|---|
| cmm1lrih9w3ulb5tci2hwyygg * | Aniket | Ready | Active | Leader | 29.2.1 |

---

### Create the Web Service

```docker service create```

This tells the Swarm Manager to create a Service.  If a container crashes or a server restarts, the Swarm will automatically notice and restart it to keep things running.

```--name webapp```

This gives your service a human-readable name. Instead of referring to random container IDs (like a1b2c3d4), you can manage, scale, or inspect the group of containers using the name webapp.

```--replicas 3```

It will make 3 copy of container. If one server fails, Docker will instantly spin up a replacement on a different server to ensure you always have exactly 3.

```-p 8080:80```

This maps the ports.
8080 (Host): This is the port you will type into your browser (e.g., http://localhost:8080).

```nginx```

This is the Image being used. Docker will pull the latest Nginx web server image from Docker Hub to create your containers.

```bash
$ docker service create \
  --name webapp \
  --replicas 3 \
  -p 8080:80 \
  nginx
```

Docker confirmed all 3 out of 3 tasks converged successfully:

```
overall progress: 3 out of 3 tasks
1/3: running   [==================================================>]
2/3: running   [==================================================>]
3/3: running   [==================================================>]
verify: Service jk0f3notfdejxbh3dtuaz3rko converged
```

### List Running Services

```bash
$ docker service ls
```

| ID | Name | Mode | Replicas | Image | Ports |
|---|---|---|---|---|---|
| jk0f3notfdej | webapp | replicated | 3/3 | nginx:latest | *:8080->80/tcp |

---

### Inspect the Service

```bash
$ docker service inspect webapp
```

Key configuration details from the inspection output:

| Field | Value |
|---|---|
| Image | nginx:latest (SHA256 digest pinned) |
| Mode | Replicated — 3 replicas |
| Restart Policy | Condition: any, Delay: 5s |
| Update Config | Parallelism: 1, stop-first, pause on failure |
| Rollback Config | Same as update config |
| Published Port | 8080 TCP (ingress) → Target Port 80 |
| Virtual IP (VIP) | 10.0.0.3/24 |

---

### Inspect Running Tasks

```bash
$ docker service ps webapp
```

| Task ID | Name | Image | Node | Desired State | Current State |
|---|---|---|---|---|---|
| awap8dm5hfj7 | webapp.1 | nginx:latest | Aniket | Running | Running 2m ago |
| mooida4bafox | webapp.2 | nginx:latest | Aniket | Running | Running 2m ago |
| l0885jf9wp4z | webapp.3 | nginx:latest | Aniket | Running | Running 2m ago |

---

### Scale the Service

The service was scaled from 3 replicas to 6 using the `docker service scale` command:

```bash
$ docker service scale webapp=6
webapp scaled to 6
overall progress: 6 out of 6 tasks
1/6: running   [==================================================>]
2/6: running   [==================================================>]
3/6: running   [==================================================>]
4/6: running   [==================================================>]
5/6: running   [==================================================>]
6/6: running   [==================================================>]
verify: Service webapp converged
```

## WSL Comand
```
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker swarm init --advertise-addr 10.255.255.254
Swarm initialized: current node (cmm1lrih9w3ulb5tci2hwyygg) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-1f3cf3a2r8whejh8dkks603qtvdt4n2qsygpaa3l6dv5zx77v6-bcenpi1xxpfv1abjt3kv0pme2 10.255.255.254:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker node ls
ID                            HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
cmm1lrih9w3ulb5tci2hwyygg *   Aniket     Ready     Active         Leader           29.2.1
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker service create \
  --name webapp \
  --replicas 3 \
  -p 8080:80 \
  nginx
jk0f3notfdejxbh3dtuaz3rko
overall progress: 3 out of 3 tasks
1/3: running   [==================================================>]
2/3: running   [==================================================>]
3/3: running   [==================================================>]
verify: Service jk0f3notfdejxbh3dtuaz3rko converged
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker service ls
ID             NAME      MODE         REPLICAS   IMAGE          PORTS
jk0f3notfdej   webapp    replicated   3/3        nginx:latest   *:8080->80/tcp
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker service ps webapp
ID             NAME       IMAGE          NODE      DESIRED STATE   CURRENT STATE           ERROR     PORTS
awap8dm5hfj7   webapp.1   nginx:latest   Aniket    Running         Running 2 minutes ago
mooida4bafox   webapp.2   nginx:latest   Aniket    Running         Running 2 minutes ago
l0885jf9wp4z   webapp.3   nginx:latest   Aniket    Running         Running 2 minutes ago
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker service inspect webapp
[
    {
        "ID": "jk0f3notfdejxbh3dtuaz3rko",
        "Version": {
            "Index": 13
        },
        "CreatedAt": "2026-02-28T05:54:13.539403325Z",
        "UpdatedAt": "2026-02-28T05:54:13.549918112Z",
        "Spec": {
            "Name": "webapp",
            "Labels": {},
            "TaskTemplate": {
                "ContainerSpec": {
                    "Image": "nginx:latest@sha256:0236ee02dcbce00b9bd83e0f5fbc51069e7e1161bd59d99885b3ae1734f3392e",
                    "Init": false,
                    "StopGracePeriod": 10000000000,
                    "DNSConfig": {},
                    "Isolation": "default"
                },
                "Resources": {
                    "Limits": {},
                    "Reservations": {}
                },
                "RestartPolicy": {
                    "Condition": "any",
                    "Delay": 5000000000,
                    "MaxAttempts": 0
                },
                "Placement": {
                    "Platforms": [
                        {
                            "Architecture": "amd64",
                            "OS": "linux"
                        },
                        {
                            "Architecture": "unknown",
                            "OS": "unknown"
                        },
                        {
                            "OS": "linux"
                        },
                        {
                            "Architecture": "unknown",
                            "OS": "unknown"
                        },
                        {
                            "OS": "linux"
                        },
                        {
                            "Architecture": "unknown",
                            "OS": "unknown"
                        },
                        {
                            "Architecture": "arm64",
                            "OS": "linux"
                        },
                        {
                            "Architecture": "unknown",
                            "OS": "unknown"
                        },
                        {
                            "Architecture": "386",
                            "OS": "linux"
                        },
                        {
                            "Architecture": "unknown",
                            "OS": "unknown"
                        },
                        {
                            "Architecture": "ppc64le",
                            "OS": "linux"
                        },
                        {
                            "Architecture": "unknown",
                            "OS": "unknown"
                        },
                        {
                            "Architecture": "riscv64",
                            "OS": "linux"
                        },
                        {
                            "Architecture": "unknown",
                            "OS": "unknown"
                        },
                        {
                            "Architecture": "s390x",
                            "OS": "linux"
                        },
                        {
                            "Architecture": "unknown",
                            "OS": "unknown"
                        }
                    ]
                },
                "ForceUpdate": 0,
                "Runtime": "container"
            },
            "Mode": {
                "Replicated": {
                    "Replicas": 3
                }
            },
            "UpdateConfig": {
                "Parallelism": 1,
                "FailureAction": "pause",
                "Monitor": 5000000000,
                "MaxFailureRatio": 0,
                "Order": "stop-first"
            },
            "RollbackConfig": {
                "Parallelism": 1,
                "FailureAction": "pause",
                "Monitor": 5000000000,
                "MaxFailureRatio": 0,
                "Order": "stop-first"
            },
            "EndpointSpec": {
                "Mode": "vip",
                "Ports": [
                    {
                        "Protocol": "tcp",
                        "TargetPort": 80,
                        "PublishedPort": 8080,
                        "PublishMode": "ingress"
                    }
                ]
            }
        },
        "Endpoint": {
            "Spec": {
                "Mode": "vip",
                "Ports": [
                    {
                        "Protocol": "tcp",
                        "TargetPort": 80,
                        "PublishedPort": 8080,
                        "PublishMode": "ingress"
                    }
                ]
            },
            "Ports": [
                {
                    "Protocol": "tcp",
                    "TargetPort": 80,
                    "PublishedPort": 8080,
                    "PublishMode": "ingress"
                }
            ],
            "VirtualIPs": [
                {
                    "NetworkID": "d0y73ettp20b2lobbgtf08n25",
                    "Addr": "10.0.0.3/24"
                }
            ]
        }
    }
]
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker service scale webapp=6
webapp scaled to 6
overall progress: 6 out of 6 tasks
1/6: running   [==================================================>]
2/6: running   [==================================================>]
3/6: running   [==================================================>]
4/6: running   [==================================================>]
5/6: running   [==================================================>]
6/6: running   [==================================================>]
verify: Service webapp converged
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$
```