# Dockerfile
FROM python:3.11-slim

# Create and switch to /app directory
WORKDIR /app

# Copy requirements and install
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the app code
COPY app/ .

# Ensure /app is owned by a non-root user (optional)
RUN useradd --create-home flaskuser && chown -R flaskuser /app
USER flaskuser

# Expose the port and run via gunicorn
EXPOSE 5000
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "main:app"]