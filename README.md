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

or

```bash
docker exec -it project-node1-1 mysqlsh -uadmin -p123456 --host=127.0.0.1 --port=3306
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
## Fragmentation & Replication Examples

### 🏗️ 1. One-Liner Table Setup (Per Node)

**Node 1 – NY Fragment:**

```bash
docker exec project-node1-1 mysql -uadmin -p123456 -e "CREATE DATABASE IF NOT EXISTS bookstore; USE bookstore; CREATE TABLE IF NOT EXISTS books (book_id INT PRIMARY KEY, title VARCHAR(255), author VARCHAR(255), genre VARCHAR(100), price DECIMAL(5,2)); CREATE TABLE IF NOT EXISTS locations (location_id INT PRIMARY KEY, city VARCHAR(100), address VARCHAR(255)); CREATE TABLE IF NOT EXISTS inventory_ny (inventory_id INT PRIMARY KEY, book_id INT, location_id INT, quantity INT);"
```

**Node 2 – LA Fragment:**

```bash
docker exec project-node2-1 mysql -uadmin -p123456 -e "SET GLOBAL super_read_only = OFF; SET GLOBAL read_only = OFF;CREATE DATABASE IF NOT EXISTS bookstore; USE bookstore; CREATE TABLE IF NOT EXISTS books (book_id INT PRIMARY KEY, title VARCHAR(255), author VARCHAR(255), genre VARCHAR(100), price DECIMAL(5,2)); CREATE TABLE IF NOT EXISTS locations (location_id INT PRIMARY KEY, city VARCHAR(100), address VARCHAR(255)); CREATE TABLE IF NOT EXISTS inventory_la (inventory_id INT PRIMARY KEY, book_id INT, location_id INT, quantity INT);"
```

**Node 3 – Chicago Fragment:**

```bash
docker exec project-node3-1 mysql -uadmin -p123456 -e "SET GLOBAL super_read_only = OFF; SET GLOBAL read_only = OFF;CREATE DATABASE IF NOT EXISTS bookstore; USE bookstore; CREATE TABLE IF NOT EXISTS books (book_id INT PRIMARY KEY, title VARCHAR(255), author VARCHAR(255), genre VARCHAR(100), price DECIMAL(5,2)); CREATE TABLE IF NOT EXISTS locations (location_id INT PRIMARY KEY, city VARCHAR(100), address VARCHAR(255)); CREATE TABLE IF NOT EXISTS inventory_chicago (inventory_id INT PRIMARY KEY, book_id INT, location_id INT, quantity INT);"
```

---

### ✍️ 2. One-Liner Insert into Replicated Tables (Node 1 only)

This data will appear in **all nodes** due to replication setup (assuming replication is configured correctly):

```bash
docker exec project-node1-1 mysql -uadmin -p123456 -e "USE bookstore; INSERT INTO books VALUES (1, '1984', 'George Orwell', 'Dystopian', 9.99), (2, 'Dune', 'Frank Herbert', 'Sci-Fi', 14.99), (3, 'The Hobbit', 'J.R.R. Tolkien', 'Fantasy', 12.99); INSERT INTO locations VALUES (1, 'New York', '123 Manhattan Ave'), (2, 'Los Angeles', '456 Sunset Blvd'), (3, 'Chicago', '789 Lake Shore Dr');"
```

Test visibility on other nodes:

```bash
docker exec project-node2-1 mysql -uadmin -p123456 -e "SELECT * FROM bookstore.books;"
docker exec project-node3-1 mysql -uadmin -p123456 -e "SELECT * FROM bookstore.locations;"
```

---

### 📦 3. One-Liner Insert into Fragmented Inventory Tables

These go only to their local node:

**Node 1:**

```bash
docker exec project-node1-1 mysql -uadmin -p123456 -e "USE bookstore; INSERT INTO inventory_ny VALUES (1, 1, 1, 10), (2, 2, 1, 5);"
```

**Node 2:**

```bash
docker exec project-node2-1 mysql -uadmin -p123456 -e "USE bookstore; INSERT INTO inventory_la VALUES (3, 1, 2, 8), (4, 3, 2, 4);"
```

**Node 3:**

```bash
docker exec project-node3-1 mysql -uadmin -p123456 -e "USE bookstore; INSERT INTO inventory_chicago VALUES (5, 2, 3, 6), (6, 3, 3, 2);"
```

---

### 🧪 4. Test: Querying Fragmented Data

#### Objective

You want 3 one-liner CMD commands to:

1. Show inventory data from Node 1 (`inventory_ny`)
2. Show inventory data from Node 2 (`inventory_la`)
3. Show inventory data from Node 3 (`inventory_chicago`)

#### One-Liner CMD Commands to Show Fragmentation

**Node 1: Show NY Inventory**

```bash
docker exec project-node1-1 mysql -uadmin -p123456 -e "USE bookstore; SELECT * FROM inventory_ny;"
```

**Node 2: Show LA Inventory**

```bash
docker exec project-node2-1 mysql -uadmin -p123456 -e "USE bookstore; SELECT * FROM inventory_la;"
```

**Node 3: Show Chicago Inventory**

```bash
docker exec project-node3-1 mysql -uadmin -p123456 -e "USE bookstore; SELECT * FROM inventory_chicago;"
```

#### Expected Output Example

**Node 1 Output:**
```
+---------------+---------+--------------+----------+
| inventory_id  | book_id | location_id  | quantity |
+---------------+---------+--------------+----------+
| 1             | 1       | 1            | 10       |
| 2             | 2       | 1            | 5        |
+---------------+---------+--------------+----------+
```

**Node 2 Output:**
```
+---------------+---------+--------------+----------+
| inventory_id  | book_id | location_id  | quantity |
+---------------+---------+--------------+----------+
| 3             | 1       | 2            | 8        |
| 4             | 3       | 2            | 4        |
+---------------+---------+--------------+----------+
```

**Node 3 Output:**
```
+---------------+---------+--------------+----------+
| inventory_id  | book_id | location_id  | quantity |
+---------------+---------+--------------+----------+
| 5             | 2       | 3            | 6        |
| 6             | 3       | 3            | 2        |
+---------------+---------+--------------+----------+
```

Each node should **only show its own inventory** and have **no access** to other nodes’ inventory fragments — this proves fragmentation is working.

---

### 🧪 5. Test: Distributed Query

#### Goal

You want to verify that:

* Inventory data is **fragmented** across nodes.
* You can **query them all together** by **manually uniting** them (simulating a distributed query).

#### One-Liner Distributed Query on Node 1

Run this on **Node 1**, assuming each inventory fragment is named correctly and exists locally (e.g., via replication or federated setup):

```bash
docker exec project-node1-1 mysql -uadmin -p123456 -e "USE bookstore; SELECT b.title, t.location_id, t.quantity FROM books b JOIN (SELECT book_id, location_id, quantity FROM inventory_ny UNION ALL SELECT book_id, location_id, quantity FROM inventory_la UNION ALL SELECT book_id, location_id, quantity FROM inventory_chicago) AS t ON b.book_id = t.book_id WHERE t.quantity > 0;"
```

#### Expected Output (Based on Previous Inserts)

```
+-------------+--------------+----------+
| title       | location_id  | quantity |
+-------------+--------------+----------+
| 1984        | 1            | 10       |
| Dune        | 1            | 5        |
| 1984        | 2            | 8        |
| The Hobbit  | 2            | 4        |
| Dune        | 3            | 6        |
| The Hobbit  | 3            | 2        |
+-------------+--------------+----------+
```

This proves:

* **Data exists only on its assigned node**.
* When you union all inventory fragments, you **reconstruct the full dataset**.

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


docker exec project-node3-1 mysql -uadmin -p123456 -e "SHOW TABLES FROM bookstore;"

docker exec project-node2-1 mysql -uadmin -p123456 -e "USE bookstore; DROP TABLE IF EXISTS inventory_ny; DROP TABLE IF EXISTS inventory_chicago; "

docker exec project-node3-1 mysql -uadmin -p123456 -e "SET GLOBAL super_read_only = 0; SET GLOBAL read_only = 0; CREATE DATABASE IF NOT EXISTS bookstore; USE bookstore; CREATE TABLE IF NOT EXISTS books (book_id INT PRIMARY KEY, title VARCHAR(255), author VARCHAR(255), genre VARCHAR(100), price DECIMAL(5,2)); CREATE TABLE IF NOT EXISTS locations (location_id INT PRIMARY KEY, city VARCHAR(100), address VARCHAR(255)); CREATE TABLE IF NOT EXISTS inventory_chicago (inventory_id INT PRIMARY KEY, book_id INT, location_id INT, quantity INT);"

