# Distributed-Database

This guide explains how to set up a MySQL InnoDB Cluster using Docker containers. The cluster will consist of three MySQL 8.0 instances working together to provide high availability.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Setup Process](#setup-process)
  - [1. Create the Docker Files](#1-create-the-docker-files)
  - [2. Build and Launch the Containers](#2-build-and-launch-the-containers)
  - [3. Verify Container Status](#3-verify-container-status)
  - [4. Configure MySQL Instances](#4-configure-mysql-instances)
  - [5. Create the InnoDB Cluster](#5-create-the-innodb-cluster)
  - [6. Add Instances to the Cluster](#6-add-instances-to-the-cluster)
  - [7. Verify Cluster Status](#7-verify-cluster-status)
  - [8. Connect to Your Cluster](#8-connect-to-your-cluster)
- [Troubleshooting](#troubleshooting)
- [Additional Resources](#additional-resources)

---

## Prerequisites

- Docker and Docker Compose installed
- Basic knowledge of Docker and MySQL
- At least 4GB of RAM available for the containers

---

## Project Structure

You'll need these three files in your project directory:

### Dockerfile

```dockerfile
FROM mysql/mysql-server:8.0
COPY ./setup.sql /docker-entrypoint-initdb.d
EXPOSE 3306
```

This Dockerfile:
- Uses the official MySQL 8.0 server image.
- Copies our setup.sql file to be executed on container initialization.
- Exposes port `3306` for MySQL connections.

---

### setup.sql

```sql
CREATE USER 'admin'@'%' IDENTIFIED BY '123456';
GRANT ALL privileges ON *.* TO 'admin'@'%' with grant option;
reset master;
```

This SQL script:
- Creates an admin user with access from any host (`%`).
- Grants all privileges to this user.
- Resets binary log state for clean cluster initialization.

---

### docker-compose.yml

```yaml
version: "3.3"
services:
  node1:
    build: .
    command: --default-authentication-plugin=mysql_native_password
    environment:
      MYSQL_ROOT_PASSWORD: password
    ports:
      - "3308:3306"
    volumes:
      - db-data1:/var/lib/mysql

  node2:
    build: .
    command: --default-authentication-plugin=mysql_native_password
    environment:
      MYSQL_ROOT_PASSWORD: password
    ports:
      - "3309:3306"
    volumes:
      - db-data2:/var/lib/mysql

  node3:
    build: .
    command: --default-authentication-plugin=mysql_native_password
    environment:
      MYSQL_ROOT_PASSWORD: password
    ports:
      - "3310:3306"
    volumes:
      - db-data3:/var/lib/mysql

volumes:
  db-data1: {}
  db-data2: {}
  db-data3: {}
```

This docker-compose file:
- Defines three MySQL nodes (`node1`, `node2`, `node3`).
- Maps to different host ports (`3308`, `3309`, `3310`).
- Uses persistent volumes for data storage.
- Sets the root password and authentication method.

---

## Setup Process

### 1. Create the Docker Files

Create the three files (`Dockerfile`, `setup.sql`, and `docker-compose.yml`) in your project directory.

---

### 2. Build and Launch the Containers

Open a terminal in your project directory and run:

```bash
docker-compose build
```

This builds the custom MySQL images with our `setup.sql` file included.

Next, launch the containers:

```bash
docker-compose up -d
```

The `-d` flag runs the containers in detached mode (background).

---

### 3. Verify Container Status

Check that all three MySQL containers are running:

```bash
docker ps
```

Expected output: You should see three containers running with status "Up".

---

### 4. Configure MySQL Instances

Before creating a cluster, we need to check and configure each instance.

connect to MySQL Shell with the admin user:

```bash
docker exec -it project-node1-1 mysqlsh -uadmin -p123456
```

Verify the admin user was created:

```sql
SELECT user, host FROM mysql.user;
```

Now we need to check and configure each instance for the cluster. Run this for each node:

Node 1:
```javascript
dba.checkInstanceConfiguration("admin@project-node1-1:3306")
```

If configuration changes are needed, run:
```javascript
dba.configureInstance("admin@project-node1-1:3306")
```

Repeat this process for nodes 2 and 3:

```javascript
dba.checkInstanceConfiguration("admin@project-node2-1:3306")
dba.configureInstance("admin@project-node2-1:3306")

dba.checkInstanceConfiguration("admin@project-node3-1:3306")
dba.configureInstance("admin@project-node3-1:3306")
```

---

### 5. Create the InnoDB Cluster

After configuring all instances, create the cluster using node1 as the primary:

```javascript
var cluster = dba.createCluster("bookstoreCluster")
```

Expected output: Confirmation message that the cluster was created.

---

### 6. Add Instances to the Cluster

Add the remaining nodes to the cluster:

```javascript
cluster.addInstance("admin@project-node2-1:3306")
cluster.addInstance("admin@project-node3-1:3306")
```

Expected output: Each node will be added to the cluster after validating compatibility.

---

### 7. Verify Cluster Status

Check the status of your cluster:

```javascript
cluster.status()
```

Expected output: A JSON structure showing all three nodes, with `node1` as `PRIMARY` and the others as `SECONDARY`.

You can also get information about all clusters:

```javascript
dba.getClusterSet()
```

---

### 8. Connect to Your Cluster

You can now connect to the primary node (`node1`) using MySQL Workbench or any other client and create your database schemas and tables. All changes will be replicated to the secondary nodes automatically.

Connect using:
- Hostname: `localhost`
- Port: `3308` (mapped to node1)
- Username: `admin`
- Password: `123456`

---

## Troubleshooting

### Common Issues

1. **Cannot connect to MySQL**: Ensure the containers are running with `docker ps` and that you're using the correct port mappings.

2. **Cluster creation fails**: Check that all instances are properly configured using `dba.checkInstanceConfiguration()` and `dba.configureInstance()`.

3. **Replication issues**: Run `cluster.status()` to see if any nodes are showing errors or warnings.

4. **Container name mismatch**: If your container names differ from the examples, adjust the commands accordingly. Find your container names with `docker ps`.

---

## Additional Resources

- [MySQL InnoDB Cluster Documentation](https://dev.mysql.com/doc/refman/8.0/en/mysql-innodb-cluster-introduction.html)
- [MySQL Shell User Guide](https://dev.mysql.com/doc/mysql-shell/8.0/en/)
- [Docker Documentation](https://docs.docker.com/)

---

This setup creates a three-node MySQL InnoDB Cluster that provides high availability for your database applications. The primary node (`node1`) accepts write operations while all nodes can handle read operations, and automatic failover ensures your application remains available if a node fails.


docker exec project3-node3-1 mysql -uadmin -p123456 -e "SHOW TABLES FROM bookstore;"

docker exec project3-node2-1 mysql -uadmin -p123456 -e "USE bookstore; DROP TABLE IF EXISTS inventory_ny; DROP TABLE IF EXISTS inventory_chicago; "

docker exec project-node3-1 mysql -uadmin -p123456 -e "SET GLOBAL super_read_only = 0; SET GLOBAL read_only = 0; CREATE DATABASE IF NOT EXISTS bookstore; USE bookstore; CREATE TABLE IF NOT EXISTS books (book_id INT PRIMARY KEY, title VARCHAR(255), author VARCHAR(255), genre VARCHAR(100), price DECIMAL(5,2)); CREATE TABLE IF NOT EXISTS locations (location_id INT PRIMARY KEY, city VARCHAR(100), address VARCHAR(255)); CREATE TABLE IF NOT EXISTS inventory_chicago (inventory_id INT PRIMARY KEY, book_id INT, location_id INT, quantity INT);"

