#!/usr/bin/env python3
"""
PyStudio cross-platform installer launcher.

Detects the OS, asks the user which platform to install for,
then invokes the matching install script and optionally launches run.ps1.

Linux  -> runs install.sh (expects bash)
Windows -> sets execution policy for current user, runs install.ps1, then run.ps1
"""

import os
import platform
import subprocess
import sys


def detect_os() -> str:
    """Return 'windows', 'linux', or 'unknown'."""
    sysname = platform.system().lower()
    if sysname == "windows":
        return "windows"
    if sysname == "linux":
        return "linux"
    return "unknown"


def run(cmd, cwd=None, check=False):
    """Run a command, stream output, return CompletedProcess."""
    print(f"  > {' '.join(cmd)}")
    return subprocess.run(cmd, cwd=cwd, check=check)


def install_linux(script_dir: str) -> int:
    """Run install.sh via bash."""
    script = os.path.join(script_dir, "install.sh")
    if not os.path.isfile(script):
        print(f"ERROR: install.sh not found in {script_dir}", file=sys.stderr)
        return 1
    # bash is the expected interpreter on Linux
    return run(["bash", script], cwd=script_dir).returncode


def install_windows(script_dir: str) -> int:
    """Set execution policy, run install.ps1, then optionally run.ps1."""
    install_ps1 = os.path.join(script_dir, "install.ps1")
    if not os.path.isfile(install_ps1):
        print(f"ERROR: install.ps1 not found in {script_dir}", file=sys.stderr)
        return 1

    # 1. Allow local scripts for the current user (does not require admin).
    #    RemoteSigned permits locally-created scripts while still requiring
    #    signatures for scripts downloaded from the internet.
    print("[*] Setting execution policy to RemoteSigned for CurrentUser...")
    policy_cmd = [
        "powershell",
        "-NoProfile",
        "-Command",
        "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force",
    ]
    r = subprocess.run(policy_cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print("WARNING: could not set execution policy.", file=sys.stderr)
        print(r.stderr, file=sys.stderr)
        print("Continuing with -ExecutionPolicy Bypass for this run only...",
              file=sys.stderr)

    # 2. Run install.ps1 with -File so the path is passed correctly even with spaces.
    #    -NoProfile avoids user profile side effects.
    print("[*] Running install.ps1...")
    install_cmd = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", install_ps1,
    ]
    rc = run(install_cmd, cwd=script_dir).returncode
    if rc != 0:
        print(f"ERROR: install.ps1 exited with code {rc}", file=sys.stderr)
        return rc

    # 3. Offer to run run.ps1. install.ps1 itself already asks,
    #    but this gives the Python wrapper a final say and covers the
    #    case where the user declined inside install.ps1.
    # run_ps1 = os.path.join(script_dir, "run.ps1")
    # if os.path.isfile(run_ps1):
    #     answer = input("\n  Launch PyStudio now? [Y/n] ").strip().lower()
    #     if answer in ("", "y", "yes"):
    #         print("[*] Running run.ps1...")
    #         run_cmd = [
    #             "powershell",
    #             "-NoProfile",
    #             "-ExecutionPolicy", "Bypass",
    #             "-File", run_ps1,
    #         ]
    #         return run(run_cmd, cwd=script_dir).returncode
    #     else:
    #         print("  Run it later with: .\\run.ps1")
    # else:
    #     print("  run.ps1 not found; skipping launch.")

    # return 0


def main() -> int:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    detected = detect_os()

    print("")
    print("  PyStudio installer")
    print("  ------------------")
    print(f"  Detected platform: {platform.system()} ({platform.machine()})")
    print("")
    print("  Select target platform:")
    print("    1) Linux")
    print("    2) Windows")
    print("")

    try:
        choice = input("  Enter 1 or 2: ").strip()
    except (EOFError, KeyboardInterrupt):
        print("\n  Cancelled.")
        return 1

    if choice == "1":
        if detected != "linux":
            print("WARNING: selected Linux but the current OS is not Linux.",
                  file=sys.stderr)
        return install_linux(script_dir)
    elif choice == "2":
        if detected != "windows":
            print("WARNING: selected Windows but the current OS is not Windows.",
                  file=sys.stderr)
        return install_windows(script_dir)
    else:
        print("  Invalid choice. Enter 1 or 2.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())