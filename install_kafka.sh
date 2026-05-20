#!/bin/bash
# Debian/Ubuntu Apache Kafka Installation and Verification Script
set -e

KAFKA_VERSION="3.4.0"
SCALA_VERSION="2.13"
KAFKA_DIR="/opt/kafka"
TEMP_DIR="/tmp/kafka-install"

echo "=== Starting Apache Kafka Installation ==="

# 1. Install Prerequisites (Java JRE)
echo "Installing Java Runtime Environment..."
sudo apt-get update
sudo apt-get install -y default-jre wget

# 2. Create a Dedicated Kafka System User
echo "Creating dedicated 'kafka' system user..."
if ! id -u kafka > /dev/null 2>&1; then
    sudo useradd -r -m -U -d /home/kafka -s /bin/bash kafka
fi

# 3. Download and Extract Kafka Binaries
echo "Downloading Apache Kafka v${KAFKA_VERSION}..."
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"
wget -q "https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"

echo "Extracting Kafka to ${KAFKA_DIR}..."
sudo mkdir -p "$KAFKA_DIR"
sudo tar -xzf "kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz" -C "$KAFKA_DIR" --strip-components=1
sudo chown -R kafka:kafka "$KAFKA_DIR"

# 4. Create Systemd Unit Files for Zookeeper and Kafka
echo "Configuring Systemd Services..."

# Zookeeper Service Definition
cat <<EOF | sudo tee /etc/systemd/system/zookeeper.service
[Unit]
Description=Apache Zookeeper server
Documentation=http://zookeeper.apache.org
After=network.target

[Service]
Type=simple
User=kafka
Group=kafka
ExecStart=${KAFKA_DIR}/bin/zookeeper-server-start.sh ${KAFKA_DIR}/config/zookeeper.properties
ExecStop=${KAFKA_DIR}/bin/zookeeper-server-stop.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Kafka Service Definition
cat <<EOF | sudo tee /etc/systemd/system/kafka.service
[Unit]
Description=Apache Kafka Server
Documentation=http://kafka.apache.org/documentation.html
After=zookeeper.service

[Service]
Type=simple
User=kafka
Group=kafka
Environment="JAVA_HOME=/usr/lib/jvm/default-java"
ExecStart=${KAFKA_DIR}/bin/kafka-server-start.sh ${KAFKA_DIR}/config/server.properties
ExecStop=${KAFKA_DIR}/bin/kafka-server-stop.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 5. Start and Enable Services
echo "Starting Zookeeper and Kafka Services..."
sudo systemctl daemon-reload
sudo systemctl enable --now zookeeper
sudo systemctl enable --now kafka

# Wait for Kafka to initialize and bind to port 9092
echo "Waiting for Kafka to start up (10 seconds)..."
sleep 10

# 6. Verify Installation (Create Topic, Produce and Consume a Message)
echo "=== Running Verification Test ==="
TOPIC_NAME="test-debian-topic"

# Create a test topic
sudo -u kafka ${KAFKA_DIR}/bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic "$TOPIC_NAME"

# Produce a test message
echo "Hello Kafka from Debian 9 Guide!" | sudo -u kafka ${KAFKA_DIR}/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic "$TOPIC_NAME"

# Consume the test message to verify end-to-end flow
echo "Consuming test message:"
sudo -u kafka ${KAFKA_DIR}/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic "$TOPIC_NAME" --from-beginning --max-messages 1

echo "=== Kafka Installation and Verification Successful! ==="