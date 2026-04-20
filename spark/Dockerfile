FROM apache/spark:3.5.1

USER root

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    netcat-traditional \
    postgresql-client \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir kafka-python
RUN pip3 install psycopg2-binary

RUN mkdir -p /opt/spark/jars

RUN wget -P /opt/spark/jars/ \
    https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.5.0/iceberg-spark-runtime-3.5_2.12-1.5.0.jar \
    && wget -P /opt/spark/jars/ \
    https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar \
    && wget -P /opt/spark/jars/ \
    https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar \
    && wget -P /opt/spark/jars/ \
    https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.12/3.5.1/spark-sql-kafka-0-10_2.12-3.5.1.jar \
    && wget -P /opt/spark/jars/ \
    https://repo1.maven.org/maven2/org/apache/spark/spark-token-provider-kafka-0-10_2.12/3.5.1/spark-token-provider-kafka-0-10_2.12-3.5.1.jar \
    && wget -P /opt/spark/jars/ \
    https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/3.4.1/kafka-clients-3.4.1.jar \
    && wget -P /opt/spark/jars/ \
    https://repo1.maven.org/maven2/org/apache/commons/commons-pool2/2.11.1/commons-pool2-2.11.1.jar

COPY app/ /app/
COPY scripts/ /scripts/

RUN chmod +x /scripts/*.sh

RUN mkdir -p /opt/spark/data /tmp/derby /home/spark/metastore_db /tmp/spark-warehouse && \
    chown -R spark:spark /opt/spark/jars /app /scripts /opt/spark/data /tmp/derby /home/spark /tmp/spark-warehouse && \
    chmod -R 755 /home/spark /tmp/derby /tmp/spark-warehouse

RUN mkdir -p /home/spark/.ivy2 && \
    chown -R spark:spark /home/spark/.ivy2

RUN echo "Derby home set to /home/spark/metastore_db" > /home/spark/derby-config.txt

USER spark

WORKDIR /app