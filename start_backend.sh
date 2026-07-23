#!/bin/bash
echo "Starting Sourcely Backend..."
cd backend
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
