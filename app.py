
import os
import sys
import uuid
import queue
import shutil
import tempfile
import threading
import subprocess
import time

from pathlib import Path
from flask import Flask, jsonify, request, send_from_directory
from asgiref.wsgi import WsgiToAsgi

app = Flask(__name__)
BASE_DIR = Path(__file__).resolve().parent

# Local development only; not a secure sandbox.
sessions = {}
sessions_lock = threading.Lock()


def read_stream(stream, stream_name, session):
    """Read output continuously, including prompts without newlines."""
    try:
        while True:
            chunk = os.read(stream.fileno(), 1024)
            if not chunk:
                break

            session["events"].put({
                "stream": stream_name,
                "text": chunk.decode("utf-8", errors="replace")
            })
    except (OSError, ValueError):
        pass
    finally:
        with session["lock"]:
            session["readers_remaining"] -= 1


def get_session(run_id):
    with sessions_lock:
        return sessions.get(run_id)


@app.route("/")
def home():
    return send_from_directory(BASE_DIR, "index.html")


@app.route("/api/health")
def health():
    return jsonify({"status": "success", "message": "PyStudio API is running"})


@app.route("/api/start", methods=["POST"])
def start_program():
    data = request.get_json(silent=True) or {}
    code = data.get("code", "")

    if not isinstance(code, str) or not code.strip():
        return jsonify({"error": "Please enter Python code."}), 400

    if len(code) > 10000:
        return jsonify({"error": "Code is too long."}), 400

    # Allow only one active program at a time for this local prototype.
    with sessions_lock:
        active = any(
            item["process"].poll() is None
            for item in sessions.values()
        )
        if active:
            return jsonify({
                "error": "A program is already running. Stop it first."
            }), 409

        temp_dir = tempfile.mkdtemp(prefix="pystudio_")
        script_path = Path(temp_dir) / "main.py"
        script_path.write_text(code, encoding="utf-8")

        try:
            process = subprocess.Popen(
                [sys.executable, "-u", "-I", str(script_path)],
                cwd=temp_dir,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                bufsize=0,
                env={
                    "PATH": os.environ.get("PATH", ""),
                    "PYTHONIOENCODING": "utf-8",
                    "PYTHONUNBUFFERED": "1"
                }
            )
        except Exception:
            shutil.rmtree(temp_dir, ignore_errors=True)
            app.logger.exception("Could not start Python process")
            return jsonify({"error": "Could not start Python."}), 500

        started_at = time.perf_counter()
        run_id = uuid.uuid4().hex
        session = {
            "process": process,
            "events": queue.Queue(),
            "lock": threading.Lock(),
            "readers_remaining": 2,
            "temp_dir": temp_dir,
            "started_at": started_at,
            "execution_time": None,
            "cleaned": False
        }
        sessions[run_id] = session

        for stream, name in (
            (process.stdout, "stdout"),
            (process.stderr, "stderr")
        ):
            threading.Thread(
                target=read_stream,
                args=(stream, name, session),
                daemon=True
            ).start()

        threading.Thread(
            target=watch_timeout,
            args=(session,),
            daemon=True
        ).start()

    return jsonify({"run_id": run_id, "status": "running"})


def watch_timeout(session):
    try:
        session["process"].wait(timeout=10)
    except subprocess.TimeoutExpired:
        session["process"].kill()
        session["events"].put({
            "stream": "stderr",
            "text": "\nExecution stopped: 10-second time limit reached.\n"
        })


@app.route("/api/input/<run_id>", methods=["POST"])
def send_input(run_id):
    session = get_session(run_id)
    if not session:
        return jsonify({"error": "Run session not found."}), 404

    data = request.get_json(silent=True) or {}
    value = data.get("input", "")

    if not isinstance(value, str) or len(value) > 10000:
        return jsonify({"error": "Invalid input."}), 400

    process = session["process"]

    try:
        if process.poll() is not None:
            return jsonify({"error": "Program has already finished."}), 409

        process.stdin.write((value + "\n").encode("utf-8"))
        process.stdin.flush()
        return jsonify({"status": "input sent"})
    except (BrokenPipeError, OSError, ValueError):
        return jsonify({"error": "Program is no longer accepting input."}), 409


@app.route("/api/poll/<run_id>")
def poll_output(run_id):
    session = get_session(run_id)
    if not session:
        return jsonify({"error": "Run session not found."}), 404

    events = []
    for _ in range(200):
        try:
            events.append(session["events"].get_nowait())
        except queue.Empty:
            break

    process = session["process"]
    done = (
    process.poll() is not None
    and session["readers_remaining"] == 0
)

    if done and session["execution_time"] is None:  
        session["execution_time"] = (
        time.perf_counter() - session["started_at"]
    )

    result = {
        "events": events,
        "done": done,
        "execution_time": session["execution_time"],
        "return_code": process.poll() if done else None
    }

    if done and not session["cleaned"]:
        with session["lock"]:
            if not session["cleaned"]:
                session["cleaned"] = True
                shutil.rmtree(session["temp_dir"], ignore_errors=True)
                try:
                    process.stdin.close()
                    process.stdout.close()
                    process.stderr.close()
                except OSError:
                    pass

    return jsonify(result)


@app.route("/api/stop/<run_id>", methods=["POST"])
def stop_program(run_id):
    session = get_session(run_id)
    if not session:
        return jsonify({"error": "Run session not found."}), 404

    process = session["process"]
    if process.poll() is None:
        process.kill()

    return jsonify({"status": "stopped"})


asgi_app = WsgiToAsgi(app)



@app.route("/style.css")
def styles():
    return send_from_directory(BASE_DIR, "style.css")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app:asgi_app",
        host="127.0.0.1",
        port=8000,
        reload=True
    )
