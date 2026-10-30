# PyStudio

<div align="center">

**A browser-based Python interpreter that runs entirely on your machine.**

Write Python · Run it instantly · No account, no cloud, no setup headaches.

[![Python](https://img.shields.io/badge/Python-3.8%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Backend-Flask-000000?logo=flask&logoColor=white)](https://flask.palletsprojects.com/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-4B5563?logo=linux&logoColor=white)](#)
[![License](https://img.shields.io/badge/License-Not%20specified-lightgrey)](#license)

[Features](#-features) · [Install](#-installation) · [Run](#-running-pystudio) · [Troubleshooting](#-troubleshooting)

</div>

---

## ✨ What is PyStudio?

PyStudio is a **local Python playground** you open in your browser. It gives you a clean code editor with syntax highlighting, smart autocomplete, and a live output console — all backed by a small Flask + Uvicorn server running on your own computer.

> Built for beginners, students, and anyone who wants a zero-friction way to write and run Python without an IDE.

---

## 🚀 Features

| | |
|---|---|
| 🖥️ **Browser editor** | Syntax highlighting with multiple colour themes |
| ⚡ **Instant run** | Click *Run Code* and see output stream live |
| 🧠 **Smart autocomplete** | Keywords, built-ins, your own variables, module members |
| ⌨️ **Interactive input** | Full support for `input()` |
| 🌐 **LAN mode** | Access from your phone on the same Wi-Fi |
| 📦 **Zero config** | One command installs everything |
| 🔒 **Fully local** | Your code never leaves your machine |

---

## 📦 Installation

**Requirements:** Python **3.8+** and an internet connection during install.
That's it — everything else is automatic.

### 🪟 Windows

Open **PowerShell** and paste this:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Codez-suriya/PyStudio/main/install.py" -OutFile "install.py"; python install.py
