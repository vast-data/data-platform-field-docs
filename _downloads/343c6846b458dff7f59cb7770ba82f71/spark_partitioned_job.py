#!/usr/bin/env python3
import sys
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

def main(output):
    spark = (
        SparkSession.builder
        .appName("Large Partitioned Write for Multipart Test (>16MB files)")
        .getOrCreate()
    )
    sc = spark.sparkContext
    sc.setLogLevel("WARN")

    # Exactly one output file per partition
    partitions = 5
    spark.conf.set("spark.sql.shuffle.partitions", str(partitions))
    spark.conf.set("spark.sql.files.maxRecordsPerFile", "100000000")
    # Force large on-disk size: no compression
    spark.conf.set("spark.sql.parquet.compression.codec", "uncompressed")

    # Target size: >16MB per file (comfortably). Use ~80k rows/partition with ~2KB payload.
    rows_per_partition = 80_000
    total_rows = partitions * rows_per_partition

    df = (
        spark.range(0, total_rows)
             .withColumn("partition_key", (F.col("id") % F.lit(partitions)).cast("int"))
    )

    # ~2KB payload per row: 64-hex-char segment repeated 32 times
    seg = F.sha2(F.concat_ws('', F.lit('seed'), F.rand(), F.col('id').cast('string')), 256)
    payload = F.concat(F.col("id").cast("string"), F.repeat(seg, 32))

    df = (
        df.select("id", payload.alias("val"), "partition_key")
          .repartition(partitions, F.col("partition_key"))  # one partition per key
    )

    (df.write
        .mode("overwrite")
        .partitionBy("partition_key")
        .parquet(output)
    )

    spark.stop()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: spark_partitioned_job.py <output_path>", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1])

