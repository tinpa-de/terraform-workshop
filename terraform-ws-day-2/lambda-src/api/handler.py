"""
DEVK Claims API Lambda
======================

Stellt REST-Endpoints für das Anlegen und Abfragen von Schadensmeldungen bereit.

Routes:
  POST /claims           - Neue Schadensmeldung anlegen
  GET  /claims           - Alle Schadensmeldungen auflisten
  GET  /claims/{id}      - Einzelne Schadensmeldung abrufen

Im echten Leben würde diese Lambda auch presigned URLs für S3-Uploads erzeugen.
"""

import json
import logging
import os
import uuid

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

BUCKET_NAME = os.environ["BUCKET_NAME"]

DDL = """
CREATE TABLE IF NOT EXISTS claims (
    id              VARCHAR(64) PRIMARY KEY,
    policy_number   VARCHAR(64) NOT NULL,
    claim_type      VARCHAR(64) NOT NULL,
    description     TEXT,
    status          VARCHAR(32) NOT NULL DEFAULT 'new',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_claims_policy
    ON claims (policy_number);
"""


def get_connection():
    return pg8000.native.Connection(**DB_CONFIG, timeout=10)


def ensure_schema(conn):
    conn.run(DDL)


def response(status: int, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body, default=str),
    }


def create_claim(conn, payload: dict):
    policy_number = payload.get("policy_number")
    claim_type = payload.get("claim_type")
    description = payload.get("description", "")

    if not policy_number or not claim_type:
        return response(400, {"error": "policy_number and claim_type are required"})

    claim_id = f"CLM-{uuid.uuid4().hex[:10].upper()}"

    conn.run(
        """
        INSERT INTO claims (id, policy_number, claim_type, description)
        VALUES (:claim_id, :policy_number, :claim_type, :description)
        """,
        claim_id=claim_id,
        policy_number=policy_number,
        claim_type=claim_type,
        description=description,
    )

    # Presigned URL für Foto-/Dokument-Upload bereitstellen (optional)
    upload_key = f"policies/{policy_number}/{claim_id}/document"
    presigned = s3.generate_presigned_url(
        "put_object",
        Params={"Bucket": BUCKET_NAME, "Key": upload_key},
        ExpiresIn=3600,
    )

    logger.info(f"Created claim {claim_id} for policy {policy_number}")
    return response(201, {
        "id": claim_id,
        "policy_number": policy_number,
        "claim_type": claim_type,
        "status": "new",
        "upload_url": presigned,
        "upload_key": upload_key,
    })


def list_claims(conn):
    rows = conn.run(
        "SELECT id, policy_number, claim_type, status, created_at "
        "FROM claims ORDER BY created_at DESC LIMIT 100"
    )
    columns = [c[0] for c in conn.columns]
    return response(200, {"claims": [dict(zip(columns, row)) for row in rows]})


def get_claim(conn, claim_id: str):
    rows = conn.run("SELECT * FROM claims WHERE id = :claim_id", claim_id=claim_id)
    if not rows:
        return response(404, {"error": f"Claim {claim_id} not found"})

    columns = [c[0] for c in conn.columns]
    claim = dict(zip(columns, rows[0]))

    doc_rows = conn.run(
        "SELECT id, filename, content_type, size_bytes, uploaded_at, status "
        "FROM claim_documents WHERE policy_number = :policy_number ORDER BY uploaded_at DESC",
        policy_number=claim["policy_number"],
    )
    doc_columns = [c[0] for c in conn.columns]
    documents = [dict(zip(doc_columns, row)) for row in doc_rows]

    return response(200, {"claim": claim, "documents": documents})


def lambda_handler(event, context):
    logger.info(f"Request: {event.get('routeKey')} {event.get('rawPath')}")

    route_key = event.get("routeKey", "")
    path_params = event.get("pathParameters") or {}

    conn = get_connection()
    try:
        ensure_schema(conn)

        if route_key == "POST /claims":
            payload = json.loads(event.get("body") or "{}")
            return create_claim(conn, payload)

        if route_key == "GET /claims":
            return list_claims(conn)

        if route_key == "GET /claims/{id}":
            return get_claim(conn, path_params.get("id"))

        return response(404, {"error": f"Unknown route: {route_key}"})

    except json.JSONDecodeError:
        return response(400, {"error": "Invalid JSON body"})
    except Exception as e:
        logger.exception("Handler failed")
        return response(500, {"error": str(e)})
    finally:
        conn.close()
