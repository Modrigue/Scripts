# SSH Tunnel Utilities

# create a simple SSH tunnel:
ssh -L 50000:192.168.201.12:22 10.0.30.4
ssh root@127.0.0.1 -p 50000

# create an SSH tunnel and dump a remote database:
ssh -f -L3310:localhost:3306 user@remote.server -N
mysqldump -P 3310 -h 127.0.0.1 -u mysql_user -p database_name table_name

# close the process that opened port 3310 for the SSH tunnel:
lsof -ti:3310 | xargs kill -9