"""
DEVK Claims Processor Lambda
============================

Wird durch S3 ObjectCreated Events getriggert. Extrahiert Metadaten aus dem
hochgeladenen Objekt und legt einen Eintrag in der `claim_documents`-Tabelle an.

Erwartete Objekt-Schlüssel-Struktur: policies/{policy_number}/{filename}
Beispiel: policies/POL-12345/schaden_foto.jpg
"""

import json
import logging
import os
import urllib.parse

import boto3
import pg8000.native

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

s3 = boto3.client("s3")

DB_CONFIG = {
    "host": os.environ["DB_HOST"],
    "port": int(os.environ.get("DB_PORT", "5432")),
    "database": os.environ["DB_NAME"],
    "user": os.environ["DB_USER"],
    "password": os.environ["DB_PASSWORD"],
}

DDL = """
CREATE TABLE IF NOT EXISTS claim_documents (
    id              SERIAL PRIMARY KEY,
    policy_number   VARCHAR(64) NOT NULL,
    s3_bucket       VARCHAR(255) NOT NULL,
    s3_key          VARCHAR(1024) NOT NULL,
    filename        VARCHAR(512) NOT NULL,
    content_type    VARCHAR(128),
    size_bytes      BIGINT,
    uploaded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status          VARCHAR(32) NOT NULL DEFAULT 'new'
);

CREATE INDEX IF NOT EXISTS idx_claim_documents_policy
    ON claim_documents (policy_number);
"""


def get_connection():
    return pg8000.native.Connection(**DB_CONFIG, timeout=10)


def ensure_schema(conn):
    conn.run(DDL)


def extract_policy_number(key: str) -> str:
    """policies/POL-12345/foo.jpg -> POL-12345"""
    parts = key.split("/")
    if len(parts) >= 2 and parts[0] == "policies":
        return parts[1]
    return "UNKNOWN"


def process_record(conn, record: dict):
    bucket = record["s3"]["bucket"]["name"]
    key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
    size = record["s3"]["object"].get("size", 0)

    logger.info(f"Processing s3://{bucket}/{key} ({size} bytes)")

    # Metadaten via HEAD holen (Content-Type etc.)
    try:
        head = s3.head_object(Bucket=bucket, Key=key)
        content_type = head.get("ContentType", "application/octet-stream")
    except Exception as e:
        logger.warning(f"HEAD failed for {key}: {e}")
        content_type = "application/octet-stream"

    policy_number = extract_policy_number(key)
    filename = key.split("/")[-1]

    rows = conn.run(
        """
        INSERT INTO claim_documents
            (policy_number, s3_bucket, s3_key, filename, content_type, size_bytes)
        VALUES (:policy_number, :bucket, :key, :filename, :content_type, :size)
        RETURNING id;
        """,
        policy_number=policy_number,
        bucket=bucket,
        key=key,
        filename=filename,
        content_type=content_type,
        size=size,
    )
    new_id = rows[0][0]

    logger.info(
        f"Inserted claim_document id={new_id} policy={policy_number} file={filename}"
    )
    return new_id


def lambda_handler(event, context):
    logger.info(f"Received event with {len(event.get('Records', []))} record(s)")

    conn = get_connection()
    try:
        ensure_schema(conn)
        results = []
        for record in event.get("Records", []):
            if record.get("eventSource") != "aws:s3":
                continue
            new_id = process_record(conn, record)
            results.append(new_id)
        return {
            "statusCode": 200,
            "body": json.dumps({"processed": results}),
        }
    except Exception as e:
        logger.exception("Processing failed")
        raise
    finally:
        conn.close()
