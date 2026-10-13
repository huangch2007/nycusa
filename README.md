# NYCU SA homework

作業依 `hw1/`、`hw2/`、`hw3/` 分開保存。

## HW1

- `hw1/hw1.sh`：目前的作業腳本（開發中，server 指向本地 `127.0.0.1:8000`）。
- `hw1/test.sh`：建立 WORDLE task、呼叫腳本、檢查結果並清除本次 task。
- `hw1/temp.sh`：候選字篩選實驗。
- `hw1/main.py`、`hw1/Dockerfile`：TA 提供的本地 task server。
- `hw1/dictionary.txt`：task server 使用的字典。
- `hw1/hw1_start_test_server.sh`：啟動本地 server。

SAVM 的 repo 路徑是 `/home/judge/nycusa`。`/home/judge/hw1.sh` 保留為
指向 `hw1/hw1.sh` 的 symbolic link，讓 judge 可以使用原本要求的入口。
字典與測試腳本使用這個部署位置的絕對路徑。

Python venv 位於 `/home/judge/task-server-venv`，不納入 Git。
正式評測前需將作業腳本的 server 改回 `http://192.168.255.69`。
