# Use a stable Ubuntu LTS as the base image.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Versions
ENV HADOOP_VERSION=3.4.0
ENV SPARK_VERSION=3.5.1
ENV JAVA_VERSION=11

# Paths
ENV HADOOP_HOME=/opt/hadoop-${HADOOP_VERSION}
ENV SPARK_HOME=/opt/spark-${SPARK_VERSION}-bin-hadoop3
ENV HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop
ENV JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64
ENV PATH=${HADOOP_HOME}/bin:${SPARK_HOME}/bin:${JAVA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${HADOOP_HOME}/lib/native

# URLs (use mirror selector + fallbacks)
ENV HADOOP_TGZ=hadoop-${HADOOP_VERSION}.tar.gz
ENV SPARK_TGZ=spark-${SPARK_VERSION}-bin-hadoop3.tgz
ENV HADOOP_URL_PRIMARY="https://www.apache.org/dyn/closer.lua/hadoop/common/hadoop-${HADOOP_VERSION}/${HADOOP_TGZ}?action=download"
ENV HADOOP_URL_FALLBACK1="https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/${HADOOP_TGZ}"
ENV HADOOP_URL_FALLBACK2="https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/${HADOOP_TGZ}"
ENV SPARK_URL_PRIMARY="https://www.apache.org/dyn/closer.lua/spark/spark-${SPARK_VERSION}/${SPARK_TGZ}?action=download"
ENV SPARK_URL_FALLBACK1="https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/${SPARK_TGZ}"
ENV SPARK_URL_FALLBACK2="https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_TGZ}"

# Install tools, download Hadoop & Spark via fast mirrors with retries & parallel connections
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates aria2 gnupg "openjdk-${JAVA_VERSION}-jdk" python3; \
    rm -rf /var/lib/apt/lists/*; \
    \
    # helper: try URLs in order using aria2 (multi-conn) with fallback to curl
    fetch() { \
      for u in "$@"; do \
        echo "Trying: $u"; \
        aria2c -x 16 -s 16 -k 1M --check-certificate=true -o /tmp/pkg.tgz "$u" && return 0 || true; \
        curl -fL --retry 8 --retry-all-errors --retry-delay 2 --connect-timeout 15 --max-time 900 -o /tmp/pkg.tgz "$u" && return 0 || true; \
      done; \
      echo "All mirrors failed" >&2; exit 1; \
    }; \
    \
    # Hadoop
    fetch "$HADOOP_URL_PRIMARY" "$HADOOP_URL_FALLBACK1" "$HADOOP_URL_FALLBACK2"; \
    tar -xzf /tmp/pkg.tgz -C /opt/; rm -f /tmp/pkg.tgz; \
    \
    # Spark
    fetch "$SPARK_URL_PRIMARY" "$SPARK_URL_FALLBACK1" "$SPARK_URL_FALLBACK2"; \
    tar -xzf /tmp/pkg.tgz -C /opt/; rm -f /tmp/pkg.tgz; \
    \
    # Spark–Hadoop 3.3.4 compatible S3A jars (to match Spark's bundled Hadoop)
    mkdir -p /opt/spark_compat_jars; \
    curl -fL --retry 8 --retry-all-errors \
      -o /opt/spark_compat_jars/hadoop-aws-3.3.4.jar \
      https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar; \
    curl -fL --retry 8 --retry-all-errors \
      -o /opt/spark_compat_jars/aws-java-sdk-bundle-1.12.262.jar \
      https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar; \
    \
    # Spark Hadoop Cloud integration (needed for S3A committers in Spark SQL)
    curl -fL --retry 8 --retry-all-errors \
      -o "${SPARK_HOME}/jars/spark-hadoop-cloud_2.12-${SPARK_VERSION}.jar" \
      "https://repo1.maven.org/maven2/org/apache/spark/spark-hadoop-cloud_2.12/${SPARK_VERSION}/spark-hadoop-cloud_2.12-${SPARK_VERSION}.jar"

# Logging defaults
ENV HADOOP_OPTS="-Dlog4j.logger.org.apache.hadoop.fs.s3a=INFO"
ENV HADOOP_ROOT_LOGGER="WARN,console"

# Copy scripts
COPY entrypoint.sh /entrypoint.sh
COPY run-s3a-tests.sh /run-s3a-tests.sh
COPY spark_job.py /spark_job.py
COPY spark_failing_job.py /spark_failing_job.py
COPY spark_partitioned_job.py /spark_partitioned_job.py
COPY spark_overwrite_job.py /spark_overwrite_job.py
COPY spark_speculation_job.py /spark_speculation_job.py
RUN chmod +x /entrypoint.sh /run-s3a-tests.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["test"]


