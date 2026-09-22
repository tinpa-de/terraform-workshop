"""Feedback Portal - API backend.

One Lambda function serves all three routes of the HTTP API. It stores every
piece of feedback as a single JSON object in S3 under the "feedback/" prefix.

    POST /feedback        store new feedback, returns the generated id
    GET  /feedback        list all feedback
    GET  /feedback/{id}   read one piece of feedback

The bucket name comes from the BUCKET_NAME environment variable - the code
never hardcodes it. That is what lets the exact same file run against your
Day 1 bucket and your Day 2 bucket.

Only the standard library and boto3 are used. boto3 is part of the managed
Python runtime, so there is nothing to install and nothing to vendor.
"""

import json
import os
import uuid
from datetime import datetime, timezone

import boto3

s3 = boto3.client("s3")

BUCKET_NAME = os.environ["BUCKET_NAME"]
PREFIX = "feedback/"

VALID_RATINGS = range(1, 6)


def lambda_handler(event, context):
    """Entry point. Dispatches on the API Gateway v2 route key."""
    route = event.get("routeKey", "")

    if route == "POST /feedback":
        return create_feedback(event)
    if route == "GET /feedback":
        return list_feedback()
    if route == "GET /feedback/{id}":
        return get_feedback(event["pathParameters"]["id"])

    return respond(404, {"error": f"unknown route: {route or '(none)'}"})


# --- Handlers ---------------------------------------------------------------


def create_feedback(event):
    """Validate the request body and write it to S3 as feedback/<id>.json."""
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return respond(400, {"error": "body is not valid JSON"})

    team = body.get("team")
    rating = body.get("rating")
    comment = body.get("comment", "")

    if not team:
        return respond(400, {"error": "field 'team' is required"})
    if rating not in VALID_RATINGS:
        return respond(400, {"error": "field 'rating' must be an integer 1-5"})

    item = {
        "id": str(uuid.uuid4()),
        "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "team": team,
        "rating": rating,
        "comment": comment,
    }

    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=f"{PREFIX}{item['id']}.json",
        Body=json.dumps(item).encode("utf-8"),
        ContentType="application/json",
    )

    print(f"stored feedback {item['id']} for team {team}")
    return respond(201, item)


def list_feedback():
    """Return every object under the feedback/ prefix, newest first."""
    pages = s3.get_paginator("list_objects_v2").paginate(
        Bucket=BUCKET_NAME, Prefix=PREFIX
    )

    items = []
    for page in pages:
        for obj in page.get("Contents", []):
            items.append(read_item(obj["Key"]))

    items.sort(key=lambda item: item["created_at"], reverse=True)
    return respond(200, {"count": len(items), "items": items})


def get_feedback(feedback_id):
    """Return a single piece of feedback, or 404 if the key does not exist."""
    try:
        item = read_item(f"{PREFIX}{feedback_id}.json")
    except s3.exceptions.NoSuchKey:
        return respond(404, {"error": f"no feedback with id {feedback_id}"})

    return respond(200, item)


# --- Helpers ----------------------------------------------------------------


def read_item(key):
    """Read one JSON object out of S3 and parse it."""
    obj = s3.get_object(Bucket=BUCKET_NAME, Key=key)
    return json.loads(obj["Body"].read())


def respond(status_code, payload):
    """Build the response shape that API Gateway expects (payload format 2.0)."""
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload),
    }
