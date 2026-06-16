"""Quote API — DevOps take-home assignment service."""

import hashlib
import os
import random
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest

REQUESTS_TOTAL = Counter(
    "quote_api_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)

QUOTES = [
    {"id": 1, "text": "The only way to do great work is to love what you do.", "author": "Steve Jobs"},
    {"id": 2, "text": "It always seems impossible until it's done.", "author": "Nelson Mandela"},
    {"id": 3, "text": "Stay hungry, stay foolish.", "author": "Steve Jobs"},
    {"id": 4, "text": "Simplicity is the ultimate sophistication.", "author": "Leonardo da Vinci"},
    {"id": 5, "text": "Well done is better than well said.", "author": "Benjamin Franklin"},
    {"id": 6, "text": "Move fast and fix things.", "author": "Unknown"},
    {"id": 7, "text": "Infrastructure as code is a love letter to your future self.", "author": "Unknown"},
    {"id": 8, "text": "Automate everything you do twice.", "author": "Unknown"},
]

_ready = False


def _simulate_cpu_work(duration_ms: int = 100) -> None:
    """Burn CPU for roughly duration_ms using a deterministic hash loop."""
    deadline = time.perf_counter() + (duration_ms / 1000.0)
    seed = str(time.time_ns())
    while time.perf_counter() < deadline:
        seed = hashlib.sha256(seed.encode()).hexdigest()


@asynccontextmanager
async def lifespan(_: FastAPI):
    global _ready
    _ready = True
    yield
    _ready = False


app = FastAPI(title="Quote API", version="1.0.0", lifespan=lifespan)


@app.get("/healthz")
def healthz():
    REQUESTS_TOTAL.labels(method="GET", endpoint="/healthz", status="200").inc()
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    if not _ready:
        REQUESTS_TOTAL.labels(method="GET", endpoint="/readyz", status="503").inc()
        return Response(content='{"status":"not ready"}', status_code=503, media_type="application/json")
    REQUESTS_TOTAL.labels(method="GET", endpoint="/readyz", status="200").inc()
    return {"status": "ready"}


@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/api/quote")
def get_quote():
    _simulate_cpu_work(int(os.getenv("CPU_WORK_MS", "100")))
    quote = random.choice(QUOTES)
    REQUESTS_TOTAL.labels(method="GET", endpoint="/api/quote", status="200").inc()
    return quote
