# spark_job.py
import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import col

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: spark_job.py <output_path>", file=sys.stderr)
        sys.exit(-1)

    output_path = sys.argv[1]

    spark = SparkSession \
        .builder \
        .appName("S3A Magic Committer Test") \
        .getOrCreate()

    # Set log level to WARN to reduce noise
    spark.sparkContext.setLogLevel("WARN")

    # Generate a larger dataset to ensure multipart uploads are triggered.
    # ~150 MB of data (15M rows * ~10 bytes/row)
    num_rows = 15000000
    num_partitions = 4
    df = spark.range(num_rows, numPartitions=num_partitions)

    print(f"Writing {num_rows} rows across {num_partitions} partitions to {output_path}...")

    # Write the DataFrame to S3 as Parquet.
    df.write.mode("overwrite").parquet(output_path)

    print("Write successful. Now reading back to verify...")
    
    # Read the data back and verify the row count.
    read_df = spark.read.parquet(output_path)
    read_count = read_df.count()
    
    if read_count == num_rows:
        print(f"Verification successful: Found {read_count} rows as expected.")
    else:
        print(f"Verification FAILED: Expected {num_rows} rows, but found {read_count} rows.", file=sys.stderr)
        sys.exit(1)

    print("Spark job finished successfully.")
    spark.stop()


