---
title: Run FlowDSL Locally with Docker Compose
description: Start the full FlowDSL infrastructure stack on your machine using Docker Compose.
weight: 209
---

This tutorial walks through starting the complete FlowDSL infrastructure stack locally — MongoDB, Redis, Kafka, Studio, and the runtime — using Docker Compose.

## Prerequisites

- **Docker Desktop 4.x+** with Docker Compose v2: `docker compose version`
- 4GB+ RAM available for Docker
- Ports 5173, 6379, 8081, 8082, 9092, 27017, 50051-50053 must be available

## Step 1: Clone the examples repository

```bash
git clone https://github.com/flowdsl/examples
cd examples
```

## Step 2: Review the docker-compose.yaml

```yaml
# docker-compose.yaml (excerpt)
services:
  mongodb:
    image: mongo:7
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --save 60 1 --loglevel warning
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10

  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
    ports:
      - "2181:2181"

  kafka:
    image: confluentinc/cp-kafka:7.5.0
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
    healthcheck:
      test: ["CMD", "kafka-topics", "--bootstrap-server", "localhost:9092", "--list"]
      interval: 30s
      timeout: 10s
      retries: 5

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    ports:
      - "8082:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: local
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092
    depends_on:
      - kafka

  flowdsl-runtime:
    image: flowdsl/runtime:latest
    ports:
      - "8081:8081"
    environment:
      MONGODB_URI: mongodb://mongodb:27017/flowdsl
      REDIS_URL: redis://redis:6379
      KAFKA_BROKERS: kafka:9092
      FLOWDSL_REGISTRY_FILE: /app/node-registry.yaml
      FLOWDSL_NODE_TRANSPORT: grpc
      FLOWDSL_GRPC_GO_ADDR: nodes-go:50051
      FLOWDSL_GRPC_PYTHON_ADDR: nodes-py:50052
      FLOWDSL_GRPC_JS_ADDR: nodes-js:50053
    volumes:
      - ./:/app/flows
      - ./node-registry.yaml:/app/node-registry.yaml
    depends_on:
      mongodb:
        condition: service_healthy
      redis:
        condition: service_healthy

  flowdsl-studio:
    image: flowdsl/studio:latest
    ports:
      - "5173:5173"
    environment:
      VITE_RUNTIME_URL: http://localhost:8081
    depends_on:
      - flowdsl-runtime

volumes:
  mongodb_data:
```

## Step 3: Start everything

```bash
make up-infra
```

Or directly:

```bash
docker compose up -d
```

This pulls images on the first run (may take a few minutes).

## Step 4: Verify services

```bash
docker compose ps
```

All services should show `healthy` or `running`:

```
NAME                    STATUS              PORTS
examples-mongodb-1      Up (healthy)        0.0.0.0:27017->27017/tcp
examples-redis-1        Up (healthy)        0.0.0.0:6379->6379/tcp
examples-zookeeper-1    Up                  0.0.0.0:2181->2181/tcp
examples-kafka-1        Up (healthy)        0.0.0.0:9092->9092/tcp
examples-kafka-ui-1     Up                  0.0.0.0:8082->8080/tcp
examples-flowdsl-runtime-1  Up (healthy)    0.0.0.0:8081->8081/tcp
examples-flowdsl-studio-1   Up              0.0.0.0:5173->5173/tcp
```

## Step 5: Access the services

| Service | URL | What it is |
|---------|-----|-----------|
| Studio | http://localhost:5173 | FlowDSL visual editor |
| Runtime API | http://localhost:8081 | Flow management API |
| Kafka UI | http://localhost:8082 | Browse Kafka topics |
| MongoDB | localhost:27017 | Connect with MongoDB Compass |
| Redis | localhost:6379 | Connect with Redis Insight |
| Go nodes (gRPC) | localhost:50051 | gRPC endpoint for Go nodes |
| Python nodes (gRPC) | localhost:50052 | gRPC endpoint for Python nodes |
| JS nodes (gRPC) | localhost:50053 | gRPC endpoint for JS nodes |

## Step 6: Load and run a sample flow

Copy an example flow to the working directory:

```bash
cp order-fulfillment/order-fulfillment.flowdsl.yaml .
```

Deploy it via the runtime API:

```bash
curl -X POST http://localhost:8081/flows \
  -H "Content-Type: application/yaml" \
  --data-binary @order-fulfillment.flowdsl.yaml
```

Or drag it into Studio at [http://localhost:5173](http://localhost:5173).

Trigger the flow with a sample event:

```bash
curl -X POST http://localhost:8081/flows/order_fulfillment/trigger \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": "ord-001",
    "customerId": "cust-123",
    "items": [{"sku": "WIDGET-A", "qty": 2, "price": 19.99}],
    "total": 39.98,
    "currency": "USD"
  }'
```

## Step 7: View execution logs

```bash
# Stream runtime logs
docker compose logs -f flowdsl-runtime

# View logs for all services
docker compose logs -f
```

Execution events look like:

```
flowdsl-runtime | {"level":"INFO","executionId":"exec-001","flowId":"order_fulfillment","nodeId":"ValidateOrder","status":"completed","durationMs":2}
flowdsl-runtime | {"level":"INFO","executionId":"exec-001","flowId":"order_fulfillment","nodeId":"ChargePayment","status":"completed","durationMs":847}
```

## Step 8: Stop everything

```bash
make down
# or
docker compose down
```

To also remove persisted data (MongoDB volumes):

```bash
docker compose down -v
```

## Troubleshooting

**Port already in use:**
```bash
# Find what's using port 27017
lsof -i :27017
# Change the host port in docker-compose.yaml if needed
```

**Kafka not starting:**
Kafka requires at least 2GB RAM. Check Docker Desktop's memory limit in Preferences → Resources. Set to at least 4GB.

**Runtime can't connect to MongoDB:**
Wait for MongoDB to show `healthy` before the runtime starts. You can restart just the runtime:
```bash
docker compose restart flowdsl-runtime
```

**Studio shows "Runtime offline":**
Ensure the runtime is healthy before opening Studio. The runtime needs MongoDB and Redis to be healthy first.

## Summary

```
make up-infra        # Start all services
docker compose ps    # Check service health
# Open Studio: http://localhost:5173
# Runtime API: http://localhost:8081
docker compose logs -f flowdsl-runtime  # Stream logs
make down            # Stop all services
```

## Next steps

- [Getting Started](/docs/tutorials/getting-started) — load the Order Fulfillment example
- [Your First Flow](/docs/tutorials/your-first-flow) — build and run a custom flow
- [Go SDK](/docs/tools/go-sdk) — run your own node implementations
