
# Deploying NGINX Using Different Base Images and Comparing Image Layers

---

## Lab Objectives

After completing this lab, students will be able to:

* Deploy NGINX using:

  * Official `nginx` image
  * Ubuntu-based image
  * Alpine-based image
* Understand Docker image layers and size differences
* Compare performance, security, and use-cases of each approach
* Explain real-world use of NGINX in containerized systems

---

## Prerequisites

* Docker installed and running
* Basic knowledge of:

  * `docker run`
  * `Dockerfile`
  * Port mapping
* Linux command basics

---

## Part 1: Deploy NGINX Using Official Image (Recommended Approach)

### Step 1: Pull the Image

```bash
docker pull nginx:latest
```
![Image 1](img/1.png)

### Step 2: Run the Container

```bash
docker run -d --name nginx-official -p 8080:80 nginx
```

![Image 2](img/2.png)

### Step 3: Verify

```bash
curl http://localhost:8080
```

![Image 3](img/3.png)

You should see the **NGINX welcome page**.

---

### Key Observations

```bash
docker images nginx
```

![Image 4](img/4.png)

* Image is **pre-optimized**
* Minimal configuration required
* Uses Debian-based OS internally

---

## Part 2: Custom NGINX Using Ubuntu Base Image

### Step 1: Create Dockerfile
![Image 6](img/6.png)
```Dockerfile
FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y nginx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```
![Image 7](img/7.png)
### Step 2: Build Image

```bash
docker build -t nginx-ubuntu .
```
![Image 8](img/8.png)

### Step 3: Run Container

```bash
docker run -d --name nginx-ubuntu -p 8081:80 nginx-ubuntu
```
![Image 8](img/9.png)
---

### Observations

```bash
docker images nginx-ubuntu
```

![Image 8](img/10.png)

* Much **larger image size**
* More layers
* Full OS utilities available

---

## Part 3: Custom NGINX Using Alpine Base Image

### Step 1: Create Dockerfile

![Image 8](img/13.png)

```Dockerfile
FROM alpine:latest

RUN apk add --no-cache nginx

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```
![Image 8](img/11.png)
### Step 2: Build Image

```bash
docker build -t nginx-alpine .
```

![Image 8](img/12.png)

### Step 3: Run Container

```bash
docker run -d --name nginx-alpine -p 8082:80 nginx-alpine
```

![Image 9](img/14.png)

---

### Observations

```bash
docker images nginx-alpine
```

![Image 10](img/15.png)

* Extremely **small image**
* Fewer packages
* Faster pull and startup time

---

## Part 4: Image Size and Layer Comparison

### Compare Sizes

```bash
docker images | grep nginx
```

![Image 11](img/16.png)

Typical result (approx):

| Image Type   | Size      |
| ------------ | --------- |
| nginx:latest | ~140 MB   |
| nginx-ubuntu | ~220+ MB  |
| nginx-alpine | ~25–30 MB |

---

Observations:

* Ubuntu has many filesystem layers
* Alpine has minimal layers
* Official NGINX image is optimized but heavier than Alpine

---

## Part 5: Functional Tasks Using NGINX

### Task 1: Serve Custom HTML Page

```bash
mkdir html
echo "<h1>Hello from Docker NGINX</h1>" > html/index.html
```

![Image 13](img/17.png)

Run:

```bash
docker run -d \
  -p 8083:80 \
  -v $(pwd)/html:/usr/share/nginx/html \
  nginx
```

![Image 14](img/18.png)

---
