# Docker_WebApp

Containerized Student Records REST API built with Node.js and PostgreSQL using Docker Compose, Macvlan networking, and persistent Docker volumes.

---

## 1. Introduction

This project implements a containerized **Student Records Web Application** using:

* Node.js + Express (Backend)
* PostgreSQL (Database)
* Docker multi-stage builds
* Docker Compose
* Macvlan networking
* Named volumes for persistence

---

## 2. System Architecture

```
Client (Browser / Postman)
        |
        v
+-------------------------------+
| Backend Container             |
| Node.js + Express             |
| IP: 172.21.0.100              |
+-------------------------------+
        |
        v
+-------------------------------+
| Database Container            |
| PostgreSQL                    |
| IP: 172.21.0.101              |
+-------------------------------+
        |
        v
Docker Volume (student_pgdata)
```

---

## 3. API Endpoints

| Endpoint  | Method | Description   |
| --------- | ------ | ------------- |
| /health   | GET    | Health check  |
| /students | POST   | Insert record |
| /students | GET    | Fetch records |

---

## Example Student Record

```json
{
  "name": "Siddharth",
  "roll_number": "CS01",
  "department": "CSE",
  "year": 3
}
```

---

## 4. Networking (Macvlan)

```bash
docker network create \
--driver macvlan \
--subnet=172.21.0.0/16 \
--gateway=172.21.0.1 \
-o parent=eth0 \
student_macvlan
```

---

## 5. Testing

### Health Check

```bash
docker exec -it studentapi sh
wget -qO- http://localhost:3000/health
```

Output:

```json
{"status":"ok"}
```

---

### Insert Record

```bash
wget -qO- \
--header="Content-Type: application/json" \
--post-data='{"name":"Siddharth","roll_number":"CS01","department":"CSE","year":3}' \
http://localhost:3000/students
```

---

### Get Records

```bash
wget -qO- http://localhost:3000/students
```

---

## 6. Persistence Test

```bash
docker compose down
docker compose up -d
```

Data remains stored due to Docker volume.

---

## 7. Important Note

Due to **macvlan host isolation**, API is tested inside the container using `wget`.

---

## 8. Conclusion

* Containerized Node.js + PostgreSQL app
* Static IP using macvlan
* Persistent storage using volumes
* Fully working REST API

---
