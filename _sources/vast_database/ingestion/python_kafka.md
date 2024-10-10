# Kafka to Vast DB using Python

## Requirements:
1. Create a vast bucket and schema
2. Set the following env variables:
   1. KAFKA_HOST (defaults to `localhost`)
   2. VAST_DB_INSERT_BATCH_SIZE (defaults to 1000)
   3. VAST_DB_HOST
   4. VAST_DB_PORT (defaults to 8070)
   5. VAST_DB_ACCESS_KEY
   6. VAST_DB_SECRET_KEY
   7. BUCKET
   8. SCHEMA

## Steps

1. Subscribe to predefined topics
2. Topic data is inserted to an auto-created VDB table
3. Topic schema changes are auto-detected and applied to the table
4. Two specific arrow schema edge cases:
   1. Empty list: `key: []` is translated to arrow `list<item: string>` type
   2. `ts` key (`double` by default) is translated to arrow `timestamp[us]` type

## Running the script:

```bash
python3 ./vdb_kafka_importer.py
```

## Script: vdb_kafka_importer.py

```python
from kafka import KafkaConsumer
import json
import pyarrow as pa
from kafka.errors import KafkaError

import vastdb

import vastdb.bucket
import vastdb.schema
import vastdb.table
import os
import logging
import time
logging.basicConfig()
logger = logging.getLogger()


def is_debug_mode():
    return os.environ.get('VAST_DEBUG', '0').lower() in ['1', 'y', 'yes']


if is_debug_mode():
    logger.setLevel(logging.DEBUG)
else:
    logger.setLevel(logging.INFO)


KAFKA_HOST = os.environ.get('KAFKA_HOST', 'localhost')
KAFKA_TOPICS = ["topic1", "topic2"]

VAST_DB_INSERT_BATCH_SIZE = int(os.environ.get('VAST_DB_INSERT_BATCH_SIZE', '1000'))
VAST_DB_HOST = os.environ.get('VAST_DB_HOST', os.environ['VAST_DB_HOST'])
VAST_DB_PORT = int(os.environ.get('VAST_DB_PORT', '8070'))
VAST_DB_ACCESS_KEY = os.environ.get('VAST_DB_ACCESS_KEY', os.environ['VAST_DB_ACCESS_KEY'])
VAST_DB_SECRET_KEY = os.environ.get('VAST_DB_SECRET_KEY', os.environ['VAST_DB_SECRET_KEY'])
BUCKET = os.environ['BUCKET']
SCHEMA = os.environ['SCHEMA']

SCHEMA_EDGE_CASES = {
    lambda f: f.type == pa.list_(pa.null()): lambda f: pa.field(f.name, pa.list_(pa.string())),
    lambda f: f.name == "ts" and f.type != pa.timestamp: lambda f: pa.field(f.name, pa.timestamp('us'))
}


def to_record_batch(list_of_messages_as_dict):
    return pa.RecordBatch.from_pylist(list_of_messages_as_dict)


def main():
    debug_mode = is_debug_mode()
    consumer = KafkaConsumer(
        bootstrap_servers=[KAFKA_HOST],
        value_deserializer=lambda m: json.loads(m.decode('utf-8')),
        max_poll_records=VAST_DB_INSERT_BATCH_SIZE,
        auto_offset_reset='earliest'
    )
    consumer.subscribe(topics=KAFKA_TOPICS)

    session = vastdb.connect(
        endpoint=f'http://{VAST_DB_HOST}:{VAST_DB_PORT}',
        access=VAST_DB_ACCESS_KEY,
        secret=VAST_DB_SECRET_KEY
    )

    start_time = time.time()
    logger.info(f"Start time: {start_time}")
    inserted_rows = 0
    # Main loop to consume messages from Kafka, process, and insert into VastDB
    topic_to_dicts = {}
    topic_to_table_schema = {}
    ctr = 0
    for msg in consumer:
        if debug_mode:
            logger.debug(f"New message from topic {msg.topic}: {msg.value}")
        topic_to_dicts.setdefault(msg.topic, []).append(msg.value)
        ctr = ctr + 1
        if ctr == VAST_DB_INSERT_BATCH_SIZE:
            with session.transaction() as tx:
                bucket: vastdb.bucket.Bucket = tx.bucket(BUCKET)
                schema: vastdb.schema.Schema = bucket.schema(SCHEMA)
                for topic, dicts_list in topic_to_dicts.items():
                    rb: pa.RecordBatch = to_record_batch(dicts_list)
                    batch_length = len(rb)
                    inserted_rows = inserted_rows + batch_length
                    logger.info(f"Transformed topic {topic} data to record batch of size {batch_length}, with schema: {rb.schema}")
                    batch_schema = replace_schema_edge_cases(rb.schema)
                    table_schema = topic_to_table_schema.get(topic)
                    if table_schema is None:
                        table: vastdb.table.Table = schema.create_table(topic, columns=batch_schema, fail_if_exists=False)
                        topic_to_table_schema[topic] = batch_schema
                        if batch_schema != rb.schema:
                            logger.debug(f"Adapting record batch to new schema")
                            rb = pa.RecordBatch.from_pylist(rb.to_pylist(), schema=batch_schema)
                    else:
                        unify_schema = pa.unify_schemas([table_schema, batch_schema])
                        schema_fields_diff = list(set(unify_schema).difference(table_schema))
                        table: vastdb.table.Table = schema.table(topic, fail_if_missing=True)
                        if len(schema_fields_diff) > 0:
                            logger.warning(f"Found missing columns: {schema_fields_diff}")
                            table.add_column(pa.schema(schema_fields_diff))
                            topic_to_table_schema[topic] = unify_schema
                        if unify_schema != rb.schema:
                            logger.debug(f"Adapting record batch to new unified schema")
                            rb = pa.RecordBatch.from_pylist(rb.to_pylist(), schema=unify_schema)
                    logger.info(f"Inserting to table: {table}")
                    table.insert(rb)
                logger.info(f"Done - Total inserted rows: {inserted_rows}, total time: {time.time() - start_time}")
            topic_to_dicts.clear()
            ctr = 0
    logger.info("All finished. Inserted ")


def replace_schema_edge_cases(schema):
    tmp_schema = schema
    for i, f in enumerate(schema):
        for field_predicate, field_mapper in SCHEMA_EDGE_CASES.items():
            if field_predicate(f):
                new_list_field = field_mapper(f)
                logger.warning(f"Adapting field at index {i}: {f} to {new_list_field}")
                tmp_schema = tmp_schema.set(i, new_list_field)
                break
    return tmp_schema


main()
```