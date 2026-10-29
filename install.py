#!/usr/bin/env python3
"""
PyStudio cross-platform installer launcher.

Detects the OS, asks the user which platform to install for.
If the installer script (install.sh or install.ps1) is missing,
it automatically downloads it from GitHub before running.
"""

import os
import platform
import subprocess
import sys
import urllib.request

# ============================================================
#  GITHUB CONFIGURATION
# ============================================================
REPO_OWNER = "Codez-suriya"
REPO_NAME = "PyStudio"
BRANCH = "main"  # Change to "Windows" if your scripts are on a different branch


def detect_os() -> str:
    """Return 'windows', 'linux', or 'unknown'."""
    sysname = platform.system().lower()
    if sysname == "windows":
        return "windows"
    if sysname == "linux":
        return "linux"
    return "unknown"


def run(cmd, cwd=None):
    """Run a command, stream output, return exit code (integer)."""
    print(f"  > {' '.join(cmd)}")
    try:
        result = subprocess.run(cmd, cwd=cwd)
        return result.returncode
    except FileNotFoundError:
        print(f"  ERROR: Command not found: {cmd[0]}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"  ERROR: {e}", file=sys.stderr)
        return 1


def download_file(url, dest_path):
    """Download a file from the internet."""
    print(f"[*] Downloading {os.path.basename(dest_path)}...")
    try:
        urllib.request.urlretrieve(url, dest_path)
        print(f"[+] Downloaded successfully.")
    except Exception as e:
        print(f"  ERROR: Failed to download {url}", file=sys.stderr)
        print(f"  Details: {e}", file=sys.stderr)
        sys.exit(1)


def install_linux(script_dir: str) -> int:
    """Download (if needed) and run install.sh."""
    script = os.path.join(script_dir, "install.sh")
    
    if not os.path.isfile(script):
        url = f"https://raw.githubusercontent.com/{REPO_OWNER}/{REPO_NAME}/{BRANCH}/install.sh"
        download_file(url, script)
        
    # Ensure it's executable
    os.chmod(script, 0o755)
    
    print("[*] Starting Linux installation...")
    return run(["bash", "install.sh"], cwd=script_dir)


def install_windows(script_dir: str) -> int:
    """Download (if needed) and run install.ps1, then run.ps1."""
    install_script = os.path.join(script_dir, "install.ps1")
    run_script = os.path.join(script_dir, "run.ps1")

    # 1. Download install.ps1 if missing
    if not os.path.isfile(install_script):
        url = f"https://raw.githubusercontent.com/{REPO_OWNER}/{REPO_NAME}/{BRANCH}/install.ps1"
        download_file(url, install_script)

    # 2. Set Execution Policy (bypass for this session, no admin needed)
    print("[*] Setting execution policy for this session...")
    subprocess.run(
        ["powershell", "-NoProfile", "-Command", "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force"],
        check=False
    )

    # 3. Run install.ps1
    print("[*] Starting Windows installation...")
    rc = run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "install.ps1"], cwd=script_dir)
    
    if rc != 0:
        print(f"  ERROR: install.ps1 failed with code {rc}", file=sys.stderr)
        return rc

    # 4. Ask to launch (if run.ps1 was generated)
    if os.path.isfile(run_script):
        print("\n  Launch PyStudio now? [Y/n] ", end="")
        try:
            ans = input().strip().lower()
        except (EOFError, KeyboardInterrupt):
            ans = "n"
            
        if ans in ("", "y", "yes"):
            print("[*] Launching...")
            return run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "run.ps1"], cwd=script_dir)
        else:
            print("  Run it later with: .\\run.ps1")
    else:
        print("  run.ps1 not found; skipping launch.")
    
    return 0


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
            print("WARNING: selected Linux but the current OS is not Linux.", file=sys.stderr)
        return install_linux(script_dir)
    elif choice == "2":
        if detected != "windows":
            print("WARNING: selected Windows but the current OS is not Windows.", file=sys.stderr)
        return install_windows(script_dir)
    else:
        print("  Invalid choice. Enter 1 or 2.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())