# Spark UI Proxying

Instructions for proxying data engine UIs when deployed on two cnodes.

The proxy rewrites links from the spark UI so that they can be accessed using hostnames set on the client machine.

The proxy needs to have network access to the spark cluster.

```
             +----------------------------------+
             |          Client Machine          |
             |----------------------------------|
             |     /etc/hosts configuration     |
             |  - spark.master  -> 10.143.15.111|
             |  - spark.worker1 -> 10.143.15.111|
             |  - spark.worker2 -> 10.143.15.111|
             +----------------------------------+
                               |
                               |
                          HTTP Requests
                               |
                               v
                     +-------------------+
                     |    Nginx Proxy    |
                     |-------------------|
                     | IP: 10.143.15.111 |
                     |  - nginx.conf     |
                     |  - Maps Spark UI  |
                     +-------------------+
                               |
               +---------------+-------------------+
               |                                   |
               v                                   v
   +-------------------------+           +------------------------+
   |   Spark Master Node     |           |   Spark Worker Nodes   |
   |---------=---------------|           |------------------------|
   | IP:                     |           | IPs:                   |
   |  - 172.200.202.20:9292  |           |  - 172.200.202.21:9293 |
   |  - 172.200.202.20:18080 |           |  - 172.200.202.21:9293 |
   +-------------------------+           +------------------------+            
```



## docker-compose.yml

```
services:
  nginx:
    image: nginx:stable
    container_name: nginx_proxy
    ports:
      - "80:80"
      - "18080:18080"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    networks:
      - spark_network
networks:
  spark_network:
    driver: bridge
```

## nginx.conf

Will need to be modified to work on another cluster.

```
events {
    worker_connections 1024;
}

http {
    # Master node variables
    map $host $master_ip { default "172.200.202.20"; }
    map $host $master_port { default "9292"; }
    map $host $master_host { default "spark.master"; }

    # Worker 1 variables
    map $host $worker1_ip { default "172.200.202.21"; }
    map $host $worker1_port { default "9293"; }
    map $host $worker1_host { default "spark.worker1"; }
    map $host $worker1_old_name { default "cosmo-arrow-cb2-cn-1"; }

    # Worker 2 variables
    map $host $worker2_ip { default "172.200.202.22"; }
    map $host $worker2_port { default "9293"; }
    map $host $worker2_host { default "spark.worker2"; }
    map $host $worker2_old_name { default "cosmo-arrow-cb2-cn-2"; }

    map $host $worker_prefix { default "worker-20250115194059-"; }

    upstream spark_nodes {
        server 172.200.202.20:9292; # Master
        server 172.200.202.21:9293; # Worker 1
        server 172.200.202.22:9293; # Worker 2
    }

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server {
        listen 80;
        server_name spark.master;

        location / {
            proxy_pass http://$master_ip:$master_port;
            proxy_set_header Host $host;
            proxy_set_header Accept-Encoding "";

            sub_filter_types text/html text/css text/xml text/javascript application/javascript;
            sub_filter_once off;

            # URLs
            sub_filter "http://$master_ip:$master_port" "http://$master_host";
            sub_filter "http://$worker1_ip:$worker1_port" "http://$worker1_host";
            sub_filter "http://$worker2_ip:$worker2_port" "http://$worker2_host";

            # Worker IDs
            sub_filter "${worker_prefix}${worker1_ip}-" "${worker_prefix}${worker1_host}-";
            sub_filter "${worker_prefix}${worker2_ip}-" "${worker_prefix}${worker2_host}-";

            # IPs
            sub_filter $master_ip $master_host;
            sub_filter $worker1_ip $worker1_host;
            sub_filter $worker2_ip $worker2_host;

            # Old names
            sub_filter "${worker1_old_name}:${worker1_port}" $worker1_host;
            sub_filter "${worker2_old_name}:${worker2_port}" $worker2_host;
            sub_filter "${worker1_old_name}:${master_port}" $master_host;
            sub_filter "${worker2_old_name}:${master_port}" $master_host;
        }
    }

    server {
        listen 18080;
        server_name spark.master;

        location / {
            proxy_pass http://$master_ip:18080;
            proxy_set_header Host $host;
            proxy_set_header Accept-Encoding "";

            sub_filter_types text/html text/css text/xml text/javascript application/javascript;
            sub_filter_once off;

            # URLs
            sub_filter "http://$master_ip:$master_port" "http://$master_host";
            sub_filter "http://$worker1_ip:$worker1_port" "http://$worker1_host";
            sub_filter "http://$worker2_ip:$worker2_port" "http://$worker2_host";

            # Worker IDs
            sub_filter "${worker_prefix}${worker1_ip}-" "${worker_prefix}${worker1_host}-";
            sub_filter "${worker_prefix}${worker2_ip}-" "${worker_prefix}${worker2_host}-";

            # IPs
            sub_filter $master_ip $master_host;
            sub_filter $worker1_ip $worker1_host;
            sub_filter $worker2_ip $worker2_host;

            # Old names
            sub_filter "${worker1_old_name}:${worker1_port}" $worker1_host;
            sub_filter "${worker2_old_name}:${worker2_port}" $worker2_host;
            sub_filter "${worker1_old_name}:${master_port}" $master_host;
            sub_filter "${worker2_old_name}:${master_port}" $master_host;
        }
    }

    server {
        listen 80;
        server_name spark.worker1;

        location / {
            proxy_pass http://$worker1_ip:$worker1_port;
            proxy_set_header Host $host;
            proxy_set_header Accept-Encoding "";

            sub_filter_types text/html text/css text/xml text/javascript application/javascript;
            sub_filter_once off;

            # URLs
            sub_filter "http://$master_ip:$master_port" "http://$master_host";
            sub_filter "http://$worker1_ip:$worker1_port" "http://$worker1_host";
            sub_filter "http://$worker2_ip:$worker2_port" "http://$worker2_host";

            # Worker IDs
            sub_filter "${worker_prefix}${worker1_ip}-" "${worker_prefix}${worker1_host}-";
            sub_filter "${worker_prefix}${worker2_ip}-" "${worker_prefix}${worker2_host}-";

            # IPs
            sub_filter $master_ip $master_host;
            sub_filter $worker1_ip $worker1_host;
            sub_filter $worker2_ip $worker2_host;

            # Old names
            sub_filter "${worker1_old_name}:${worker1_port}" $worker1_host;
            sub_filter "${worker2_old_name}:${worker2_port}" $worker2_host;
            sub_filter "${worker1_old_name}:${master_port}" $master_host;
            sub_filter "${worker2_old_name}:${master_port}" $master_host;
        }
    }

    server {
        listen 80;
        server_name spark.worker2;

        location / {
            proxy_pass http://$worker2_ip:$worker2_port;
            proxy_set_header Host $host;
            proxy_set_header Accept-Encoding "";

            sub_filter_types text/html text/css text/xml text/javascript application/javascript;
            sub_filter_once off;

            # URLs
            sub_filter "http://$master_ip:$master_port" "http://$master_host";
            sub_filter "http://$worker1_ip:$worker1_port" "http://$worker1_host";
            sub_filter "http://$worker2_ip:$worker2_port" "http://$worker2_host";

            # Worker IDs
            sub_filter "${worker_prefix}${worker1_ip}-" "${worker_prefix}${worker1_host}-";
            sub_filter "${worker_prefix}${worker2_ip}-" "${worker_prefix}${worker2_host}-";

            # IPs
            sub_filter $master_ip $master_host;
            sub_filter $worker1_ip $worker1_host;
            sub_filter $worker2_ip $worker2_host;

            # Old names
            sub_filter "${worker1_old_name}:${worker1_port}" $worker1_host;
            sub_filter "${worker2_old_name}:${worker2_port}" $worker2_host;
            sub_filter "${worker1_old_name}:${master_port}" $master_host;
            sub_filter "${worker2_old_name}:${master_port}" $master_host;
        }
    }
}
```

## client machine /etc/hosts

```
10.143.15.111 spark.master
10.143.15.111 spark.worker1
10.143.15.111 spark.worker2
```

## Test

```
curl http://spark.master
curl http://spark.master:18080
curl http://spark.worker1
curl http://spark.worker2
```
 
