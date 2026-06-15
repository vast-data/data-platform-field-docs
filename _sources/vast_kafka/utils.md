# Kafka Utils

## List topics

```bash
VAST_BROKER=172.200.204.1:9092
docker run --rm jforge/kafka-tools kafka-topics.sh --bootstrap-server $VAST_BROKER --list
```

## Consume messages

```bash
VAST_BROKER=172.200.204.1:9092

# Example: Consume from 'topic-A' AND 'topic-B'
docker run --rm jforge/kafka-tools kafka-console-consumer.sh \
    --bootstrap-server $VAST_BROKER \
    --whitelist 'topic-A|topic-B' \
    --from-beginning
```

```bash
VAST_BROKER=172.200.204.1:9092

# Example: Consume from all topics starting with 'prod-'
docker run --rm jforge/kafka-tools kafka-console-consumer.sh \
    --bootstrap-server $VAST_BROKER \
    --whitelist 'prod-*' \
    --from-beginning
```