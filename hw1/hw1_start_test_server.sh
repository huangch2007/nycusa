#!/bin/sh

cd /home/judge/nycusa/hw1 || exit 1

python3 -m venv /home/judge/task-server-venv
/home/judge/task-server-venv/bin/pip install fastapi 'uvicorn[standard]' python-multipart

/home/judge/task-server-venv/bin/uvicorn main:app \
    --host 127.0.0.1 \
    --port 8000

