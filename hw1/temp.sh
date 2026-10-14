#!/bin/sh

guess_word='force'
feedback='ABBXX'

guess_list=$(cat /home/judge/nycusa/hw1/dictionary.txt)

i=1
while [ "$i" -le 5 ]; do
    status=$(printf '%s' "$feedback" | cut -c "$i")
    alphabet=$(printf '%s' "$guess_word" | cut -c "$i")

    case "$status" in
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

    printf 'Current list size:\n%s\n' "$guess_list" | wc -l
done

