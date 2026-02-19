FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libc-dev && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    psycopg2-binary \
    confluent-kafka \
    pyyaml

COPY src/ /app/src/

CMD ["python", "-m", "src.main"]