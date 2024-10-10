# NiFi 2.x Quickstart

The VastDB Apache NiFi 2.x Processors [Github repository](https://github.com/vast-data/vastdb_nifi) contains Apache Nifi 2.x Processors for working with VastDB:

  - **DeleteVastDB**: Deletes Vast DataBase Table rows
  - **DropVastDBTable**: Drop a Vast DataBase Table
  - **ImportVastDB**: High performance import of parquet files from Vast S3
  - **PutVastDB**: Writes data to a Vast DataBase Table
  - **QueryVastDBTable**: Queries a Vast DataBase Table
  - **UpdateVastDB**: Updates a Vast DataBase Table

Visit the above URL for details.

Here is an example from the above URL to quickly try NiFi with VastDB using docker:

```bash
# set this to the hostname or ip address where you are running NiFi
export NIFI_HOST=hostname_or_ipaddress

if [[ "$NIFI_HOST" == "hostname_or_ipaddress" ]]; then
    echo "ERROR: NIFI_HOST must be set for your environment."
    exit 1
fi

mkdir vastdb_nifi_docker
cd vastdb_nifi_docker

LATEST_RELEASE=$(python3 -c "import requests; print(requests.get('https://api.github.com/repos/vast-data/vastdb_nifi/releases/latest').json()['tag_name'].lstrip('v'))")
wget -c https://github.com/vast-data/vastdb_nifi/releases/download/v${LATEST_RELEASE}/vastdb_nifi-${LATEST_RELEASE}-linux-x86_64-py39.nar

# Include parquet support
wget -c https://repo1.maven.org/maven2/org/apache/nifi/nifi-parquet-nar/2.0.0-M4/nifi-parquet-nar-2.0.0-M4.nar
wget -c https://repo1.maven.org/maven2/org/apache/nifi/nifi-hadoop-libraries-nar/2.0.0-M4/nifi-hadoop-libraries-nar-2.0.0-M4.nar

docker run --name nifi \
   -p 8443:8443 \
   -d \
   -e NIFI_WEB_PROXY_HOST=${NIFI_HOST} \
   -e SINGLE_USER_CREDENTIALS_USERNAME=admin \
   -e SINGLE_USER_CREDENTIALS_PASSWORD=123456123456 \
   -v .:/opt/nifi/nifi-current/nar_extensions \
   --platform linux/amd64 \
   apache/nifi:2.0.0-M4
```

Wait a few minutes, then:
- Open the URL: `https://hostname_or_ipaddress:8443`
- username: `admin`
- password: `123456123456`
- Note:
  - If you receive a SNI error when accessing NiFi from your browser, verify the `NIFI_HOST` variable is set to your NiFi hostname or ip address.
  - NiFi should be accessible when the logs output `org.apache.nifi.web.server.JettyServer Started Server on https://abcdefghi:8443/nifi`

**Important**:
- All state is lost when docker restarts:
  - This environment is not suitable for production.
  - It is recommended that you regularly **Download Flow Definition** files (Right click the canvas or Process Group).
- The `--platform linux/amd64` docker option is a hard requirement.
