#!/bin/bash
#
# Unified entrypoint for ODH Spark Operator image.
# Handles operator commands (controller, webhook) AND Spark commands (driver, executor).
# Based on upstream operator entrypoint + Apache Spark v4.0.1 entrypoint.

set -ex

# Add a passwd entry for the container UID if one does not exist.
# Required for OpenShift arbitrary UID support and Java user.home resolution.
myuid="$(id -u)"
mygid="$(id -g)"
if ! getent passwd "$myuid" &> /dev/null; then
  if ! echo "$myuid:x:$myuid:$mygid:${SPARK_USER_NAME:-anonymous uid}:${HOME:-/home/spark}:/bin/false" >> /etc/passwd 2>/dev/null; then
    export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Duser.home=${HOME:-/opt/spark/work-dir}"
  fi
fi

case "$1" in
  driver)
    shift 1
    if [ -z "$JAVA_HOME" ]; then
      JAVA_HOME=$(java -XshowSettings:properties -version 2>&1 > /dev/null | grep 'java.home' | awk '{print $3}')
    fi

    SPARK_CLASSPATH="$SPARK_CLASSPATH:${SPARK_HOME}/jars/*"
    [ -n "$SPARK_EXTRA_CLASSPATH" ] && SPARK_CLASSPATH="$SPARK_CLASSPATH:$SPARK_EXTRA_CLASSPATH"
    [ -n "$HADOOP_CONF_DIR" ]       && SPARK_CLASSPATH="$HADOOP_CONF_DIR:$SPARK_CLASSPATH"
    if [ -n "$SPARK_CONF_DIR" ]; then
      SPARK_CLASSPATH="$SPARK_CONF_DIR:$SPARK_CLASSPATH"
    elif [ -n "$SPARK_HOME" ]; then
      SPARK_CLASSPATH="$SPARK_HOME/conf:$SPARK_CLASSPATH"
    fi
    [ -n "${HADOOP_HOME}" ] && [ -z "${SPARK_DIST_CLASSPATH}" ] && \
      export SPARK_DIST_CLASSPATH="$($HADOOP_HOME/bin/hadoop classpath)"
    [ -n "${PYSPARK_PYTHON+x}" ]        && export PYSPARK_PYTHON
    [ -n "${PYSPARK_DRIVER_PYTHON+x}" ] && export PYSPARK_DRIVER_PYTHON

    exec /usr/bin/tini -s -- \
      "$SPARK_HOME/bin/spark-submit" \
      --conf "spark.driver.bindAddress=$SPARK_DRIVER_BIND_ADDRESS" \
      --conf "spark.executorEnv.SPARK_DRIVER_POD_IP=$SPARK_DRIVER_BIND_ADDRESS" \
      --deploy-mode client \
      "$@"
    ;;

  executor)
    shift 1
    if [ -z "$JAVA_HOME" ]; then
      JAVA_HOME=$(java -XshowSettings:properties -version 2>&1 > /dev/null | grep 'java.home' | awk '{print $3}')
    fi

    SPARK_CLASSPATH="$SPARK_CLASSPATH:${SPARK_HOME}/jars/*"
    [ -n "$SPARK_EXTRA_CLASSPATH" ] && SPARK_CLASSPATH="$SPARK_CLASSPATH:$SPARK_EXTRA_CLASSPATH"
    [ -n "$HADOOP_CONF_DIR" ]       && SPARK_CLASSPATH="$HADOOP_CONF_DIR:$SPARK_CLASSPATH"
    if [ -n "$SPARK_CONF_DIR" ]; then
      SPARK_CLASSPATH="$SPARK_CONF_DIR:$SPARK_CLASSPATH"
    elif [ -n "$SPARK_HOME" ]; then
      SPARK_CLASSPATH="$SPARK_HOME/conf:$SPARK_CLASSPATH"
    fi
    [ -n "${HADOOP_HOME}" ] && [ -z "${SPARK_DIST_CLASSPATH}" ] && \
      export SPARK_DIST_CLASSPATH="$($HADOOP_HOME/bin/hadoop classpath)"
    SPARK_CLASSPATH="$SPARK_CLASSPATH:$PWD"

    env | grep SPARK_JAVA_OPT_ | sort -t_ -k4 -n | sed 's/[^=]*=\(.*\)/\1/g' > /opt/spark/work-dir/java_opts.txt
    readarray -t SPARK_EXECUTOR_JAVA_OPTS < /opt/spark/work-dir/java_opts.txt

    exec /usr/bin/tini -s -- \
      ${JAVA_HOME}/bin/java \
      "${SPARK_EXECUTOR_JAVA_OPTS[@]}" \
      -Xms$SPARK_EXECUTOR_MEMORY \
      -Xmx$SPARK_EXECUTOR_MEMORY \
      -cp "$SPARK_CLASSPATH:$SPARK_DIST_CLASSPATH" \
      org.apache.spark.scheduler.cluster.k8s.KubernetesExecutorBackend \
      --driver-url $SPARK_DRIVER_URL \
      --executor-id $SPARK_EXECUTOR_ID \
      --cores $SPARK_EXECUTOR_CORES \
      --app-id $SPARK_APPLICATION_ID \
      --hostname $SPARK_EXECUTOR_POD_IP \
      --resourceProfileId $SPARK_RESOURCE_PROFILE_ID \
      --podName $SPARK_EXECUTOR_POD_NAME
    ;;

  *)
    exec /usr/bin/tini -s -- /usr/bin/spark-operator "$@"
    ;;
esac
