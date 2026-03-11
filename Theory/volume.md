# Docker Volumes

### Theory: Docker Storage 

By default, all files created inside a Docker container are stored in the **container's writable layer**. This has two major problems:

- When the container is deleted, **all data is lost**
- Data is hard to share between containers

Docker solves this with **three types of storage mounts** that persist or share data outside the container lifecycle:

```
Host Machine
├── /var/lib/docker/volumes/   ← Named Volumes (managed by Docker)
├── /any/host/path/            ← Bind Mounts (managed by you)
└── RAM (tmpfs)                ← tmpfs Mounts (in-memory, temporary)
```

---

### Types of Docker Storage

| Type | Managed By | Persists After Container Stops? | Use Case |
|---|---|---|---|
| **Volume** | Docker | Yes | Databases, app data, sharing between containers |
| **Bind Mount** | You (host path) | Yes (it's a host folder) | Dev workflow, config files, source code |
| **tmpfs** | OS (RAM) | No (lost on stop) | Secrets, sensitive temp data, performance |

**Rule:** Use **volumes** for production data. Use **bind mounts** for development. Use **tmpfs** for sensitive/temporary data you never want on disk.

---

### Practical

### Explore docker volume Command

```bash
docker volume
```

**Output:**
```
Usage:  docker volume COMMAND

Manage volumes

Commands:
  create      Create a volume
  inspect     Display detailed information on one or more volumes
  ls          List volumes
  prune       Remove unused local volumes
  rm          Remove one or more volumes

Run 'docker volume COMMAND --help' for more information on a command.
```

**Explanation:**  
Running `docker volume` with no sub-command prints the help menu listing all available volume management commands. This is useful for quickly checking what operations are available.

---

### Create a Named Volume

```bash
docker volume create testcolume01
```

**Output:**
```
testcolume01
```

**Explanation:**  
This creates a **named volume** called `testcolume01`. Docker stores it at `/var/lib/docker/volumes/testcolume01/_data` on the host. The volume name is echoed back on success.

**Note:** The volume name `testcolume01` has a typo (should be `testvolume01`) but Docker accepts any valid string as a volume name — this is not an error.

---

### List Volumes

```bash
docker volume ls
```

**Output:**
```
DRIVER    VOLUME NAME
local     testcolume01
```

**Explanation:**  
Lists all volumes currently managed by Docker. The `local` driver means the volume is stored on the local host filesystem (the default). At this point only `testcolume01` exists.

---

### Write Data into a Volume

```bash
docker run -it --rm -v testvolume01:/home/app ubuntu
```

**Inside the container:**
```bash
root@2db51a71a801:/# cd /home/app
root@2db51a71a801:/home/app# echo "my sap id: 500124385" > sapid.txt
root@2db51a71a801:/home/app# cat sapid.txt
my sap id: 500124385
root@2db51a71a801:/home/app# exit
```

**Explanation of flags:**

| Flag | Meaning |
|---|---|
| `-it` | Interactive terminal — attach to container's shell |
| `--rm` | Automatically remove the container when it exits |
| `-v testvolume01:/home/app` | Mount named volume `testvolume01` at `/home/app` inside the container |
| `ubuntu` | Use the Ubuntu image |

**What happened step by step:**
1. Docker started a temporary Ubuntu container
2. The volume `testvolume01` was mounted at `/home/app`
3. A file `sapid.txt` was created with content `my sap id: 500124385`
4. The container exited and was automatically removed (`--rm`)
5. **The volume and its data survived** — even though the container is gone

**Key insight:** `--rm` deletes the container, NOT the volume. Volume data outlives the container.

---

### Step 5: Verify Data Persistence Across Containers

```bash
docker run -it --rm -v testvolume01:/home/app2 ubuntu
```

**Inside the container:**
```bash
root@1f7adc478e4e:/# cd home/app2/
root@1f7adc478e4e:/home/app2# ls
sapid.txt
root@1f7adc478e4e:/home/app2# cat sapid.txt
my sap id: 500124385
root@1f7adc478e4e:/home/app2# echo testsdata > dummy.txt
root@1f7adc478e4e:/home/app2# ls
dummy.txt  sapid.txt
root@1f7adc478e4e:/home/app2# exit
```

**Explanation:**  
This is a **completely new, different container** (note the different hostname `1f7adc478e4e` vs `2db51a71a801`), but the **same volume** `testvolume01` is mounted — this time at `/home/app2` instead of `/home/app`. The mount point name on the container side can be anything.

Results:
- `sapid.txt` from the previous container is **still there** — proving data persistence
- A new file `dummy.txt` was added — it will persist for the next container too
- This also demonstrates **data sharing between containers** via volumes

---

### Mount Volume as Read-Only (with -v flag)

```bash
docker run -it --rm -v testvolume01:/home/app:ro ubuntu
```

**Inside the container:**
```bash
root@4eb7a6c53ff4:/# cd home/app/
root@4eb7a6c53ff4:/home/app# ls
dummy.txt  sapid.txt
root@4eb7a6c53ff4:/home/app# cat dummy.txt
testsdata
root@4eb7a6c53ff4:/home/app# exit
```

**Explanation:**  
The `:ro` suffix added to the `-v` flag makes the volume **read-only** inside this container. Both files from the previous steps (`dummy.txt` and `sapid.txt`) are visible and readable, but the container cannot write or modify anything in `/home/app`.

**Syntax breakdown:**
```
-v  testvolume01  :  /home/app  :  ro
     volume name     mount path    read-only
```

**Use case:** Mount a shared config or secrets volume as read-only for app containers so they can read but never accidentally overwrite shared data.

---

### Mount Volume with --mount Syntax (Read-Only)

```bash
docker run -it --rm --mount type=volume,source=testvolume01,target=/home/app:ro ubuntu
```

**Inside the container:**
```bash
root@0afaebca1855:/# cd home/app:ro/
root@0afaebca1855:/home/app:ro# cd /home/app
bash: cd: /home/app: No such file or directory
root@0afaebca1855:/home/app:ro# ls
dummy.txt  sapid.txt
root@0afaebca1855:/home/app:ro# exit
```

**Explanation:**  
The `--mount` flag is a more explicit, verbose alternative to `-v`. However, the `:ro` suffix was **incorrectly placed inside the `target=` value**, causing Docker to mount the volume at the literal path `/home/app:ro` instead of `/home/app` with read-only mode.

**Wrong:**
```bash
--mount type=volume,source=testvolume01,target=/home/app:ro
```

**Correct syntax for read-only with --mount:**
```bash
--mount type=volume,source=testvolume01,target=/home/app,readonly
```

| Syntax Style | Read-Only Flag |
|---|---|
| `-v` flag | `-v volume:/path:ro` |
| `--mount` flag | `--mount ...,readonly` |

---

### Step 8: Bind Mount — Read-Only Directory

```bash
docker run -it --rm -v ./testdir2:/home/app:ro ubuntu
```

**Inside the container:**
```bash
root@dea7729260c1:/# cd /home/app/
root@dea7729260c1:/home/app# echo test > test
bash: test: Read-only file system
root@dea7729260c1:/home/app# exit
```

**Explanation:**  
This is a **bind mount** — it maps a directory from the host (`./testdir2`) directly into the container at `/home/app`. The `:ro` flag makes it read-only, so any write attempt fails with `Read-only file system`.

**Volume vs Bind Mount:**
```
Named Volume:  -v testvolume01:/home/app        ← Docker manages storage location
Bind Mount:    -v ./testdir2:/home/app           ← You control the host path
```

**Note:** `./testdir2` is a relative path. Docker resolves it relative to the current working directory on the host.

---

### tmpfs Mount

```bash
docker run -it --rm --mount type=tmpfs,target=/home/app ubuntu
```

**Inside the container:**
```bash
root@51772b4cd608:/# exit
```

**Explanation:**  
A `tmpfs` mount stores data **in the host's RAM**, not on disk. The data is available only while the container is running — once the container stops, all tmpfs data is gone permanently, with no trace on disk.

**When to use tmpfs:**
- Storing secrets or tokens that should never touch disk
- High-performance temporary file operations
- Scratch space for in-memory processing

**tmpfs is not for persistence** — it is the opposite of a volume. Use it specifically when you want data to disappear.

---

### Errors & Fixes Encountered

### Bind Mount Source Path Does Not Exist

```bash
docker run -it --rm --mount type=bind,source=./testdir22,target=/home/app ubuntu
```

**Error Output:**
```
docker: Error response from daemon: invalid mount config for type "bind":
bind source path does not exist: /mnt/d/ccvt/sem 6/devops/testdir22
```

**Cause:** Unlike named volumes (which Docker creates automatically), **bind mounts require the host directory to already exist**. `testdir22` had not been created.

**Fix:** Create the directory first, then run:
```bash
mkdir testdir22
docker run -it --rm --mount type=bind,source=$(pwd)/testdir22,target=/home/app ubuntu
```

---

###  `$(pwd)` Expansion Breaks --mount Parsing (Path with Spaces)

```bash
docker run -it --rm --mount type=bind,source=$(pwd)/testdir22,target=/home/app ubuntu
```

**Error Output:**
```
invalid argument "type=bind,source=/mnt/d/ccvt/sem" for "--mount" flag: target is required
```

**Cause:** The working directory path contains a **space** (`sem 6/devops`). When `$(pwd)` expands, the shell splits on the space — `--mount` receives `type=bind,source=/mnt/d/ccvt/sem` as one argument and `6/devops/testdir22,target=/home/app` as another, breaking the parsing.

**Fix:** Quote the entire `--mount` value:
```bash
docker run -it --rm --mount "type=bind,source=$(pwd)/testdir22,target=/home/app" ubuntu
```

---

## 5. Key Observations 

| Observation | What It Proves |
|---|---|
| `sapid.txt` survived after container with `--rm` exited | Volumes persist independently of container lifecycle |
| Second container found `sapid.txt` without any special steps | Same volume can be shared across multiple containers |
| `:ro` prevented `echo test > test` from writing | Read-only mounts are enforced at the OS level |
| Bind mount failed because `testdir22` didn't exist | Docker doesn't auto-create bind mount source directories |
| `$(pwd)` broke with spaces in path | Paths with spaces must be quoted in shell commands |
| `tempfs` caused "mount type unknown" | Docker type names are case-sensitive and exact |
| `--mount target=/home/app:ro` created a literal `:ro` path | `:ro` is `-v` syntax only; `--mount` uses `readonly` keyword |

---

## 6. Volume vs Bind Mount vs tmpfs — Comparison

| Feature | Named Volume | Bind Mount | tmpfs |
|---|---|---|---|
| **Storage location** | Docker-managed (`/var/lib/docker/volumes/`) | Any host path you specify | Host RAM only |
| **Created automatically** | Yes | No (must exist first) | Yes (in memory) |
| **Persists after container stops** | Yes | Yes | No |
| **Shareable between containers** | Yes | Yes | No |
| **Works on all platforms** | Yes | Path issues on Windows/WSL | Yes (Linux only) |
| **Best for** | Production data, databases | Dev source code, configs | Secrets, sensitive temp data |
| **Mount syntax** | `-v volname:/path` | `-v ./hostpath:/path` | `--mount type=tmpfs,target=/path` |

---

### Quick Reference Cheatsheet

### Mounting in docker run

| Syntax | Description |
|---|---|
| `-v myvolume:/container/path` | Mount named volume (read-write) |
| `-v myvolume:/container/path:ro` | Mount named volume (read-only) |
| `-v ./hostdir:/container/path` | Bind mount host directory |
| `-v ./hostdir:/container/path:ro` | Bind mount read-only |
| `--mount type=volume,source=myvol,target=/path` | Named volume (--mount style) |
| `--mount type=volume,source=myvol,target=/path,readonly` | Named volume read-only |
| `--mount type=bind,source=/host/path,target=/path` | Bind mount (--mount style) |
| `--mount type=tmpfs,target=/path` | tmpfs in-memory mount |

### -v vs --mount

| Scenario | Recommended Syntax |
|---|---|
| Quick single mount | `-v` (shorter) |
| Production / scripts | `--mount` (explicit, less error-prone) |
| Read-only volume | `-v vol:/path:ro` OR `--mount ...,readonly` |
| Path with spaces | `--mount "type=bind,source=$(pwd)/my dir,target=/app"` |

---
### WSL Command
```
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker volume
Usage:  docker volume COMMAND

Manage volumes

Commands:
  create      Create a volume
  inspect     Display detailed information on one or more volumes
  ls          List volumes
  prune       Remove unused local volumes
  rm          Remove one or more volumes

Run 'docker volume COMMAND --help' for more information on a command.
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker voulme create testcolume01
docker: unknown command: docker voulme

Run 'docker --help' for more information
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker volume create testcolume01
testcolume01
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker volume ls
DRIVER    VOLUME NAME
local     testcolume01
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker run -it --rm -v testvolume01:/home/app ubuntu
root@2db51a71a801:/# cd /home/app
root@2db51a71a801:/home/app# echo "my sap id: 500124385" > sapid.txt
root@2db51a71a801:/home/app# cat sapid.txt
my sap id: 500124385
root@2db51a71a801:/home/app# exit
exit
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker ps -a
CONTAINER ID   IMAGE                     COMMAND                  CREATED       STATUS                     PORTS                                         NAMES
b973c8400a01   nginx                     "/docker-entrypoint.…"   3 days ago    Exited (0) 3 days ago                                                    cranky_wilbur
072d0a0360ed   sapid-checker:500124385   "python app.py"          5 days ago    Exited (0) 5 days ago                                                    amazing_shamir
c907b5626bda   sapid-checker:500124385   "python app.py"          5 days ago    Exited (1) 5 days ago                                                    eloquent_fermi
9dda3b3dd60b   sapid-checker:500124385   "python app.py"          5 days ago    Exited (0) 5 days ago                                                    wonderful_blackwell
c9d26a2f2d20   hello-c-app               "/hello"                 5 days ago    Exited (0) 5 days ago                                                    intelligent_rubin
acc3227fbfb0   my-flask-app:v1           "python /app/app.py"     6 days ago    Exited (255) 5 days ago    0.0.0.0:5000->5000/tcp, [::]:5000->5000/tcp   my-flask
3dc6fee2455d   b3/java-app:3.0           "bash"                   2 weeks ago   Exited (0) 2 weeks ago                                                   compassionate_bohr
b65389cf84cb   myrepo/java-app:1.0       "bash"                   2 weeks ago   Exited (127) 2 weeks ago                                                 reverent_swartz
b5334b76c24b   ubuntu:22.04              "bash"                   2 weeks ago   Exited (0) 2 weeks ago                                                   java_lab
0ded4732b3fb   c881927c4077              "/docker-entrypoint.…"   3 weeks ago   Exited (0) 3 weeks ago                                                   festive_hopper
81870169556e   ubuntu                    "/bin/bash"              3 weeks ago   Exited (0) 3 weeks ago                                                   dockerclass
26101d4f3ed4   ubuntu                    "/bin/bash"              3 weeks ago   Exited (0) 3 weeks ago                                                   eager_sutherland
e30f8bb4bdfe   ubuntu                    "/bin/bash"              3 weeks ago   Exited (0) 3 weeks ago                                                   eloquent_blackwell
9e0dba4e3626   c881927c4077              "/docker-entrypoint.…"   3 weeks ago   Exited (0) 3 weeks ago                                                   nginx-container
c7595ae5f6b2   c881927c4077              "/docker-entrypoint.…"   3 weeks ago   Exited (0) 3 weeks ago                                                   sharp_brahmagupta
f7a439271847   c881927c4077              "/docker-entrypoint.…"   3 weeks ago   Exited (0) 3 weeks ago                                                   kind_yalow
0cadda32442f   hello-world               "/hello"                 3 weeks ago   Exited (0) 3 weeks ago                                                   dazzling_lehmann
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker run -it --rm -v testvolume01:/home/app2 ubuntu
root@1f7adc478e4e:/# cd home/
root@1f7adc478e4e:/home# cd app2/
root@1f7adc478e4e:/home/app2# ls
sapid.txt
root@1f7adc478e4e:/home/app2# cat sapid.txt
my sap id: 500124385
root@1f7adc478e4e:/home/app2# echo testsdata > dummy.txt
root@1f7adc478e4e:/home/app2# ls
dummy.txt  sapid.txt
root@1f7adc478e4e:/home/app2# exit
exit
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker run -it --rm -v testvolume01:/home/app:ro ubuntu
root@4eb7a6c53ff4:/# cd home/app/
root@4eb7a6c53ff4:/home/app# ls
dummy.txt  sapid.txt
root@4eb7a6c53ff4:/home/app# cat dummy.txt
testsdata
root@4eb7a6c53ff4:/home/app# exit
exit
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker run -it --rm --mount type=volume,source=testvolume01,target=/home/app:ro ubuntu
root@0afaebca1855:/# cd home/app\:ro/
root@0afaebca1855:/home/app:ro# cd /home/app
bash: cd: /home/app: No such file or directory
root@0afaebca1855:/home/app:ro# ls
dummy.txt  sapid.txt
root@0afaebca1855:/home/app:ro# exit
exit
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ ls
container.tar  flask-docker-project  flask-lab  image.tar  java-app.tar  sapid-test
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ mkdir testdir
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ cd testdir/
aniket@Aniket:/mnt/d/ccvt/sem 6/devops/testdir$ cd ..
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker run -it --rm -v ./testdir2:/home/app:ro ubuntu
root@dea7729260c1:/# cd /home/app/
root@dea7729260c1:/home/app# echo test > test
bash: test: Read-only file system
root@dea7729260c1:/home/app# exit
exit
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker run -it --rm -mount type=bind,source=./testdir22,target=/home/app ubuntu
invalid argument "ount" for "-m, --memory" flag: invalid size: 'ount'

Usage:  docker run [OPTIONS] IMAGE [COMMAND] [ARG...]

Run 'docker run --help' for more information
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker run -it --rm --mount type=bind,source=./testdir22,target=/home/app ubuntu
docker: Error response from daemon: invalid mount config for type "bind": bind source path does not exist: /mnt/d/ccvt/sem 6/devops/testdir22

Run 'docker run --help' for more information
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker run -it --rm --mount type=bind,source=$(pwd)/testdir22,target=/home/app ubuntu
invalid argument "type=bind,source=/mnt/d/ccvt/sem" for "--mount" flag: target is required

Usage:  docker run [OPTIONS] IMAGE [COMMAND] [ARG...]

Run 'docker run --help' for more information
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker run -it --rm --mount type=tempfs,target=/home/app ubuntu
docker: Error response from daemon: invalid mount config for type "tempfs": mount type unknown

Run 'docker run --help' for more information
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$ docker run -it --rm --mount type=tmpfs,target=/home/app ubuntu
root@51772b4cd608:/# exit
exit
aniket@Aniket:/mnt/d/ccvt/sem 6/devops$
```