# Build frontend
FROM node:14 as frontend-build
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./
RUN npm run build

# Build backend
FROM python:3.12 as backend-build
WORKDIR /app/backend
RUN pip install --upgrade pip && pip install poetry
COPY backend/pyproject.toml backend/poetry.lock ./
RUN poetry config virtualenvs.create false \
    && poetry install --no-dev --no-interaction --no-ansi
COPY backend/ ./

# Final image
FROM python:3.12-slim
WORKDIR /app

# Install Nginx and required system libraries
RUN apt-get update && apt-get install -y nginx \
    && rm -rf /var/lib/apt/lists/*

# Copy backend from backend-build stage
COPY --from=backend-build /app/backend /app/backend
COPY --from=backend-build /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=backend-build /usr/local/bin /usr/local/bin

# Copy frontend build from frontend-build stage
COPY --from=frontend-build /app/frontend/build /app/frontend/build

# Configure Nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Ensure correct permissions for Nginx
RUN chown -R www-data:www-data /app/frontend/build

EXPOSE 8080

# Start Nginx and the backend server
CMD service nginx start && cd /app/backend && uvicorn app.main:app --host 0.0.0.0 --port 8000
