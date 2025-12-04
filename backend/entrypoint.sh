#!/bin/sh
echo "Waiting for postgres..."
set -e  # Exit ngay nếu bất kỳ lệnh nào thất bại

# Graceful shutdown handler
trap 'echo "Received shutdown signal, exiting gracefully..."; exit 0' SIGTERM SIGINT

# Thêm timeout để tránh loop vô hạn (ví dụ: 60 giây)
counter=0
while ! nc -z $DB_URL $DB_PORT; do
    sleep 0.1
    counter=$((counter + 1))
    if [ $counter -ge 600 ]; then  # 600 * 0.1s = 60s
        echo "Timeout: Không thể kết nối PostgreSQL sau 60 giây."
        exit 1
    fi
done
echo "PostgreSQL started"

# Chạy setup_db với error handling
echo "Setting up database..."
python manage.py recreate_db || {
    echo "Error: Failed to recreate database"
    exit 1
}

python manage.py seed_db || {
    echo "Error: Failed to seed database"
    exit 1
}

echo "Starting Flask application..."
# Start gunicorn with graceful shutdown
exec gunicorn -b 0.0.0.0:$PORT --timeout 120 --workers 2 --preload manage:app