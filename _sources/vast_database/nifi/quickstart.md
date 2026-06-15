# NiFi 2.x Quickstart

The VastDB Apache NiFi 2.x Processors [Github repository](https://github.com/vast-data/vastdb_nifi) contains Apache Nifi 2.x Processors for working with VastDB:

- **DeleteVastDB**: Deletes Vast DataBase Table rows ([docs](https://github.com/vast-data/vastdb_nifi/blob/main/docs/DeleteVastDB.md))
- **DropVastDBTable**: Drop a Vast DataBase Table ([docs](https://github.com/vast-data/vastdb_nifi/blob/main/docs/DropVastDBTable.md))
- **ImportVastDB**: High performance import of parquet files from Vast S3 ([docs](https://github.com/vast-data/vastdb_nifi/blob/main/docs/ImportVastDB.md))
- **PutVastDB**: Writes data to a Vast DataBase Table ([docs](https://github.com/vast-data/vastdb_nifi/blob/main/docs/PutVastDB.md))
- **QueryVastDBTable**: Queries a Vast DataBase Table ([docs](https://github.com/vast-data/vastdb_nif/blob/main/docs/QueryVastDBTable.md))
- **UpdateVastDB**: Updates a Vast DataBase Table ([docs](https://github.com/vast-data/vastdb_nifi/blob/main/docs/UpdateVastDB.md))

Visit the above URL for details.

Here is an example from the above URL to quickly try NiFi with VastDB using docker:

```{important}
The following example experimental. Ensure you manually backup data that you can't afford to lose.
```

```bash
# set this to the hostname or ip address where you are running NiFi
export NIFI_HOST=hostname_or_ipaddress

if [[ "$NIFI_HOST" == "hostname_or_ipaddress" ]]; then
    echo "ERROR: NIFI_HOST variable MUST be set for your environment."
    exit 1
fi

mkdir vastdb_nifi_docker
cd vastdb_nifi_docker

mkdir -p nifi_extensions
mkdir -p nifi_state
mkdir -p nifi_db
mkdir -p nifi_flowfile
mkdir -p nifi_profile
mkdir -p nifi_content
mkdir -p nifi_provenance

LATEST_RELEASE=$(python3 -c "import requests; print(requests.get('https://api.github.com/repos/vast-data/vastdb_nifi/releases/latest').json()['tag_name'].lstrip('v'))")

wget -c -P nifi_extensions https://github.com/vast-data/vastdb_nifi/releases/download/v${LATEST_RELEASE}/vastdb_nifi-${LATEST_RELEASE}-linux-x86_64-py39.nar

# Include parquet support
wget -c -P nifi_extensions https://repo1.maven.org/maven2/org/apache/nifi/nifi-parquet-nar/2.0.0-M4/nifi-parquet-nar-2.0.0-M4.nar
wget -c -P nifi_extensions https://repo1.maven.org/maven2/org/apache/nifi/nifi-hadoop-libraries-nar/2.0.0-M4/nifi-hadoop-libraries-nar-2.0.0-M4.nar
wget -c -P nifi_extensions https://repo1.maven.org/maven2/org/apache/nifi/nifi-iceberg-processors-nar/2.0.0-M4/nifi-iceberg-processors-nar-2.0.0-M4.nar
wget -c -P nifi_extensions https://repo1.maven.org/maven2/org/apache/nifi/nifi-iceberg-services-api-nar/2.0.0-M4/nifi-iceberg-services-api-nar-2.0.0-M4.nar
wget -c -P nifi_extensions https://repo1.maven.org/maven2/org/apache/nifi/nifi-iceberg-services-nar/2.0.0-M4/nifi-iceberg-services-nar-2.0.0-M4.nar

docker run --name nifi \
   -p 8443:8443 \
   -d \
   -e NIFI_WEB_PROXY_HOST=${NIFI_HOST} \
   -e SINGLE_USER_CREDENTIALS_USERNAME=admin \
   -e SINGLE_USER_CREDENTIALS_PASSWORD=123456123456 \
   -v ./nifi_extensions:/opt/nifi/nifi-current/nar_extensions \
   -v ./nifi_state:/opt/nifi/nifi-current/state \
   -v ./nifi_db:/opt/nifi/nifi-current/database_repository \
   -v ./nifi_flowfile:/opt/nifi/nifi-current/flowfile_repository \
   -v ./nifi_content:/opt/nifi/nifi-current/content_repository \
   -v ./nifi_provenance:/opt/nifi/nifi-current/provenance_repository \
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
