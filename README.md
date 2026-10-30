# PyStudio

<div align="center">

**A browser-based Python interpreter that runs entirely on your machine.**

Write Python · Run it instantly · No cloud, no accounts.

[![Python](https://img.shields.io/badge/Python-3.8%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Backend-Flask-000000?logo=flask&logoColor=white)](https://flask.palletsprojects.com/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-4B5563?logo=linux&logoColor=white)](#)

</div>

---

## ✨ What is PyStudio?

PyStudio is a **local Python playground** that runs in your browser. It gives you a clean code editor with syntax highlighting, smart autocomplete, and a live output console — all powered by a small Flask server on your own computer.

- 🔒 **Fully local** — your code runs on your machine
- ⚡ **Instant execution** — click *Run Code* and see output
- 🧠 **Smart autocomplete** — keywords, built-ins, and your own variables
- 🌐 **LAN mode** — access PyStudio from another device on the same Wi-Fi
- 📦 **Automatic setup** — installers prepare the Python environment and install dependencies

Built for beginners, students, and anyone who wants to run Python without a full IDE.

---

## 🚀 Installation

Choose your operating system below to see the installation instructions.

<details>
<summary><b>🪟 Windows Installation (Click to expand)</b></summary>

<br>

### 1. Requirements

| Requirement | Details |
|---|---|
| **Operating System** | Windows 10 / 11 |
| **Python** | 3.8 or newer |
| **PowerShell** | 5.1 or newer |
| **Internet** | Required during installation |
| **Dependencies** | Flask, Uvicorn, asgiref |

### 2. Download PyStudio

Open PowerShell and clone the repository:

```powershell
git clone https://github.com/Codez-suriya/PyStudio.git
cd PyStudio
```

### 3. Install PyStudio

Run the PowerShell installer:

```powershell
.\install.ps1
```

The installer prepares the Python environment and installs the required dependencies.

If PowerShell blocks script execution, allow scripts for the current PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then run the installer again.

### 4. Launch PyStudio

After installation, run:

```powershell
.\run.ps1
```

The launcher asks for a port (default: `8000`) and how PyStudio should be accessed:

| Mode | Description |
|---|---|
| **Have Domain** | Use a domain name |
| **Expose Locally** | Accessible only from this computer |
| **Expose to LAN** | Accessible from devices on your local network |

### 5. Open PyStudio

Open the URL displayed by the launcher in your browser.

Default address:

```text
http://localhost:8000
```

</details>

<details>
<summary><b>🐧 Linux Installation (Click to expand)</b></summary>

<br>

### 1. Requirements

| Requirement | Details |
|---|---|
| **Operating System** | Linux |
| **Python** | 3.8 or newer |
| **Shell** | Bash |
| **Internet** | Required during installation |
| **Dependencies** | Git, curl, Flask, Uvicorn, asgiref |

The installer supports common package managers, including APT, DNF, Pacman, Zypper, and APK.

### 2. Download PyStudio

Open your terminal and clone the repository:

```bash
git clone https://github.com/Codez-suriya/PyStudio.git
cd PyStudio
```

### 3. Install PyStudio

Make the installer executable:

```bash
chmod +x install.sh
```

Run the installer:

```bash
./install.sh
```

The installer automatically:

- Checks for Git and curl.
- Detects or installs a compatible Python runtime.
- Creates a virtual environment (`.venv`).
- Installs the required Python packages.
- Checks the application launcher.

### 4. Launch PyStudio

Run:

```bash
./run.sh
```

The launcher asks for a port (default: `8000`) and whether you want to use a domain.

If you do not use a domain, it attempts to detect your LAN IP address.

### 5. Open PyStudio

Open the URL displayed in your terminal.

Default address:

```text
http://localhost:8000
```

</details>

---

## 🖥️ Using PyStudio

Once PyStudio is running, open its URL in your browser.

### Code Editor

Write your Python code in the editor.

- Syntax highlighting
- Smart autocomplete
- Code editing
- Python keyword and built-in suggestions

### Run Code

Click **Run Code** to execute your program.

### Output Console

View your program's output and errors in the console.

Programs can also receive input through the application interface.

---

## 🌐 LAN Access

PyStudio can be accessed from other devices connected to the same local network.

1. Connect your computer and the other device to the same Wi-Fi network.
2. Start PyStudio using the appropriate operating system launcher.
3. Enable LAN access using the launcher's options.
4. Open the displayed network address in the other device's browser.

Example:

```text
http://192.168.1.10:8000
```

The address above is only an example. Use the actual address displayed by your launcher.

**Security note:** LAN access allows other devices on your network to reach the application. Only use it on networks you trust. PyStudio is not a security sandbox for untrusted code. Avoid exposing it directly to the public internet.

---

## 📁 Project Structure

```text
PyStudio/
│
├── app.py                 # Flask application and Python execution
├── index.html             # Main browser interface
├── style.css              # Main interface styling
│
├── autocomplete.css       # Autocomplete styling
├── autocomplete.js        # Autocomplete functionality
│
├── syntax.css             # Syntax highlighting styles
├── syntax.js              # Syntax highlighting functionality
│
├── requirements.txt       # Python dependencies
│
├── install.py             # Cross-platform installer launcher
├── install.ps1            # Windows installer
├── install.sh             # Linux installer
│
├── run.ps1                # Windows launcher
└── run.sh                 # Linux launcher
```

---

## 📦 Dependencies

PyStudio uses the following Python packages:

| Package | Purpose |
|---|---|
| Flask | Web application backend |
| Uvicorn | ASGI server |
| asgiref | WSGI-to-ASGI compatibility |

These dependencies are installed automatically by the platform installer.

---

## 🛠️ Troubleshooting

### Python is not recognized on Windows

Check whether Python is installed from PowerShell:

```powershell
python --version
```

If the command is unavailable, install Python and ensure it is available in your system PATH.

### Installation fails

- Check your internet connection.
- Verify that Python 3.8 or newer is available.
- Read the error message printed by the installer.

### PyStudio does not start

- Verify that installation completed successfully.
- Check that the project virtual environment exists.
- Read the error message printed in your terminal.

### Port is already in use

Choose a different available port when the launcher asks for one.

### LAN access is not working

- Check that both devices are connected to the same network.
- Use the LAN address printed by the launcher.
- Check whether your computer's firewall is blocking the selected port.

---

## 🗑️ Uninstallation

PyStudio uses a project-local Python virtual environment.

To remove the installation, stop the running server and delete the PyStudio project directory.

Removing the project directory also removes its `.venv` environment.

**Note:** Keep a backup of any files you want to save before deleting the directory.

---

## 🤝 Contributing

Contributions, suggestions, and bug reports are welcome!

1. Fork the repository.
2. Create a new branch.
3. Make your changes.
4. Submit a pull request.

---

## 📄 License

See the repository for license information.

---

<div align="center">

**Made with ❤️ for Python learners.**

[GitHub Repository](https://github.com/Codez-suriya/PyStudio)

</div>
