#!/bin/bash
# Exit on error, treat unset variables as an error, and propagate exit status through pipes.
set -Eeuo pipefail

# This script runs a series of functional tests against an S3 endpoint
# using the Hadoop S3A connector and Spark. It is designed to be run inside the
# accompanying Docker container.

# --- Test Configuration ---
RANDOM_SUFFIX=$(od -A n -t d -N 4 /dev/urandom | tr -d '[:space:]')
TEST_DIR_NAME="hadoop-s3a-test-${RANDOM_SUFFIX}"
TEST_DIR="${S3_TEST_BUCKET}/${TEST_DIR_NAME}"

# Simple text file for basic tests
LOCAL_TEST_FILE="/tmp/s3a_test_file.txt"
LOCAL_TEST_CONTENT="This is a test file for the S3A magic committer."
TEST_FILE_NAME="s3a_test_file.txt"
TEST_FILE_COPY_NAME="s3a_test_file_copy.txt"
TEST_FILE_RENAMED_NAME="s3a_test_file_renamed.txt"
EMPTY_FILE_NAME="empty_file.txt"

# Random content files for multipart upload tests
SMALL_RANDOM_FILE="/tmp/small_random_file.bin"
LARGE_RANDOM_FILE="/tmp/large_random_file.bin"

# Classpath for Hadoop 3.4.0 S3A (used by CLI/MR only; keeps Spark isolated)
TOOLS_DIR="${HADOOP_HOME}/share/hadoop/tools/lib"
S3A_TOOLS_CP=$(echo \
  "${TOOLS_DIR}"/hadoop-aws-*.jar \
  "${TOOLS_DIR}"/bundle-*.jar \
  "${TOOLS_DIR}"/wildfly-openssl-*.jar 2>/dev/null | tr ' ' :)
HADOOP_CLI_CMD="HADOOP_CLASSPATH=${S3A_TOOLS_CP}${HADOOP_CLASSPATH:+:${HADOOP_CLASSPATH}}"


# --- Hadoop Configuration ---
HADOOP_CONF_FILE="${HADOOP_HOME}/etc/hadoop/core-site.xml"
echo "Generating Hadoop core-site.xml configuration..." >&2
cat <<EOF > "${HADOOP_CONF_FILE}"
<configuration>
    <property><name>fs.s3a.endpoint</name><value>${S3_ENDPOINT}</value></property>
    <property><name>fs.s3a.access.key</name><value>${S3_ACCESS_KEY}</value></property>
    <property><name>fs.s3a.secret.key</name><value>${S3_SECRET_KEY}</value></property>
    <property><name>fs.s3a.path.style.access</name><value>true</value></property>
    <property><name>fs.s3a.connection.ssl.enabled</name><value>${S3_SSL_ENABLED:-false}</value></property>
    <property><name>fs.s3a.committer.name</name><value>magic</value></property>
    <property><name>fs.s3a.committer.magic.enabled</name><value>true</value></property>
    <property><name>fs.s3a.impl</name><value>org.apache.hadoop.fs.s3a.S3AFileSystem</value></property>
    <property><name>fs.s3a.impl.disable.cache</name><value>true</value></property>
    <property><name>fs.s3a.multipart.size</name><value>16M</value></property>
    <property><name>fs.s3a.multipart.threshold</name><value>16M</value></property>
    <property><name>fs.s3a.connection.establish.timeout</name><value>15000</value></property>
    <property>
        <name>mapreduce.outputcommitter.factory.scheme.s3a</name>
        <value>org.apache.hadoop.fs.s3a.commit.S3ACommitterFactory</value>
    </property>
</configuration>
EOF

# --- Test Infrastructure ---
TEST_COUNTER=1
PASS_COUNT=0
FAIL_COUNT=0

report_pass() {
    printf "[TEST %2d] - %-60s ... PASS\n" "$TEST_COUNTER" "$1"
    ((++PASS_COUNT)); ((++TEST_COUNTER))
}
report_fail() {
    printf "[TEST %2d] - %-60s ... FAIL\n" "$TEST_COUNTER" "$1"
    ((++FAIL_COUNT)); ((++TEST_COUNTER))
    if [ -n "${2-}" ]; then
      echo "------- ERROR INFO -------" >&2; echo -e "$2" >&2; echo "--------------------------" >&2
    fi
}

# --- Main Execution ---
echo "Creating local test files..." >&2
dd if=/dev/urandom of="${SMALL_RANDOM_FILE}" bs=1M count=5 &>/dev/null
dd if=/dev/urandom of="${LARGE_RANDOM_FILE}" bs=1M count=20 &>/dev/null
echo "${LOCAL_TEST_CONTENT}" > "${LOCAL_TEST_FILE}"

echo "" >&2
echo "Starting Functional Tests for S3A endpoint: ${S3_ENDPOINT}" >&2
echo "Test Directory: ${TEST_DIR}" >&2
echo "----------------------------------------------------------------" >&2

# --- Test Suite ---
# [TEST 1] mkdir
test_name="Create directory with 'hdfs dfs -mkdir'"
set +e; output=$(eval ${HADOOP_CLI_CMD} hdfs dfs -mkdir -p "${TEST_DIR}" 2>&1); exit_code=$?; set -e
if [ ${exit_code} -eq 0 ]; then report_pass "$test_name"; else report_fail "$test_name" "$output"; fi

echo -e "\n--- Configuration Verification ---"
# [TEST 2] Confirm Magic Committer is configured
test_name="Confirm Magic Committer is configured"
set +e
name=$(eval ${HADOOP_CLI_CMD} hdfs getconf -confKey fs.s3a.committer.name 2>/dev/null || true)
enabled=$(eval ${HADOOP_CLI_CMD} hdfs getconf -confKey fs.s3a.committer.magic.enabled 2>/dev/null || true)
exit_code=$?
set -e
shopt -s nocasematch
if [[ ${exit_code} -eq 0 && "$name" == "magic" && "$enabled" == "true" ]]; then
  report_pass "$test_name"
else
  report_fail "$test_name" "Got: fs.s3a.committer.name=$name, fs.s3a.committer.magic.enabled=$enabled"
fi
shopt -u nocasematch

# [TEST 3] Confirm SSL is configured as expected
test_name="Confirm S3A SSL connection is configured"
set +e
ssl_enabled_conf=$(eval ${HADOOP_CLI_CMD} hdfs getconf -confKey fs.s3a.connection.ssl.enabled 2>/dev/null || true)
exit_code=$?
set -e
shopt -s nocasematch
if [[ ${exit_code} -eq 0 && "$ssl_enabled_conf" == "${S3_SSL_ENABLED:-false}" ]]; then
  report_pass "$test_name (Value: ${ssl_enabled_conf})"
else
  report_fail "$test_name" "Expected: ${S3_SSL_ENABLED:-false}, Got: ${ssl_enabled_conf}"
fi
shopt -u nocasematch

# [TEST 4] Display Multipart Upload Settings
test_name="Display S3A Multipart Upload settings"
set +e
multipart_size=$(eval ${HADOOP_CLI_CMD} hdfs getconf -confKey fs.s3a.multipart.size 2>/dev/null || true)
multipart_threshold=$(eval ${HADOOP_CLI_CMD} hdfs getconf -confKey fs.s3a.multipart.threshold 2>/dev/null || true)
exit_code=$?
set -e
if [ ${exit_code} -eq 0 ]; then
    printf "[TEST %2d] - %-60s ... INFO\n" "$TEST_COUNTER" "$test_name"
    echo "------- Settings -------"; echo "Part Size:    ${multipart_size}"; echo "Threshold:    ${multipart_threshold}"; echo "------------------------"
    ((++PASS_COUNT)); ((++TEST_COUNTER))
else
    report_fail "$test_name" "Could not retrieve multipart settings."
fi


echo -e "\n--- MapReduce Magic Committer Job Test ---"
MAPREDUCE_EXAMPLES_JAR=$(find "$HADOOP_HOME/share/hadoop/mapreduce" -maxdepth 1 -type f -name "hadoop-mapreduce-examples*.jar" | grep -Ev 'sources|tests|javadoc' | head -n1)

# [TEST 5] TeraGen
test_name="Run TeraGen MR job"
set +e
log_output=$( \
  eval ${HADOOP_CLI_CMD} hadoop jar "$MAPREDUCE_EXAMPLES_JAR" teragen \
  -Dmapreduce.framework.name=local -Dmapreduce.job.maps=2 1000000 "${TEST_DIR}/teragen-out" 2>&1 )
exit_code=$?
data_size=$(eval ${HADOOP_CLI_CMD} hdfs dfs -du -s -h "${TEST_DIR}/teragen-out" 2>&1 | awk '{print $1 " " $2}')
set -e
if [ ${exit_code} -eq 0 ]; then report_pass "$test_name (Generated Data Size: ${data_size})"; else report_fail "$test_name" "$log_output"; fi

# [TEST 6] Verify TeraGen
test_name="Verify TeraGen job success (_SUCCESS file)"
set +e; output=$(eval ${HADOOP_CLI_CMD} hdfs dfs -stat "${TEST_DIR}/teragen-out/_SUCCESS" 2>&1); exit_code=$?; set -e
if [ ${exit_code} -eq 0 ]; then report_pass "$test_name"; else report_fail "$test_name" "_SUCCESS file not found.\n$output"; fi

# [TEST 7] TeraSort
test_name="Run TeraSort MR job on generated data"
set +e
log_output=$( \
  eval ${HADOOP_CLI_CMD} hadoop jar "$MAPREDUCE_EXAMPLES_JAR" terasort \
  -Dmapreduce.framework.name=local -Dmapreduce.job.maps=2 -Dmapreduce.job.reduces=2 \
  "${TEST_DIR}/teragen-out" "${TEST_DIR}/terasort-out" 2>&1 )
exit_code=$?
set -e
if [ ${exit_code} -eq 0 ]; then report_pass "$test_name"; else report_fail "$test_name" "$log_output"; fi

# [TEST 8] Verify TeraSort
test_name="Verify TeraSort job success (_SUCCESS file)"
set +e; output=$(eval ${HADOOP_CLI_CMD} hdfs dfs -stat "${TEST_DIR}/terasort-out/_SUCCESS" 2>&1); exit_code=$?; set -e
if [ ${exit_code} -eq 0 ]; then report_pass "$test_name"; else report_fail "$test_name" "_SUCCESS file not found.\n$output"; fi

# [TEST 9] Display TeraSort Output Size
test_name="Display TeraSort output directory size"
set +e
output=$(eval ${HADOOP_CLI_CMD} hdfs dfs -ls -h "${TEST_DIR}/terasort-out" 2>&1)
exit_code=$?
set -e
if [ $exit_code -eq 0 ]; then
    printf "[TEST %2d] - %-60s ... INFO\n" "$TEST_COUNTER" "$test_name"
    echo "------- Directory Contents -------"; echo "$output"; echo "----------------------------------"
    ((++PASS_COUNT)); ((++TEST_COUNTER))
else
    report_fail "$test_name" "$output"
fi


echo -e "\n--- Advanced Spark Magic Committer Scenarios ---"
S3A_COMPAT_JARS_DIR=/opt/spark_compat_jars
S3A_SPARK_JARS_CSV=$(find "$S3A_COMPAT_JARS_DIR" -name "*.jar" | paste -sd, -)
SPARK_MAGIC_CONF="\
  --conf spark.hadoop.fs.s3a.committer.name=magic \
  --conf spark.hadoop.fs.s3a.committer.magic.enabled=true \
  --conf spark.hadoop.mapreduce.outputcommitter.factory.scheme.s3a=org.apache.hadoop.fs.s3a.commit.S3ACommitterFactory \
  --conf spark.sql.sources.commitProtocolClass=org.apache.spark.internal.io.cloud.PathOutputCommitProtocol"
SPARK_CMD_BASE="env -u HADOOP_HOME SPARK_DIST_CLASSPATH='' spark-submit --master local[*] \
    --jars ${S3A_SPARK_JARS_CSV} \
    --conf spark.driver.userClassPathFirst=true \
    --conf spark.hadoop.fs.s3a.impl.disable.cache=false \
    ${SPARK_MAGIC_CONF}"

# [TEST 10] Atomicity & Abort Test
test_name="Run intentionally failing Spark job to test atomicity"
set +e
log_output=$(eval ${SPARK_CMD_BASE} --conf "spark.driver.extraJavaOptions=-Dlog4j.logger.org.apache.hadoop.fs.s3a.commit=DEBUG" \
  --driver-memory 4g --executor-memory 4g \
  /spark_failing_job.py "${TEST_DIR}/spark-fail-out" 2>&1)
exit_code=$?
set -e

# [TEST 11] Verify Atomicity
test_name="Verify job failed and no committed files exist"
if [ ${exit_code} -ne 0 ]; then
  set +e
  committed=$(eval ${HADOOP_CLI_CMD} hdfs dfs -ls -R "${TEST_DIR}/spark-fail-out" 2>/dev/null | awk '$1 !~ /^d/ {print $8}' | grep -Ev '/\.|/_temporary|/_SUCCESS' || true)
  set -e
  if [ -z "$committed" ]; then
    report_pass "$test_name"
    set +e; eval ${HADOOP_CLI_CMD} hdfs dfs -rm -r -f "${TEST_DIR}/spark-fail-out" >/dev/null 2>&1; set -e
  else
    report_fail "$test_name" "Leftover objects:\n$committed"
  fi
else
  report_fail "Job was expected to fail for atomicity test, but it succeeded" "$log_output"
fi

# [TEST 12] Partitioned Write Test
test_name="Run Spark partitioned write job"
set +e
log_output=$(eval ${SPARK_CMD_BASE} --driver-memory 4g --executor-memory 4g ./spark_partitioned_job.py "${TEST_DIR}/spark-partitioned-out" 2>&1)
exit_code=$?
set -e
if [ ${exit_code} -eq 0 ]; then report_pass "$test_name"; else report_fail "$test_name" "$log_output"; fi

# [TEST 13] Verify Partitioned Job
test_name="Verify partitioned output contains non-empty parquet files"
set +e
zero_sized=$(eval ${HADOOP_CLI_CMD} hdfs dfs -ls -R "${TEST_DIR}/spark-partitioned-out" | awk '$1 !~ /^d/ && $5 == 0 && $8 ~ /\.parquet$/ {print $8}')
exit_code=$?
set -e
if [ ${exit_code} -eq 0 ] && [ -z "$zero_sized" ]; then
    report_pass "$test_name"
    printf "[TEST %2d] - %-60s ... INFO\n" "$TEST_COUNTER" "Display partitioned output"
    echo "------- Directory Contents -------"
    eval ${HADOOP_CLI_CMD} hdfs dfs -ls -h -R "${TEST_DIR}/spark-partitioned-out" | grep '\.parquet$'
    echo "----------------------------------"
    ((++PASS_COUNT)); ((++TEST_COUNTER))
else
    report_fail "$test_name" "Zero-sized parquet files found:\n$zero_sized"
fi

# [TEST 15] Overwrite Semantics Test
test_name="Run Spark partition overwrite job"
set +e
log_output=$(eval ${SPARK_CMD_BASE} --driver-memory 4g --executor-memory 4g /spark_overwrite_job.py "${TEST_DIR}/spark-overwrite-out" 2>&1)
exit_code=$?
set -e
if [ ${exit_code} -eq 0 ]; then report_pass "$test_name"; else report_fail "$test_name" "$log_output"; fi

# [TEST 18] Cleanup
test_name="Remove test directory recursively with 'hdfs dfs -rm -r'"
set +e; output=$(eval ${HADOOP_CLI_CMD} hdfs dfs -rm -r -skipTrash "${TEST_DIR}" 2>&1); exit_code=$?; set -e
if [ ${exit_code} -eq 0 ]; then report_pass "$test_name"; else report_fail "$test_name" "$output"; fi

# --- Summary ---
TOTAL_TESTS=$((PASS_COUNT + FAIL_COUNT))
echo "----------------------------------------------------------------" >&2
echo "Test Summary:" >&2
echo "Total Tests: ${TOTAL_TESTS}" >&2
echo "Passed:      ${PASS_COUNT}" >&2
echo "Failed:      ${FAIL_COUNT}" >&2
echo "----------------------------------------------------------------" >&2

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "One or more tests failed." >&2
    exit 1
else
    echo "All tests passed successfully!" >&2
    exit 0
fi



