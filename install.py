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
    """Ask for parent directory, create PyStudio folder, and run the installer."""

    default_parent = os.path.join(os.path.expanduser("~"), "Downloads")

    print("\n  PyStudio Windows Installer")
    print("-----------------------------")
    
    try:
        user_path = input(
            f"\nEnter the parent directory to install PyStudio\n"
            f"(press Enter for default: {default_parent}): "
        ).strip()
    except (EOFError, KeyboardInterrupt):
        print("\nInstallation cancelled.")
        return 1

    # 1. Validate the user-provided parent directory.
    if user_path:
        parent_dir = os.path.abspath(
            os.path.expandvars(os.path.expanduser(user_path))
        )
        
        if not os.path.isdir(parent_dir):
            print(f"\n[!] Path does not exist: {parent_dir}")
            print(f"[*] Falling back to default: {default_parent}")
            parent_dir = default_parent
    else:
        parent_dir = default_parent

    # 2. Create the 'PyStudio' folder inside the parent directory.
    install_dir = os.path.join(parent_dir, "PyStudio")
    
    try:
        os.makedirs(install_dir, exist_ok=True)
    except OSError as e:
        print(f"\n[ERROR] Cannot create PyStudio folder in '{parent_dir}': {e}", file=sys.stderr)
        return 1

    print(f"\n[*] Installing into: {install_dir}")

    install_script = os.path.join(install_dir, "install.ps1")
    run_script = os.path.join(install_dir, "run.bat") # <-- Updated to run.bat

    # 3. Download install.ps1 into the PyStudio folder
    url = (
        f"https://raw.githubusercontent.com/"
        f"{REPO_OWNER}/{REPO_NAME}/{BRANCH}/install.ps1"
    )

    print("[*] Downloading install.ps1...")
    try:
        download_file(url, install_script)
    except Exception as e:
        print(f"[ERROR] Download failed: {e}", file=sys.stderr)
        return 1

    # 4. Execute install.ps1
    print("[*] Starting Windows installation...")
    rc = run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            install_script,
            "-InstallDir",
            install_dir  # Pass the specific PyStudio folder
        ],
        cwd=install_dir
    )

    if rc != 0:
        print(f"\n[ERROR] install.ps1 failed with code {rc}", file=sys.stderr)
        return rc

    # 5. Ask whether to launch PyStudio
    if os.path.isfile(run_script):
        try:
            ans = input("\nLaunch PyStudio now? [Y/n] ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            ans = "n"

        if ans in ("", "y", "yes"):
            print("[*] Launching PyStudio...")
            return run(["cmd", "/c", "run.bat"], cwd=install_dir)
        else:
            print(f"Run it later by double-clicking:\n  {run_script}")
    else:
        print("[!] run.bat not found; skipping launch.")

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
