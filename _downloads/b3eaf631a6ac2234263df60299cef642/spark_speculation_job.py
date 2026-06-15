# spark_speculation_job.py
import sys
import time
from pyspark.sql import SparkSession
from pyspark.sql.functions import udf, col, spark_partition_id
from pyspark.sql.types import LongType

def slow_udf(partition_id, x):
    # This UDF introduces a long delay for one specific task (partition 0)
    # to make it a "straggler" and trigger speculative execution.
    if partition_id == 0:
        time.sleep(15) # 15-second delay should be enough to trigger speculation
    return x

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: spark_speculation_job.py <output_path>", file=sys.stderr)
        sys.exit(-1)

    output_path = sys.argv[1]

    spark = SparkSession \
        .builder \
        .appName("S3A Speculative Execution Test") \
        .getOrCreate()
        
    # Set log level to WARN to reduce noise
    spark.sparkContext.setLogLevel("WARN")

    num_rows = 10000
    num_partitions = 2 # Use a small number of partitions to make speculation more likely
    
    df = spark.range(num_rows, numPartitions=num_partitions)

    # Register and apply the UDF that will slow down one task
    slow_udf_spark = udf(slow_udf, LongType())
    df_with_straggler = df.withColumn("id", slow_udf_spark(spark_partition_id(), col("id")))
    
    print(f"Starting speculative execution job, writing {num_rows} rows to {output_path}...")
    print("One task will be artificially slowed down to trigger speculation.")
    
    # This write operation will trigger speculation for the slow task.
    df_with_straggler.write.mode("overwrite").parquet(output_path)

    print("Speculative write job completed.")
    spark.stop()


