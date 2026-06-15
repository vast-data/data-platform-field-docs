# Zeek PCAP to VAST Kafka

This tutorial demonstrates how to capture network packets, process them with Zeek, and send the resulting logs to a VAST Kafka cluster for SIEM analysis.

## Overview

The workflow involves three main steps:
1. **Capture** network packets using tcpdump
2. **Process** PCAP files with Zeek using Docker
3. **Stream** Zeek logs to VAST Kafka cluster

## Prerequisites

- Docker installed and running
- Root/sudo access for packet capture
- Network access to VAST Kafka cluster (e.g. 172.200.204.1:9092)
- Basic understanding of network protocols

## Project Structure

```
zeek-compose/
├── Dockerfile
├── run.sh
├── zeek-config/
│   └── kafka-pcap.zeek
├── pcap-files/
│   └── [captured packets]
└── zeek-logs/
    └── [zeek output logs]
```

## Step 1: Build the Zeek-Kafka Docker Image

First, create the Dockerfile with all necessary dependencies:

```dockerfile
# Use official Zeek Docker image as base
FROM zeek/zeek:latest

# Install required build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    g++ \
    cmake \
    make \
    libpcap-dev \
    curl \
    ca-certificates \
    libsasl2-dev \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install librdkafka
WORKDIR /tmp
RUN curl -L https://github.com/edenhill/librdkafka/archive/v1.4.4.tar.gz | tar xvz && \
    cd librdkafka-1.4.4/ && \
    ./configure --enable-sasl && \
    make && \
    make install && \
    ldconfig && \
    cd / && \
    rm -rf /tmp/librdkafka-1.4.4

# Install Zeek Kafka plugin using zkg
RUN zkg install seisollc/zeek-kafka --version v1.2.0 --force

# Verify plugin installation
RUN zeek -N Seiso::Kafka

# Set working directory back to default
WORKDIR /

# Default command
CMD ["zeek"]
```

Build the Docker image:

```bash
docker build -t zeek-kafka .
```

## Step 2: Configure Zeek for Kafka Integration

Create the Zeek configuration file `zeek-config/kafka-pcap.zeek`:

NOTE: Change the `metadata.broker.list` to reflect your environment.

```zeek
# Configuration for processing PCAP files and sending to Kafka
@load base/protocols/conn
@load base/protocols/dns
@load base/protocols/http
@load base/protocols/ssl
@load Seiso/Kafka

# Kafka configuration
redef Kafka::topic_name = "zeek-pcap-logs";
redef Kafka::kafka_conf = table(
    ["metadata.broker.list"] = "172.200.204.1:9092",
    ["client.id"] = "zeek-pcap-processor"
);

# Enable all active logs to be sent to Kafka
redef Kafka::send_all_active_logs = T;

# Use ISO8601 timestamps for better readability
redef Kafka::json_timestamps = JSON::TS_ISO8601;

# Tag JSON messages for easier identification
redef Kafka::tag_json = T;
```

### Configuration Options Explained

- **topic_name**: Kafka topic where Zeek logs will be sent
- **metadata.broker.list**: VAST Kafka broker address
- **client.id**: Identifier for this Zeek instance
- **send_all_active_logs**: Sends all protocol logs (conn, dns, http, ssl, etc.)
- **json_timestamps**: Uses human-readable timestamp format
- **tag_json**: Adds metadata tags to JSON messages

## Step 3: Capture Network Packets

### Identify Network Interface

List available network interfaces:

```bash
ip link show | grep -E '^[0-9]+:' | awk -F': ' '{print $2}' | sed 's/@.*//'
```

Common interface names: `eth0`, `ens33`, `ens35`, `enp0s3`

### Capture Packets with tcpdump

```bash
# Basic capture (1000 packets)
sudo tcpdump -i <interface> -s 0 -w pcap-files/mypackets.pcap -c 1000

# Extended capture with filters
sudo tcpdump -i eth0 -s 0 -w pcap-files/web-traffic.pcap -c 5000 'port 80 or port 443'

# Capture for specific duration (60 seconds)
sudo timeout 60s tcpdump -i eth0 -s 0 -w pcap-files/timed-capture.pcap
```

### tcpdump Parameters

- `-i <interface>`: Network interface to capture from
- `-s 0`: Capture full packet (no truncation)
- `-w <file>`: Write packets to file
- `-c <count>`: Capture specified number of packets
- `'filter'`: BPF filter expression (optional)

## Step 4: Process PCAP with Zeek

### Setup Directory Structure

```bash
mkdir -p zeek-config pcap-files zeek-logs
```

### Run Zeek Processing

```bash
docker run --rm \
    -v $(pwd)/zeek-config:/config \
    -v $(pwd)/pcap-files:/pcap \
    -v $(pwd)/zeek-logs:/logs \
    zeek-kafka \
    zeek -r /pcap/mypackets.pcap /config/kafka-pcap.zeek
```

### Docker Run Parameters

- `--rm`: Remove container after execution
- `-v`: Mount volumes for configuration, input, and output
- `zeek -r`: Read from PCAP file
- Last argument: Zeek configuration script

## Step 5: Verify VAST Integration

### Query Zeek Logs with VASTDB

Create a Python script to query your Zeek logs from VAST:

```python
import pyarrow as pa
import vastdb
import pandas as pd
from ibis import _

# VAST connection configuration
# Change to reflect your environment
ENDPOINT='http://172.200.204.1'
ACCESS_KEY="BR77TV2BSB1LQG4CH9QO"
SECRET_KEY='37tFv8Nd3tUFsQW7nyhFXLED0KUq7PW0Bj/cpjYg'

# Optional predicate for filtering (None = get all records)
predicate=None # (_.key.isin([b'123']))

# Connect to VAST
session = vastdb.connect(
    endpoint=ENDPOINT,
    access=ACCESS_KEY,
    secret=SECRET_KEY)

# Query the Zeek data
with session.transaction() as tx:
    bucket = tx.bucket('my-kafka')
    schema = bucket.schema('kafka_topics')
    table = schema.table('zeek')

    # run `SELECT * FROM t WHERE predicate`
    result = table.select(predicate=predicate).read_all()
    print(f"Total records found: {result.num_rows}")
```

Sample Output:

```
Total records found: 39
```

### View Zeek Log Details

```python
# Set pandas display options for better readability
pd.set_option('display.max_colwidth', 1000)

# Convert to pandas and view the JSON values
df = result.to_pandas()
zeek_logs = df['value']

# Display first few log entries
for i, log in enumerate(zeek_logs.head(5)):
    print(f"Record {i}:")
    print(log.decode('utf-8'))
    print("-" * 80)
```

Based on the actual data structure, you'll see logs like:

```json
{"ssl": {"ts":"2025-05-28T22:16:03.230983Z","uid":"123456","id.orig_h":"192.168.1.10","id.orig_p":39156,"id.resp_h":"203.0.113.15","id.resp_p":443,"version":"TLSv13","cipher":"TLS_AES_256_GCM_SHA384","curve":"x25519","server_name":"example-service.com","resumed":false,"established":true,"ssl_history":"CsiI"}}

{"conn": {"ts":"2025-05-28T22:16:03.240134Z","uid":"234567","id.orig_h":"192.168.1.20","id.orig_p":56950,"id.resp_h":"192.168.2.30","id.resp_p":7680,"proto":"tcp","conn_state":"S0","local_orig":true,"local_resp":true,"missed_bytes":0,"history":"S","orig_pkts":1,"orig_ip_bytes":52,"resp_pkts":0,"resp_ip_bytes":0,"ip_proto":6}}

{"dns": {"ts":"2025-05-28T22:16:03.237027Z","uid":"3456789","id.orig_h":"192.168.1.25","id.orig_p":5353,"id.resp_h":"224.0.0.251","id.resp_p":5353,"proto":"udp","trans_id":0,"rtt":0.0004901885986328125,"query":"workstation-host.local","qclass":1,"qclass_name":"C_INTERNET","qtype":255,"qtype_name":"*","rcode":0,"rcode_name":"NOERROR","AA":true,"TC":false,"RD":false,"RA":false,"Z":0,"answers":["fe80::1234:5678:9abc:def0","192.168.1.25"],"TTLs":[60.0,60.0],"rejected":false}}
```

## Security Considerations

- Ensure PCAP files don't contain sensitive data
- Use encrypted Kafka connections in production
- Implement proper access controls for capture interfaces
- Regular security updates for Docker images

## Conclusion

This tutorial provides a complete workflow for integrating network packet capture with Zeek analysis and VAST Kafka streaming. The containerized approach ensures consistent deployment across different environments while maintaining flexibility for custom configurations.

For production deployments, consider implementing proper monitoring, alerting, and data retention policies to ensure optimal performance and compliance with organizational requirements.