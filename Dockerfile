FROM python:3.10-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    pkg-config \
    libx11-dev \
    libatlas-base-dev \
    libgtk-3-dev \
    libboost-python-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install
COPY backend/requirements.txt ./backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

# Copy the backend code and AI model
COPY backend/ ./backend/
COPY lib/ai/ ./lib/ai/

# Change to backend directory to run the server
WORKDIR /app/backend

# Run the app with gunicorn
CMD gunicorn --bind 0.0.0.0:${PORT:-5000} --workers 1 --timeout 120 server:app
