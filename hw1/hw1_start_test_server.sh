#!/bin/sh

cd /home/judge/nycusa/hw1 || exit 1

if curl -fsS --max-time 2 http://127.0.0.1:8000/ 2>/dev/null |
    jq -e '.message == "Have fun to 2026 NYCU SA HW1!"' >/dev/null 2>&1; then
    printf '%s\n' 'Task server is already running at http://127.0.0.1:8000'
    exit 0
fi

if [ ! -x /home/judge/task-server-venv/bin/uvicorn ]; then
    python3 -m venv /home/judge/task-server-venv || exit 1
    /home/judge/task-server-venv/bin/pip install fastapi 'uvicorn[standard]' python-multipart || exit 1
fi

exec /home/judge/task-server-venv/bin/uvicorn main:app \
    --host 127.0.0.1 \
    --port 8000

