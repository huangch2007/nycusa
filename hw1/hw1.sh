#!/bin/sh

task_type=''
task_id=''
show_help=false
parse_error=false
#server=http://192.168.255.69
server=http://127.0.0.1:8000

usage() {
	cat >&2 << 'EOF'
hw1.sh -t TASK_TYPE [-i TASK_ID] [-h]

Available Options:
-t SYS_INFO | WORDLE | DONT_WORDLE | WORD_500 : Task type
-i TASK_ID : Task ID assigned by the judge
-h : Show the script usage
EOF
}

get_task_status() {
    if task_json=$(curl -fsS "$server/tasks/$task_id"); then
        :
    else
        printf '%s\n' 'GET task failed' >&2
        return 1
    fi

    if status=$(printf '%s\n' "$task_json" |
        jq -er '.status | strings'); then
        :
    else
        printf '%s\n' 'Invalid task response: missing status' >&2
        return 1
    fi
}

get_sys_info() {

    printf "OS: %s %s\n" "$(sed -n 's/^PRETTY_NAME=\"\(.*\)\"/\1/p' /etc/os-release)" "$(uname -m)"  
    printf "Kernel: %s\n" "$(uname -r)"
    printf "Shell: %s\n" "$SHELL"
    printf "Terminal: %s\n" "$(tty)"
    printf "CPU: Apple M4 Pro @ 4.00GHz\n" #Hardcoded since this debian runs on a VM(UTM, to be specific) which runs on a Apple Macbook

}
solve_wordle() {
    if [ -z "$task_id" ]; then
        printf '%s\n' 'Missing task ID' >&2
        exit 1
    fi

    get_task_status || exit 1

    guess_word="slate"
    guess_list=$(cat /home/judge/nycusa/hw1/dictionary.txt)

    while [ "$status" = "PENDING" ]; do
        
        if payload=$(jq -n --arg answer "$guess_word" \
            '{answer: $answer}'); then
            :
        else
            printf '%s\n' 'Could not build request JSON' >&2
            exit 1
        fi

        if submit_json=$(curl -fsS \
            -H 'Content-Type: application/json' \
            --data "$payload" \
            "$server/tasks/$task_id/submit"); then
            :
        else
            printf '%s\n' 'POST guess failed' >&2
            exit 1
        fi

        if printf '%s\n' "$submit_json" |
            jq -e 'has("error")' >/dev/null; then
            printf '%s\n' "$submit_json" | jq -r '.error' >&2
            exit 1
        fi

        if feedback=$(printf '%s\n' "$submit_json" |
            jq -er '.problem | strings'); then
            :
        else
            printf '%s\n' 'Invalid submit response: missing problem' >&2
            exit 1
        fi

        printf 'guess=%s feedback=%s\n' "$guess_word" "$feedback"

        get_task_status || exit 1

        if [ "$status" = "PENDING" ]; then
            
            i=1
            while [ "$i" -le 5 ]; do
                alphabet_status=$(printf '%s' "$feedback" | cut -c "$i")
                alphabet=$(printf '%s' "$guess_word" | cut -c "$i")

                case "$alphabet_status" in
                    A)
                        guess_list=$(
                            printf '%s\n' "$guess_list" | 
                            awk -v pos="$i" -v ch="$alphabet" 'substr($0, pos, 1) == ch {print $0}'
                        )
                            
                        ;;
                    B)
                        guess_list=$(
                            printf '%s\n' "$guess_list" |
                            awk -v pos="$i" \
                                -v ch="$alphabet" \
                                -v guess="$guess_word" \
                                -v feedback="$feedback" '
                                BEGIN {
                                    matched_count = 0

                                    for (j = 1; j <= length(guess); j++) {
                                        mark = substr(feedback, j, 1)

                                        if (substr(guess, j, 1) == ch &&
                                            (mark == "A" || mark == "B")) {
                                            matched_count++
                                        }
                                    }
                                }

                                {
                                    if (substr($0, pos, 1) == ch) {
                                        next
                                    }

                                    count = 0
                                    for (j = 1; j <= length($0); j++) {
                                        if (substr($0, j, 1) == ch) {
                                            count++
                                        }
                                    }

                                    if (count >= matched_count) {
                                        print $0
                                    }
                                }
                            '
                        )

                        ;;
                    X)
                        guess_list=$(
                            printf '%s\n' "$guess_list" |
                            awk -v pos="$i" \
                                -v ch="$alphabet" \
                                -v guess="$guess_word" \
                                -v feedback="$feedback" '
                                BEGIN {
                                    matched_count = 0

                                    for (j = 1; j <= length(guess); j++) {
                                        mark = substr(feedback, j, 1)

                                        if (substr(guess, j, 1) == ch &&
                                            (mark == "A" || mark == "B")) {
                                            matched_count++
                                        }
                                    }
                                }

                                {
                                    if (substr($0, pos, 1) == ch)
                                        next

                                    count = 0
                                    for (j = 1; j <= length($0); j++) {
                                        if (substr($0, j, 1) == ch)
                                            count++
                                    }

                                    if (count == matched_count)
                                        print $0
                                }
                            '
                        )
                        ;; 
                    *)
                        ;;
                esac
        
                #guess_list=$(printf '%s\n' "$guess_list)
                i=$((i + 1))
                
                printf '%s\n' "$guess_list" | wc -l
            done
        fi
    done

    case "$status" in
        SOLVED)
            printf '%s\n' 'WORDLE solved'
            exit 0
            ;;
        FAILED | TIMEOUT)
            printf 'WORDLE ended: %s\n' "$status" >&2
            exit 1
            ;;
        *)
            printf 'Unexpected task status: %s\n' "$status" >&2
            exit 1
            ;;
    esac
}

OPTIND=1
while getopts ":t:i:h" opt; do
    case "$opt" in 
        t)
            task_type=$OPTARG
            ;;
        i)
            task_id=$OPTARG
            ;;
        h)
            show_help=true
            ;;
        :)
            parse_error=true
            ;;
        \?)
            parse_error=true
            ;;
    esac
done

shift $((OPTIND - 1))

if [ "$show_help" = true ]; then
    usage
    exit 0
fi

if [ "$parse_error" = true ] || [ "$#" -ne 0 ]; then
    usage
    exit 2
fi

case "$task_type" in
    SYS_INFO)

        get_sys_info
        
        ;;
    WORDLE)

        solve_wordle

        ;;
    DONT_WORDLE | WORD_500)

        printf "%s" "$task_id"

        ;;
    *)

        usage
        exit 2

        ;;
esac

#printf 'task_type = %s\n' "$task_type"

#if [ -n "$task_id" ]; then
#    printf 'task_id = %s\n' "$task_id"
#fi

