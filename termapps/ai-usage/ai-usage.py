import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time


CACHE_DIRECTORY = Path(
    os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))
) / "ai-usage"
CLAUDE_CACHE = CACHE_DIRECTORY / "claude-usage.json"
CODEX_CACHE = CACHE_DIRECTORY / "codex-usage.json"


def atomic_write(path: Path, value: object) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(value, stream, separators=(",", ":"))
            stream.write("\n")
        os.replace(temporary_name, path)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


def read_cache(path: Path) -> dict:
    try:
        with path.open(encoding="utf-8") as stream:
            value = json.load(stream)
            return value if isinstance(value, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return {}


def sanitize_limit(value: object) -> dict | None:
    if not isinstance(value, dict):
        return None
    used = value.get("used_percentage")
    reset = value.get("resets_at")
    if not isinstance(used, (int, float)):
        return None
    return {
        "usedPercent": round(float(used), 1),
        "resetsAt": reset if isinstance(reset, str) else None,
    }


def cache_claude_statusline() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return 1

    limits = payload.get("rate_limits")
    if isinstance(limits, dict):
        sanitized = {
            name: limit
            for name in ("five_hour", "seven_day", "seven_day_sonnet", "seven_day_opus")
            if (limit := sanitize_limit(limits.get(name))) is not None
        }
        if sanitized:
            atomic_write(
                CLAUDE_CACHE,
                {
                    "available": True,
                    "updatedAt": int(time.time()),
                    "limits": sanitized,
                },
            )

    model = payload.get("model", {})
    model_name = model.get("display_name", "Claude") if isinstance(model, dict) else "Claude"
    current_directory = payload.get("workspace", {}).get("current_dir", "")
    directory_name = Path(current_directory).name if current_directory else ""
    five_hour = sanitize_limit(limits.get("five_hour")) if isinstance(limits, dict) else None
    usage = f" · 5h {five_hour['usedPercent']:.0f}%" if five_hour else ""
    location = f" · {directory_name}" if directory_name else ""
    print(f"{model_name}{location}{usage}")
    return 0


def read_response(process: subprocess.Popen, request_id: int, timeout: float) -> dict:
    deadline = time.monotonic() + timeout
    while process.poll() is None:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        readable, _, _ = select.select([process.stdout], [], [], remaining)
        if not readable:
            break
        line = process.stdout.readline()
        if not line:
            break
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        if message.get("id") == request_id:
            return message
    raise TimeoutError(f"Codex app-server did not answer request {request_id}")


def send(process: subprocess.Popen, value: object) -> None:
    process.stdin.write(json.dumps(value, separators=(",", ":")) + "\n")
    process.stdin.flush()


def fetch_codex() -> dict:
    process = subprocess.Popen(
        ["codex", "app-server"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,
    )
    try:
        send(
            process,
            {
                "method": "initialize",
                "id": 1,
                "params": {
                    "clientInfo": {
                        "name": "ai-usage",
                        "title": "Jaca status bar",
                        "version": "0.1.0",
                    }
                },
            },
        )
        initialized = read_response(process, 1, 5)
        if "error" in initialized:
            raise RuntimeError(initialized["error"])

        send(process, {"method": "initialized", "params": {}})
        send(process, {"method": "account/rateLimits/read", "id": 2, "params": {}})
        response = read_response(process, 2, 8)
        if "error" in response:
            raise RuntimeError(response["error"])

        result = response.get("result", {})
        rate_limits = result.get("rateLimits")
        if not isinstance(rate_limits, dict):
            raise RuntimeError("Codex did not return rate limits")

        reset_credits = result.get("rateLimitResetCredits")
        available_resets = (
            reset_credits.get("availableCount") if isinstance(reset_credits, dict) else None
        )

        value = {
            "available": True,
            "updatedAt": int(time.time()),
            "planType": rate_limits.get("planType"),
            "limitName": rate_limits.get("limitName"),
            "primary": rate_limits.get("primary"),
            "secondary": rate_limits.get("secondary"),
            "credits": rate_limits.get("credits"),
            "spendControlReached": rate_limits.get("spendControlReached", False),
            "availableResetCredits": available_resets,
        }
        atomic_write(CODEX_CACHE, value)
        return value
    finally:
        process.terminate()
        try:
            process.wait(timeout=1)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def show() -> int:
    previous_codex = read_cache(CODEX_CACHE)
    try:
        codex = fetch_codex()
    except (OSError, RuntimeError, TimeoutError, subprocess.SubprocessError):
        codex = previous_codex or {"available": False}
        codex["stale"] = bool(previous_codex)

    claude = read_cache(CLAUDE_CACHE) or {"available": False}
    print(json.dumps({"codex": codex, "claude": claude}, separators=(",", ":")))
    return 0


def main() -> int:
    if len(sys.argv) != 2:
        print("uso: ai-usage <show|claude-statusline>", file=sys.stderr)
        return 2
    if sys.argv[1] == "show":
        return show()
    if sys.argv[1] == "claude-statusline":
        return cache_claude_statusline()
    print(f"ação desconhecida: {sys.argv[1]}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
