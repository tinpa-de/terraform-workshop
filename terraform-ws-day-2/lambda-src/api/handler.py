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
from datetime import datetime, timezone

import boto3
import psycopg2
import psycopg2.extras

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

s3 = boto3.client("s3")

DB_CONFIG = {
    "host": os.environ["DB_HOST"],
    "port": int(os.environ.get("DB_PORT", "5432")),
    "dbname": os.environ["DB_NAME"],
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
    return psycopg2.connect(**DB_CONFIG, connect_timeout=10)


def ensure_schema(conn):
    with conn.cursor() as cur:
        cur.execute(DDL)
    conn.commit()


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

    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO claims (id, policy_number, claim_type, description)
            VALUES (%s, %s, %s, %s)
            """,
            (claim_id, policy_number, claim_type, description),
        )
    conn.commit()

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
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(
            "SELECT id, policy_number, claim_type, status, created_at "
            "FROM claims ORDER BY created_at DESC LIMIT 100"
        )
        rows = cur.fetchall()
    return response(200, {"claims": rows})


def get_claim(conn, claim_id: str):
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("SELECT * FROM claims WHERE id = %s", (claim_id,))
        claim = cur.fetchone()
        if not claim:
            return response(404, {"error": f"Claim {claim_id} not found"})

        cur.execute(
            "SELECT id, filename, content_type, size_bytes, uploaded_at, status "
            "FROM claim_documents WHERE policy_number = %s ORDER BY uploaded_at DESC",
            (claim["policy_number"],),
        )
        documents = cur.fetchall()

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
