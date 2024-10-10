# Trino Quickstart for Vast DB

Trino provides a very powerful and flexible way to connect to the VAST Catalog. Trino allows querying the catalog from the Trino python client, Querybook, Grafana, and other software that can use Trino as a datasource. VAST has published docker containers with everything you need to connect to your VAST cluster.

## Prerequisites

This guide assumes that you have:

- enabled the catalog
- have an identity policy granting access to it
- have a user associated with the identity policy
- the user has S3 credentials
- a Linux system with docker installed and a user with permissions to start containers

See Providing Client Access to VAST Catalog CLI in the VAST Support documentation for information on the first 4 items.

## Configure & start Trino container

Create a vast.properties with these contents, update with the correct endpoint and access/secret keys:

```bash
## Update these fields ##
# "endpoint" should be a load-balanced DNS entry or one of the VIPs prefixed by "http://"
# it should not contain a trailing / or anything else.
endpoint=http://x.x.x.x

# "data_endpoints" should be be a load-balanced DNS entry or one or more of the VIPs
# prefixed by "http://" it should not contain a trailing / or anything else.
# Multiple VIPs can be used with commas between them, eg: http://x.x.x.x,http://y.y.y.y
data_endpoints=http://x.x.x.x

# Access and secret keys -- make sure the user was added to an identity policy
# granting them access to the catalog.
access_key_id=xxx
secret_access_key=xxx

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

Start the VAST-provided trino docker container – they already contain the connector and the correct jvm.config updates.

The version of the trino container depends on your cluster version. See the full docs (https://support.vastdata.com/s/article/UUID-58380a6a-6594-914d-004b-b37d5a06692b) for details but in short:

- 4.7 - use `vastdataorg/trino-vast:375`
- 5.0 - use `vastdataorg/trino-vast:420`
- 5.1 - use `vastdataorg/trino-vast:429`

```bash
docker run \
    --name trino \
    -p 8080:8080 -d \
    -v ./vast.properties:/etc/trino/catalog/vast.properties:ro \
    vastdataorg/trino-vast:429
```

## Test with the Trino client

Start the client from within the trino container:

```bash
docker exec -it trino trino
```

Now you can execute queries against the server – you must start with the use command to set the context:

```sql
use vast."vast-big-catalog-bucket|vast_big_catalog_schema";

show columns from vast_big_catalog_table;
select * from vast_big_catalog_table limit 1;
```
