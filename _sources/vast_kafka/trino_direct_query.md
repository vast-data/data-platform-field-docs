# Kafka to VastDB with Trino Lookup

Download Kafka to your client

```bash
wget https://archive.apache.org/dist/kafka/2.8.0/kafka_2.12-2.8.0.tgz
tar -xzf kafka_2.12-2.8.0.tgz
cd kafka_2.12-2.8.0/bin
```

From one shell prompt create a Topic and start a producer . This producer will stream all system messages into the topic. Please note this will hang the terminal unless you background it and the IP are the Vast VIP Ip’s with the kafka view associated with that view

```bash
./kafka-topics.sh --create --topic leon --bootstrap-server 172.200.202.9:9092  --partitions 1
journalctl -n all -f | ./kafka-console-producer.sh --topic leon --bootstrap-server 172.200.202.9:9092,172.200.202.10:9092,172.200.202.11:9092,172.200.202.12:9092
```

Open a new shell to your client

Create a file called vast.properties with the following properties. please note you will need to change the data_endpoints endpoint access_key_id secret_access_key to values on your cluster. The user with the access/secret key must be an identity policy that has query access to the vast system

```bash
## Update these fields ##
# "endpoint" should be a load-balanced DNS entry or one of the VIPs prefixed by "http://"
# it should not contain a trailing / or anything else.
endpoint=http://172.200.202.9
 
# "data_endpoints" should be be a load-balanced DNS entry or one or more of the VIPs
# prefixed by "http://" it should not contain a trailing / or anything else.
# Multiple VIPs can be used with commas between them, eg: http://x.x.x.x,http://y.y.y.y
data_endpoints=http://172.200.202.9
 
# Access and secret keys -- make sure the user was added to an identity policy
# granting them access to the catalog.
access_key_id=220IKZ22SDDQ4C341Z4R
secret_access_key=80lcqf6IxeqSUuNfNwuSpIbveetwslaHrhNoU56A
 
## Don't change these fields ##
connector.name=vast
region=us-east-1
 
num_of_splits=32
num_of_subsplits=8
 
vast.http-client.request-timeout=60m
vast.http-client.idle-timeout=60m
 
enable_custom_schema_separator=true
custom_schema_separator=|
```

Start up trino in docker . this version is for vast 5.1 and above

```bash
docker run \
	--name trino \
	-p 8080:8080 -d \
	-v ./vast.properties:/etc/trino/catalog/vast.properties:ro \
	--platform linux/amd64 \
	vastdataorg/trino-vast:429
```

Jump into the trino instance.

```bash
docker exec -it trino trino
```

List the schemas. is you cant see the kafka broker and other tables you have done something wrong with identity policies or the list bucket option in the view policies. If in doubt ask a friend.

```sql
 SHOW SCHEMAS FROM vast;
 ```

 Outputs:

 ```bash
                 	Schema
-------------------------------------------------
csnow-db|vts
information_schema
insight-engine-database|langchain
kafka-broker|kafka_topics
leon|leon
system_schema
vast-audit-log-bucket|vast_audit_log_schema
vast-big-catalog-bucket|vast_big_catalog_schema
(8 rows)
```

show the first message in the leon topic. its a blob object and encoded. i.e. doesnt mean anything

```bash
trino> select * from vast."kafka-broker|kafka_topics".leon limit 1;
```

Outputs:

```bash
key  |                  	value                  	|	timestamp_broker 	|   timestamp_producer	| headers
------+-------------------------------------------------+-------------------------+-------------------------+---------
NULL | 2d 2d 20 4c 6f 67 73 20 62 65 67 69 6e 20 61 74 | 2025-03-21 08:11:11.352 | 2025-03-21 08:11:11.307 | []
  	| 20 53 61 74 20 32 30 32 35 2d 30 31 2d 32 35 20 |                     	|                     	|
  	| 30 34 3a 34 39 3a 33 34 20 55 54 43 2e 20 2d 2d |                     	|                     	|
(1 row)
```

Decode this message so we can read it. (as long as the message is text)

```bash
trino> select from_utf8(value) AS decoded_json from vast."kafka-broker|kafka_topics".leon limit 5;
```

Outputs:


```bash                                                                                                                                          	decoded_json       	>
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------->
-- Logs begin at Sat 2025-01-25 04:49:34 UTC. --                                                                                                                                  	>
Jan 25 04:49:34 cosmos-var-cb3-c1 kernel: Linux version 4.18.0-348.23.1.el8_5.x86_64 (mockbuild@dal1-prod-builder001.bld.equ.rockylinux.org) (gcc version 8.5.0 20210514 (Red Hat 8.5.>
Jan 25 04:49:34 cosmos-var-cb3-c1 kernel: Command line: BOOT_IMAGE=(hd0,msdos1)/vmlinuz-4.18.0-348.23.1.el8_5.x86_64 root=/dev/mapper/root_vg01-lv_01 ro panic=60 log_buf_len=10M nvme>
Jan 25 04:49:34 cosmos-var-cb3-c1 kernel: x86/split lock detection: disabled                                                                                                      	>
Jan 25 04:49:34 cosmos-var-cb3-c1 kernel: x86/fpu: Supporting XSAVE feature 0x001: 'x87 floating point registers'                                                                 	>
(5 rows)
```

Something more complex. Keyword Frequency Distribution Query. how many warns and errors on the topic.

```sql
 WITH decoded_lines AS (
  SELECT
    line
  FROM
    vast."kafka-broker|kafka_topics".leon,
	UNNEST(regexp_split(from_utf8(value), '\n')) AS t(line)
),
tagged_lines AS (
  SELECT
    CASE
      WHEN regexp_like(line, '(?i)error') THEN 'ERROR'
  	WHEN regexp_like(line, '(?i)warn') THEN 'WARN'
  	WHEN regexp_like(line, '(?i)critical') THEN 'CRITICAL'
  	ELSE 'INFO'
	END AS level
  FROM
    decoded_lines
  WHERE
    regexp_like(line, '(?i)(error|warn|critical)')
)
SELECT
  level,
  COUNT(*) AS occurrences
FROM
  tagged_lines
GROUP BY
  level
ORDER BY
  occurrences DESC;
```
Outputs:

```
 level | occurrences
-------+-------------
WARN  |     	128
ERROR |      	57
(2 rows)
```

Decodes the Kafka blobs.
 Splits each blob into individual lines.
 Searches each line for error, warn, or critical (case-insensitive).
 Extracts the timestamp, keyword hit, and displays the matching line.

```sql
WITH decoded_lines AS (
  SELECT
	timestamp_broker,
	line
  FROM
	vast."kafka-broker|kafka_topics".leon,
	UNNEST(regexp_split(from_utf8(value), '\n')) AS t(line)
),
filtered_lines AS (
  SELECT
	timestamp_broker,
	line,
	CASE
  	WHEN regexp_like(line, '(?i)error') THEN 'ERROR'
  	WHEN regexp_like(line, '(?i)warn') THEN 'WARN'
  	WHEN regexp_like(line, '(?i)critical') THEN 'CRITICAL'
  	ELSE 'INFO'
	END AS level
  FROM
	decoded_lines
  WHERE
	regexp_like(line, '(?i)(error|warn|critical)')
)
SELECT
  timestamp_broker,
  level,
  line AS message
FROM
  filtered_lines
ORDER BY
  timestamp_broker DESC
LIMIT 5;
```

Outputs:

```
	timestamp_broker 	| level |                                                                                                              	                                   >
-------------------------+-------+----------------------------------------------------------------------------------------------------------------------------------------------------->
2025-03-21 08:11:20.564 | ERROR | Mar 13 17:02:36 cosmos-var-cb3-c1 dockerd[2545]: time="2025-03-13T17:02:36.677268080Z" level=error msg="Handler for POST /v1.45/containers/e40125ff6>
2025-03-21 08:11:20.392 | WARN  | Mar 11 10:00:36 cosmos-var-cb3-c1 systemd[1]: run-docker-runtime\x2drunc-moby-9fbc20cd5ae833a8dcff6a8b01064ecad8448102df8c5d2022cdcd927e418e23-runc.>
2025-03-21 08:11:19.822 | ERROR | Mar 05 15:30:33 cosmos-var-cb3-c1 dnf[1850333]:   - Curl error (7): Couldn't connect to server for https://packages.microsoft.com/rhel/8/prod/repoda>
2025-03-21 08:11:19.822 | ERROR | Mar 05 15:30:33 cosmos-var-cb3-c1 dnf[1850333]: Error: Failed to download metadata for repo 'packages-microsoft-com-prod': Cannot download repomd.xm>
2025-03-21 08:11:19.822 | ERROR | Mar 05 15:30:33 cosmos-var-cb3-c1 dnf[1850333]: Errors during downloading metadata for repository 'packages-microsoft-com-prod':                	>
(5 rows)
```

