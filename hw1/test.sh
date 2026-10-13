#!/bin/sh

server=http://127.0.0.1:8000
task_id=

cleanup() {
    if [ -n "$task_id" ]; then
        if curl -fsS -X DELETE "$server/tasks/$task_id" >/dev/null; then
            printf 'Deleted task: %s\n' "$task_id"
        else
            printf 'Could not delete task: %s\n' "$task_id" >&2
            return 1
        fi
    fi
}

trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

if task_json=$(curl -fsS \
    -H 'Content-Type: application/json' \
    --data '{"stuid":"0","type":"WORDLE"}' \
    "$server/tasks"); then
    task_id=$(printf '%s\n' "$task_json" | jq -er '.id | strings | select(length > 0)') || exit 1
else
    exit 1
fi

/home/judge/nycusa/hw1/hw1.sh -t WORDLE -i "$task_id"
result=$?
printf 'script exit status: %s\n' "$result"

if final_json=$(curl -fsS "$server/tasks/$task_id"); then
    printf '%s\n' "$final_json" | jq .
else
    exit 1
fi

cleanup || exit 1
task_id=
exit "$result"

