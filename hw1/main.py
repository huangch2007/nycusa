from fastapi import FastAPI, HTTPException, Request, UploadFile, File, Form
from pydantic import BaseModel
import uuid
import random
from typing import Dict
from datetime import datetime, timedelta
from fastapi.responses import FileResponse
import os

WORDLE_GUESS_LIMIT = 10
DONT_WORDLE_GUESS_LIMIT = 5
WORD_500_GUESS_LIMIT = 10

app = FastAPI()

tasks_db: Dict[str, dict] = {}
answer_db: Dict[str, dict] = {}
task_time: Dict[str, datetime] = {}

dont_wordle_guess: Dict[str, list[dict]] = {}


class CreateTaskRequest(BaseModel):
    stuid: str
    type: str


class SubmitTaskRequest(BaseModel):
    answer: str


with open("dictionary.txt", "r") as f:
    lines = [line.strip() for line in f]


def check(answer: str, target: str) -> str:
    result_list = ["X"] * 5
    target_counts: Dict[str, int] = {}

    for character in target:
        target_counts[character] = target_counts.get(character, 0) + 1

    for i in range(5):
        if answer[i] == target[i]:
            result_list[i] = "A"
            target_counts[answer[i]] -= 1

    for i in range(5):
        if result_list[i] == "A":
            continue

        character = answer[i]
        if target_counts.get(character, 0) > 0:
            result_list[i] = "B"
            target_counts[character] -= 1

    result = "".join(result_list)
    return result


def generate_timeout_task(stuid):
    task_id = str(uuid.uuid4())
    random_type = random.choice(["WORDLE", "DONT_WORDLE"])
    task = {
        "stuid": stuid,
        "type": random_type,
        "id": task_id,
        "status": "TIMEOUT",
        "guess": "0",
    }

    answer_task = {}
    if random_type in {"WORDLE", "DONT_WORDLE"}:
        task["problem"] = "XXXXX"
        random_prob = random.randint(0, len(lines) - 1)
        answer_task["problem"] = lines[random_prob]

    tasks_db[task_id] = task
    answer_db[task_id] = answer_task
    task_time[task_id] = datetime.now() - timedelta(minutes=2)
    if random_type == "DONT_WORDLE":
        dont_wordle_guess[task_id] = []

    # stu_tasks[stuid] = stu_tasks.get(stuid, 0) + 1

    return


def check_dont_wordle_guess_validation(guess: str, task_id: str):
    history = dont_wordle_guess.get(task_id, [])

    for record in history:
        old_guess = record["guess"]
        old_result = record["result"]

        if check(old_guess, guess) != old_result:
            return False

    return True


def has_available_dont_wordle_guess(task_id: str):
    guessed_words = {record["guess"] for record in dont_wordle_guess.get(task_id, [])}
    target_word = answer_db[task_id]["problem"]

    for word in lines:
        if (
            word != target_word
            and word not in guessed_words
            and check_dont_wordle_guess_validation(word, task_id)
        ):
            return True

    return False


def mark_timeout(task_id: str):
    task = tasks_db.get(task_id)
    if task and task["status"] == "PENDING":
        if datetime.now() >= task_time[task_id] + timedelta(seconds=10):
            task["status"] = "TIMEOUT"


def get_stu_tasks(stuid: str):
    count = 0
    for task in tasks_db.values():
        if task["stuid"] == stuid:
            count += 1

    return count


@app.get("/")
def welcome():
    return {"message": "Have fun to 2026 NYCU SA HW1!"}


@app.post("/file")
def upload_files(
    req: Request, userfilename: str = Form(...), file: UploadFile = File(...)
):
    client_host = req.client.host
    ip_parts = [int(part) for part in client_host.split(".")]
    stuid = str((ip_parts[2] * 16) + (ip_parts[3] // 16))

    ip_filename = userfilename.replace(".", "_")
    # print("User upload files from ", ip_parts)

    if ip_parts[0] == 10 and ip_parts[1] == 1 and ip_parts[2] == 14:
        os.makedirs("uploads", exist_ok=True)
        file_name = ip_filename + "-" + datetime.now().strftime("%Y%m%d_%H%M")
        file_location = f"uploads/{file_name}"
        with open(file_location, "wb") as f:
            f.write(file.file.read())

        return {"info": f"file '{file_name}' saved"}
    else:
        raise HTTPException(status_code=400, detail="Invalid user")


@app.get("/dictionary")
def download_dictionary():
    return FileResponse(
        "dictionary.txt", media_type="text/plain", filename="dictionary.txt"
    )


@app.post("/tasks")
def create_task(req: CreateTaskRequest, request: Request):
    task_id = str(uuid.uuid4())
    task_type = req.type.upper()
    base_task = {
        "stuid": req.stuid,
        "type": task_type,
        "id": task_id,
        "status": "PENDING",
        "guess": "0",
    }

    client_host = request.client.host
    ip_parts = [int(part) for part in client_host.split(".")]
    stuid_int = int((ip_parts[2] * 16) + (ip_parts[3] // 16))

    if ip_parts[0] == 10 and ip_parts[1] == 1:
        stuid_int = int(req.stuid)
    if str(stuid_int) != req.stuid:
        with open("invalid.log", "a") as f:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            f.write(f"[{timestamp}] IP: {client_host} | Create {req.stuid}'s task\n")
        raise HTTPException(status_code=400, detail="Invalid student ID")

    if task_type not in {"WORDLE", "DONT_WORDLE", "WORD_500"}:
        raise HTTPException(status_code=400, detail="Invalid type")
    if get_stu_tasks(req.stuid) >= 5:
        print("Create too many tasks.")
        raise HTTPException(status_code=400, detail="Too many tasks created")

    answer_task = {}
    if task_type in {"WORDLE", "DONT_WORDLE"}:
        random_prob = random.randint(0, len(lines) - 1)
        base_task["problem"] = "XXXXX"
        answer_task["problem"] = lines[random_prob]
    elif task_type == "WORD_500":
        random_prob = random.randint(0, len(lines) - 1)
        base_task["problem"] = "005"
        answer_task["problem"] = lines[random_prob]
    tasks_db[task_id] = base_task
    answer_db[task_id] = answer_task
    task_time[task_id] = datetime.now()
    if task_type == "DONT_WORDLE":
        dont_wordle_guess[task_id] = []

    random_prob = random.randint(1, 100)
    random_timeout = random.randint(1, 5)
    if random_prob > 70:
        with open("random.log", "a") as f:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            f.write(
                f"[{timestamp}] Student ID: {client_host} | Random generated timeout {str(random_timeout)} tasks\n"
            )
        for i in range(random_timeout):
            generate_timeout_task(req.stuid)

    return base_task


@app.post("/tasks/{task_id}/submit")
def submit_task(task_id: str, req: SubmitTaskRequest, request: Request):
    task = tasks_db.get(task_id)
    client_host = request.client.host
    ip_parts = [int(part) for part in client_host.split(".")]
    stuid_int = int((ip_parts[2] * 16) + (ip_parts[3] // 16))

    if not task:
        with open("nonetask.log", "a") as f:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            f.write(
                f"[{timestamp}] IP: {client_host} | Submit not exist task {task_id}\n"
            )
        raise HTTPException(status_code=404, detail="Task not found")

    if ip_parts[0] == 10 and ip_parts[1] == 1:
        stuid_int = int(task["stuid"])
    if str(stuid_int) != task["stuid"]:
        with open("invalid.log", "a") as f:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            f.write(
                f"[{timestamp}] IP: {client_host} | Submit {task['stuid']}'s task {task_id}\n"
            )
        raise HTTPException(status_code=400, detail="Invalid student ID")

    mark_timeout(task_id)
    if task["status"] == "TIMEOUT":
        return {"error": "Task timed out"}

    answer = req.answer.lower()
    target = answer_db[task_id]

    if (
        task["type"] == "WORDLE"
        and len(answer) == 5
        and task["status"] == "PENDING"
        and int(task["guess"]) < WORDLE_GUESS_LIMIT
    ):
        feedback = check(answer, target["problem"])

        task["problem"] = feedback
        task["guess"] = str(int(task["guess"]) + 1)
        if feedback == "AAAAA":
            task["status"] = "SOLVED"
        elif int(task["guess"]) >= WORDLE_GUESS_LIMIT:
            task["status"] = "FAILED"

        return {"problem": feedback}

    elif (
        task["type"] == "DONT_WORDLE"
        and len(answer) == 5
        and task["status"] == "PENDING"
        and int(task["guess"]) < DONT_WORDLE_GUESS_LIMIT
    ):
        if not check_dont_wordle_guess_validation(answer, task_id):
            return {"error": "The guess does not satisfy previous feedback."}

        feedback = check(answer, target["problem"])

        dont_wordle_guess[task_id].append({"guess": answer, "result": feedback})
        task["problem"] = feedback
        task["guess"] = str(int(task["guess"]) + 1)

        if feedback == "AAAAA":
            task["status"] = "FAILED"
        elif int(task["guess"]) >= DONT_WORDLE_GUESS_LIMIT:
            task["status"] = "SOLVED"
        elif not has_available_dont_wordle_guess(task_id):
            task["status"] = "FAILED"

        return {"problem": feedback}

    elif (
        task["type"] == "WORD_500"
        and len(answer) == 5
        and task["status"] == "PENDING"
        and int(task["guess"]) < WORD_500_GUESS_LIMIT
    ):
        check_result = check(answer, target["problem"])
        feedback = "".join(str(check_result.count(value)) for value in "ABX")
        task["problem"] = feedback
        task["guess"] = str(int(task["guess"]) + 1)

        if feedback == "500":
            task["status"] = "SOLVED"
        elif int(task["guess"]) >= WORD_500_GUESS_LIMIT:
            task["status"] = "FAILED"

        return {"problem": feedback}
    else:
        # print(task)
        # print("answer:", answer)
        return {"error": "ERROR message"}


@app.get("/tasks/{task_id}")
def get_task(task_id: str, request: Request):
    task = tasks_db.get(task_id)
    client_host = request.client.host
    ip_parts = [int(part) for part in client_host.split(".")]
    stuid_int = int((ip_parts[2] * 16) + (ip_parts[3] // 16))

    if not task:
        with open("nonetask.log", "a") as f:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            f.write(
                f"[{timestamp}] IP: {client_host} | Requesting not exist task {task_id}\n"
            )
        raise HTTPException(status_code=404, detail="Task not found")

    if ip_parts[0] == 10 and ip_parts[1] == 1 and ip_parts[2] == 14:
        stuid_int = int(task["stuid"])

    if ip_parts[0] == 10 and ip_parts[1] == 1:
        stuid_int = int(task["stuid"])
    if str(stuid_int) != task["stuid"]:
        with open("invalid.log", "a") as f:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            f.write(
                f"[{timestamp}] IP: {client_host} | Requesting {task['stuid']}'s task {task_id}\n"
            )
        raise HTTPException(status_code=400, detail="Invalid student ID")

    mark_timeout(task_id)

    return task


@app.delete("/tasks/{task_id}")
def delete_task(task_id: str, request: Request):
    task = tasks_db.get(task_id)
    client_host = request.client.host
    ip_parts = [int(part) for part in client_host.split(".")]
    stuid_int = int((ip_parts[2] * 16) + (ip_parts[3] // 16))

    if not task:
        with open("nonetask.log", "a") as f:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            f.write(
                f"[{timestamp}] IP: {client_host} | Delete not exist task {task_id}\n"
            )
        raise HTTPException(status_code=404, detail="Task not found")

    if ip_parts[0] == 10 and ip_parts[1] == 1:
        stuid_int = int(task["stuid"])
    if str(stuid_int) != task["stuid"]:
        with open("invalid.log", "a") as f:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            f.write(
                f"[{timestamp}] IP: {client_host} | Delete {task['stuid']}'s task {task_id}\n"
            )
        raise HTTPException(status_code=400, detail="Invalid student ID")

    dont_wordle_guess.pop(task_id, None)
    del tasks_db[task_id]
    del answer_db[task_id]
    del task_time[task_id]
    # stu_tasks[task["stuid"]] = stu_tasks.get((task["stuid"]), 0) - 1

    return task


@app.get("/tasks/stu/{stuid}")
def get_tasks_for_student(stuid: str, request: Request):
    client_host = request.client.host
    ip_parts = [int(part) for part in client_host.split(".")]
    stuid_int = int((ip_parts[2] * 16) + (ip_parts[3] // 16))

    if ip_parts[0] == 10 and ip_parts[1] == 1:
        stuid_int = int(stuid)
    if str(stuid_int) != stuid:
        with open("invalid.log", "a") as f:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            f.write(
                f"[{timestamp}] IP: {client_host} | Requesting {stuid}'s tasks set\n"
            )
        raise HTTPException(status_code=400, detail="Invalid student ID")

    result = []
    for t in tasks_db.values():
        if t["stuid"] == stuid:
            result.append({"id": t["id"], "type": t["type"]})
    return {"stuid": stuid, "tasks": result}

