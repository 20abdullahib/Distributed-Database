CREATE USER 'admin'@'%' IDENTIFIED BY '123456';
GRANT ALL privileges ON *.* TO 'admin'@'%' with grant option;
reset master;