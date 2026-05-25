"""
CloudOps Finance — Main Flask Application.

A simple personal finance tracker demonstrating a 3-tier highly available
architecture on AWS. Users register income and expense entries; the app
persists them to RDS PostgreSQL and displays summaries.

All database connection details (host, port, dbname, user, password) are
read from AWS Secrets Manager at runtime via the EC2 instance IAM role.
No endpoint or credential is hardcoded, so this file is safe in a public repo.
"""

import json
import logging
import os
from datetime import datetime

import boto3
from botocore.exceptions import ClientError
from flask import Flask, jsonify, render_template, request, redirect, url_for
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

# ----------------------------------------------------------------------------
# Configuration via environment variables (set by systemd unit).
# Only non-sensitive values live here; connection details come from the secret.
# ----------------------------------------------------------------------------
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
DB_SECRET_NAME = os.environ.get("DB_SECRET_NAME", "cloudops/db/credentials")

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)


def get_db_credentials() -> dict:
    """Fetch DB credentials from AWS Secrets Manager using the EC2 IAM role."""
    client = boto3.client("secretsmanager", region_name=AWS_REGION)
    try:
        response = client.get_secret_value(SecretId=DB_SECRET_NAME)
    except ClientError as err:
        logger.error("Failed to fetch DB credentials: %s", err)
        raise
    return json.loads(response["SecretString"])


def build_database_url() -> str:
    """Construct the SQLAlchemy database URL entirely from the secret."""
    creds = get_db_credentials()
    user = creds["username"]
    password = creds["password"]
    host = creds["host"]
    port = creds.get("port", 5432)
    dbname = creds.get("dbname", "cloudops")
    return f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{dbname}"


# ----------------------------------------------------------------------------
# Flask app initialization
# ----------------------------------------------------------------------------
app = Flask(__name__)

# Lazy engine creation so /health doesn't fail if DB is down
engine = None
SessionLocal = None


def get_session():
    """Lazily create and return a SQLAlchemy session."""
    global engine, SessionLocal
    if engine is None:
        engine = create_engine(build_database_url(), pool_pre_ping=True)
        SessionLocal = sessionmaker(bind=engine)
    return SessionLocal()


# ----------------------------------------------------------------------------
# Routes
# ----------------------------------------------------------------------------
@app.route("/health")
def health():
    """Health check endpoint consumed by the ALB target group."""
    return jsonify(status="ok", timestamp=datetime.utcnow().isoformat()), 200


@app.route("/")
def index():
    """Render the dashboard with all entries and a running balance."""
    session = get_session()
    try:
        result = session.execute(
            text(
                "SELECT id, description, amount, entry_type, created_at "
                "FROM entries ORDER BY created_at DESC LIMIT 50"
            )
        )
        entries = [dict(row._mapping) for row in result]
        balance = sum(
            (e["amount"] if e["entry_type"] == "income" else -e["amount"])
            for e in entries
        )
        return render_template("index.html", entries=entries, balance=balance)
    finally:
        session.close()


@app.route("/add", methods=["POST"])
def add_entry():
    """Create a new income or expense entry."""
    description = request.form.get("description", "").strip()
    amount = float(request.form.get("amount", "0") or 0)
    entry_type = request.form.get("entry_type", "expense")

    if not description or amount <= 0 or entry_type not in ("income", "expense"):
        return redirect(url_for("index"))

    session = get_session()
    try:
        session.execute(
            text(
                "INSERT INTO entries (description, amount, entry_type, created_at) "
                "VALUES (:d, :a, :t, :c)"
            ),
            {
                "d": description,
                "a": amount,
                "t": entry_type,
                "c": datetime.utcnow(),
            },
        )
        session.commit()
        logger.info("Created entry: %s (%s %s)", description, entry_type, amount)
    finally:
        session.close()

    return redirect(url_for("index"))


# ----------------------------------------------------------------------------
# Entry point for development; production uses Gunicorn via systemd
# ----------------------------------------------------------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
