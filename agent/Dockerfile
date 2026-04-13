# Stage 1: Build the environment
FROM python:3.13-slim AS builder

WORKDIR /app

# Using --no-cache-dir to keep the image lean
RUN pip install --no-cache-dir uv

# Copy uv dependency files
COPY pyproject.toml uv.lock ./

# Install dependencies into the default .venv managed by uv
# We use --no-install-project so it only installs dependencies and doesn't look for README or source code yet
ENV UV_COMPILE_BYTECODE=1
RUN uv sync --no-install-project --no-dev --locked

# Stage 2: Runtime Environment
FROM python:3.13-slim

# Set recommended Python environment variables
# Note: we add /app/.venv/bin to the PATH since uv sync creates .venv automatically
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/app/.venv/bin:$PATH" \
    PORT=8080

WORKDIR /app

# Create a non-root user and group
RUN groupadd -r agentgroup && useradd -r -g agentgroup agentuser \
    && chown -R agentuser:agentgroup /app

# Copy the virtual environment from the builder stage
COPY --from=builder /app/.venv /app/.venv

# Copy the application source code
COPY --chown=agentuser:agentgroup . .

# Switch to the non-root user
USER agentuser

# Expose standard port for Cloud Run
EXPOSE 8080

# Specify the command to run the agent
# Using shell execution to evaluate the Cloud Run dynamic $PORT variable
# We must bind to 0.0.0.0 inside a container, not localhost
CMD sh -c "python __main__.py --host 0.0.0.0 --port ${PORT:-8080}"
