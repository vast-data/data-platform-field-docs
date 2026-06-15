# spark_failing_job.py
import sys
import time
from pyspark.sql import SparkSession
from pyspark.sql.functions import udf, col, spark_partition_id
from pyspark.sql.types import LongType

def failing_udf(partition_id, x):
    # This UDF will cause a specific Spark task (the one processing partition_id 0) to fail.
    # This simulates a mid-job task failure to test the committer's abort logic.
    if partition_id == 0 and x > 100:
        raise Exception("Intentional task failure for atomicity test on partition 0!")
    return x

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: spark_failing_job.py <output_path>", file=sys.stderr)
        sys.exit(-1)

    output_path = sys.argv[1]

    spark = SparkSession \
        .builder \
        .appName("S3A Atomicity Abort Test") \
        .getOrCreate()

    # Set log level to WARN to reduce noise
    spark.sparkContext.setLogLevel("WARN")
    
    sc = spark.sparkContext
    
    print("--- Spark Job Configuration ---")
    print("commitProtocol:", spark.conf.get("spark.sql.sources.commitProtocolClass", "Not Set"))
    print("parquetCommitter:", spark.conf.get("spark.sql.parquet.output.committer.class", "Not Set"))
    print("committerFactory:", sc._jsc.hadoopConfiguration().get("mapreduce.outputcommitter.factory.scheme.s3a", "Not Set"))
    print("-----------------------------")

    # Generate a dataset large enough to ensure the failure happens mid-write.
    num_rows = 80000000
    num_partitions = 4
    df = spark.range(num_rows, numPartitions=num_partitions)

    # Register the UDF
    failing_udf_spark = udf(failing_udf, LongType())
    
    # Apply the UDF which will cause an exception and task failure on one partition.
    from pyspark.sql.functions import spark_partition_id
    df_with_failure = df.withColumn("id", failing_udf_spark(spark_partition_id(), col("id")))

    print(f"Starting intentional-failure job, writing to {output_path}...")
    
    # This write operation is expected to FAIL.
    try:
        df_with_failure.write.mode("overwrite").parquet(output_path)
    except Exception as e:
        print(f"Caught expected exception during Spark write: {e}", file=sys.stderr)
        # Exit with a non-zero status code to signal the failure to the calling script.
        sys.exit(1)

    # This part of the script should not be reached.
    print("Error: The failing Spark job completed unexpectedly.", file=sys.stderr)
    spark.stop()
    sys.exit(1)


