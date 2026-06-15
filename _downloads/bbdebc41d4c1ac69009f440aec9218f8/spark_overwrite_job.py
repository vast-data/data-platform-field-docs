# spark_overwrite_job.py
import sys
import time
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql import types as T


def list_paths_recursive(spark, uri: str, depth: int = 1) -> None:
    sc = spark.sparkContext
    jvm = sc._jvm
    hconf = sc._jsc.hadoopConfiguration()
    path = jvm.org.apache.hadoop.fs.Path(uri)
    fs = jvm.org.apache.hadoop.fs.FileSystem.get(jvm.java.net.URI(uri), hconf)
    if not fs.exists(path):
        print(f"[list] Path does not exist: {uri}")
        return
    def _list(p, d):
        for status in fs.listStatus(jvm.org.apache.hadoop.fs.Path(p)):
            pstr = status.getPath().toString()
            kind = "DIR" if status.isDirectory() else "FILE"
            size = status.getLen()
            print(f"  [{'DIR' if status.isDirectory() else 'FILE'}] {pstr} ({size} bytes)")
            if d > 0 and status.isDirectory():
                _list(pstr, d - 1)
    print(f"[list] Listing of {uri} (depth={depth}):")
    _list(uri, depth)


def delete_path_if_exists(spark, uri: str) -> None:
    sc = spark.sparkContext
    jvm = sc._jvm
    hconf = sc._jsc.hadoopConfiguration()
    path = jvm.org.apache.hadoop.fs.Path(uri)
    fs = jvm.org.apache.hadoop.fs.FileSystem.get(jvm.java.net.URI(uri), hconf)
    if fs.exists(path):
        print(f"Deleting existing path before append: {uri}")
        fs.delete(path, True)
    else:
        print(f"Path not present (nothing to delete): {uri}")


def main(output):
    spark = (
        SparkSession.builder
        .appName("S3A Manual Partition Replace Test")
        .getOrCreate()
    )

    # Keep writers and file count under control
    spark.conf.set("spark.sql.shuffle.partitions", "4")
    spark.conf.set("spark.sql.files.maxRecordsPerFile", "1000000")
    spark.sparkContext.setLogLevel("WARN")  # reduce noise

    print("""--- Spark SQL overwrite settings ---
partitionOverwriteMode: (not set; using manual delete + append)
------------------------------------""")

    # Create initial dataset with two days
    schema = T.StructType([
        T.StructField("id", T.LongType(), False),
        T.StructField("val", T.StringType(), False),
        T.StructField("dt",  T.StringType(), False),
    ])
    initial = spark.createDataFrame(
        [(i, f"v{i}", "2025-09-01") for i in range(1000)] +
        [(i, f"v{i}", "2025-09-02") for i in range(1000, 2000)],
        schema=schema
    ).coalesce(2)  # <= keep file count tiny
    print(f"Creating initial dataset at {output}")
    (initial.write
        .mode("overwrite")
        .partitionBy("dt")
        .parquet(output))
    print("Initial write complete.")
    list_paths_recursive(spark, output, depth=2)

    # New rows which should REPLACE ONLY dt=2025-09-02
    overwrite = spark.createDataFrame(
        [(i, f"v{i}-OVER", "2025-09-02") for i in range(2000, 3000)],
        schema=schema
    ).coalesce(2)
    target_partition_path = f"{output}/dt=2025-09-02"
    print(f"Preparing to replace partition: {target_partition_path}")

    # Manually delete the target partition, then append
    delete_path_if_exists(spark, target_partition_path)
    list_paths_recursive(spark, output, depth=2)
    (overwrite.write
        .mode("append")
        .partitionBy("dt")
        .parquet(output))
    print("Manual partition replace complete (delete + append)."
)
    # Give the object store a moment (defensive; should be strongly consistent)
    time.sleep(1.0)
    # Invalidate caches and re-list the path.
    try:
        spark.catalog.clearCache()
    except Exception:
        pass
    try:
        spark.catalog.refreshByPath(output)
    except Exception:
        pass
    list_paths_recursive(spark, output, depth=2)

    # Verify expectations; read via glob with basePath so partition column is included
    read_path = f"{output}/dt=*"
    print(f"Reading data from {read_path} with basePath={output} for verification...")
    df = spark.read.option("basePath", output).parquet(read_path)
    df.show(5, truncate=False)

    # Cast dt to string to avoid datetime.date keys in Python
    df_cnt = df.withColumn("dt_str", F.col("dt").cast("string"))
    counts_rows = df_cnt.groupBy("dt_str").agg(F.count(F.lit(1)).alias("n")).orderBy("dt_str").collect()
    print("Counts by partition:", counts_rows)
    counts = {r["dt_str"]: int(r["n"]) for r in counts_rows}

    print("Verifying data after manual replace...")
    errors = []
    if counts.get("2025-09-02") != 1000:
        errors.append(f"FAIL: Partition 'dt=2025-09-02' not as expected: {counts.get('2025-09-02')} (expected 1000)")
    else:
        print("OK: Partition 'dt=2025-09-02' was correctly replaced.")

    if counts.get("2025-09-01") != 1000:
        errors.append(f"FAIL: Partition 'dt=2025-09-01' was modified unexpectedly: {counts.get('2025-09-01')} (expected 1000)")
    else:
        print("OK: Partition 'dt=2025-09-01' was preserved.")

    if errors:
        for e in errors:
            print(e, file=sys.stderr)
        spark.stop()
        sys.exit(1)

    print("Overwrite semantics (manual replace) test passed successfully.")
    spark.stop()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: spark_overwrite_job.py <output_path>", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1])

