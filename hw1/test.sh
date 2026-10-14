#!/bin/sh

server=http://127.0.0.1:8000
task_id=
task_type=WORDLE

usage() {
    printf '%s\n' 'Usage: test.sh [-t wordle|dont_wordle|word_500] [-h]'
}

while getopts ':t:h' opt; do
    case "$opt" in
        t) task_type=$(printf '%s' "$OPTARG" | tr '[:lower:]' '[:upper:]') ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
shift "$((OPTIND - 1))"
if [ "$#" -ne 0 ]; then
    usage >&2
    exit 2
fi
case "$task_type" in
    WORDLE | DONT_WORDLE | WORD_500) ;;
    *) usage >&2; exit 2 ;;
esac

payload=$(jq -n --arg type "$task_type" '{stuid: "0", type: $type}') || exit 1

clear_timeout_tasks() {
    timeout_list=$(curl -fsS "$server/tasks/stu/0") || return 1
    timeout_ids=$(printf '%s\n' "$timeout_list" | jq -er '.tasks | map(.id) | join("\n")') || return 1
    for timeout_id in $timeout_ids; do
        timeout_json=$(curl -fsS "$server/tasks/$timeout_id") || return 1
        if printf '%s\n' "$timeout_json" |
            jq -e '.stuid == "0" and .status == "TIMEOUT"' >/dev/null; then
            curl -fsS -X DELETE "$server/tasks/$timeout_id" >/dev/null || return 1
            printf 'Deleted timeout task: %s\n' "$timeout_id"
        fi
    done
}

cleanup() {
    if [ -n "$task_id" ]; then
        if curl -fsS -X DELETE "$server/tasks/$task_id" >/dev/null; then
            printf 'Deleted task: %s\n' "$task_id"
            task_id=
        else
            printf 'Could not delete task: %s\n' "$task_id" >&2
            return 1
        fi
    fi
    clear_timeout_tasks
}

trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

clear_timeout_tasks || exit 1

if task_json=$(curl -fsS \
    -H 'Content-Type: application/json' \
    --data "$payload" \
    "$server/tasks"); then
    task_id=$(printf '%s\n' "$task_json" | jq -er '.id | strings | select(length > 0)') || exit 1
else
    exit 1
fi

/home/judge/nycusa/hw1/hw1.sh -t "$task_type" -i "$task_id"
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

