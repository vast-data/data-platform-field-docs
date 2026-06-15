# Hadoop S3A Functional Tester (Also Magic Committer) - WIP

## Overview

This project provides a self-contained Docker environment to run a comprehensive functional test suite against Vast object store using Hadoop's S3A connector.

The primary goal is to validate the configuration and operation of the S3A Magic Committer.

The container includes installations of:

* Hadoop 3.4.0
* Apache Spark 3.5.1

---

## Warning

**S3A limits (magic mode doesn’t change these)**

* No atomic rename/move (dir or file) — it’s copy+delete. Enhancements do exist on VAST to make this faster in the case of `cp` or `mv`.
* No append, truncate, or in-place update; objects are immutable.
* No POSIX semantics: locks, hardlinks, chmod/ownership, atomic multi-file ops.

**Spark ops that are unsafe/not supported on S3A**

* Any rename-based commit (Hadoop FileOutputCommitter v1/v2, “write to \_temporary then rename”).
* “Write then rename to final name” for single files.
* `mode("overwrite")` / INSERT OVERWRITE of large dirs: delete+write, not atomic.
* Dynamic partition overwrite: same non-atomic delete+write; risky with concurrent writers.
* Concurrent writers to the same dir/partition without a transactional table layer.
* Structured Streaming file sink using rename commits (must be reconfigured to S3A committers, still not atomic across partitions).

**What’s fine (with caveats)**

* Append-mode batch writes of Parquet/ORC (directory of files) using S3A committers, but still watch for small-files and listing issues.

**Do instead**

* Use S3ACommitter (magic/partitioned/directory) to avoid renames entirely.
* For overwrite/concurrency, use a transactional table format like Delta, Iceberg, or Hudi.
* Never try to append/update a file; instead, write new files and version via table metadata.

---

## Features & Tests Performed

This suite runs a series of automated tests to validate different aspects of the S3A connector and the Magic Committer.

---

## Tests

* **[1–4] Setup** – Generate `core-site.xml`, sanity checks. *(N/A)*
* **[5] MR TeraGen** – MapReduce write. **Magic**
* **[7] MR TeraSort** – MapReduce write. **Magic**
* **[8–9] Verify/List MR** – Read/list only. *(N/A)*
* **[10] Spark failure atomicity** – Intentional fail; expect no committed files. **Magic**
* **[11–13] Spark partitioned write (multipart)** – Partitioned Parquet (>16 MB each). **Magic**
* **[14] Spark manual partition replace (delete + append)** – **NO Magic** `dynamicPartitionOverwrite` (**unsupported by Magic**).
    The suite still launches Spark with Magic enabled by default, but this step uses manual delete + append, so it doesn’t rely on any Magic-only semantics and works with or without Magic.

---

## Required Files

Download the necessary scripts and configuration files below. Place them all in the same directory before building the Docker image.

* `Dockerfile` {download}`files/Dockerfile`
* `entrypoint.sh` {download}`files/entrypoint.sh`
* `run-s3a-tests.sh` {download}`files/run-s3a-tests.sh`
* `spark_failing_job.py` {download}`files/spark_failing_job.py`
* `spark_job.py` {download}`files/spark_job.py`
* `spark_overwrite_job.py` {download}`files/spark_overwrite_job.py`
* `spark_partitioned_job.py` {download}`files/spark_partitioned_job.py`
* `spark_speculation_job.py` {download}`files/spark_speculation_job.py`

---

## How to Use

### 1. Build the Docker Image

With all the required files in the same directory, run the build command:

```bash
docker build -t hadoop-s3a-tester .
````

### 2\. Run the Test Container

Execute the container using `docker run`. You must provide your S3 endpoint and credentials as environment variables.

```bash
docker run --rm -it \
  -e S3_ENDPOINT="<your-s3-endpoint>" \
  -e S3_ACCESS_KEY="<your-access-key>" \
  -e S3_SECRET_KEY="<your-secret-key>" \
  -e S3_TEST_BUCKET="s3a://<your-test-bucket>" \
  -e S3_SSL_ENABLED="<true_or_false>" \
  hadoop-s3a-tester
```

#### Environment Variables:

  * `S3_ENDPOINT` (Required): The full URL of your S3-compatible storage (e.g., `http://s3.example.com`).
  * `S3_ACCESS_KEY` (Required): The access key for your S3 user.
  * `S3_SECRET_KEY` (Required): The secret key for your S3 user.
  * `S3_TEST_BUCKET` (Required): The S3A URI for the bucket to use for testing (e.g., `s3a://my-test-bucket`). The script will create a unique test directory inside this bucket. The bucket must exist beforehand.
  * `S3_SSL_ENABLED` (Optional): Set to `true` if your endpoint uses HTTPS, or `false` if it uses HTTP. Defaults to `false`.

### Example Command

```text
$ docker run --rm -it \
   -e S3_ENDPOINT="[http://172.200.202.1](http://172.200.202.1)" \
   -e S3_ACCESS_KEY="VFGQ7787T2WEBGSW09UB" \
   -e S3_SECRET_KEY="vMUQBz6v30luQEyV41kKMjPRgmWMif1ApNVFILeK" \
   -e S3_TEST_BUCKET="s3a://hadoop-magic-committer-test" \
   -e S3_SSL_ENABLED="true" \
   hadoop-s3a-tester

All required environment variables are set. Starting the S3A functional tests...
--------------------------------------------------------------------------------
Generating Hadoop core-site.xml configuration...
Creating local test files...

Starting Functional Tests for S3A endpoint: [http://172.200.202.1](http://172.200.202.1)
Test Directory: s3a://hadoop-magic-committer-test/hadoop-s3a-test-1999767119
----------------------------------------------------------------
[TEST  1] - Create directory with 'hdfs dfs -mkdir'                ... PASS
...
(output continues)
...
----------------------------------------------------------------
Test Summary:
Total Tests: 15
Passed:      15
Failed:       0
----------------------------------------------------------------
All tests passed successfully!
```