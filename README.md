# MeetMind 🚀
> **Real-Time Stealth AI Meeting & Interview Assistant**

MeetMind is an intelligent, real-time interview and meeting copilot designed for Windows. It captures meeting audio from Microsoft Teams, Zoom, or Google Meet, transcribes conversation in real time, automatically detects interview questions, and streams structured, instant answers to a floating heads-up display (HUD).

Most importantly, MeetMind is **100% invisible on screen shares, screenshots, and taskbars**, allowing you to reference AI-powered insights smoothly and discreetly.

---

## 🌟 Key Features

* **🛡️ 100% Screen-Share Invisibility**:
  * Utilizes native Windows Desktop Window Manager (DWM) display affinity (`WDA_EXCLUDEFROMCAPTURE = 0x00000011`).
  * Completely invisible on Microsoft Teams, Zoom, Google Meet, Slack, Snipping Tool, and screen recordings—while remaining crisp and clear on your monitor.
* **🥷 Zero Console Windows & Silent Execution**:
  * Launched via Windows Script Host (`wscript.exe`) with `SW_HIDE (0)`.
  * **Zero black command prompts** or PowerShell console boxes ever appear or flash on your screen.
* **🚫 Hidden from Taskbar & Alt+Tab**:
  * Configured with native `ShowInTaskbar="False"`.
  * No icons appear on the Windows taskbar, and the HUD is omitted from the `Alt + Tab` app switcher.
* **🖥️ Windows Virtual Desktop Auto-Tracking**:
  * Integrated with the native Windows `IVirtualDesktopManager` COM interface.
  * If you switch between **Desktop 1** and **Desktop 2**, the HUD automatically follows you to your active virtual desktop.
* **🔊 Universal Meeting Audio Loopback**:
  * Captures the interviewer's voice directly from system audio without needing virtual cables or third-party audio drivers (`navigator.mediaDevices.getDisplayMedia` with system loopback).
* **⚡ Google Gemini AI Engine**:
  * Uses Google Gemini for fast, highly tailored, contextual technical answers, code snippets, and architecture explanations.
* **🛑 Instant Panic / Stop Controls**:
  * Close instantly by pressing the **`Esc`** key on the HUD, clicking the **`✕`** button, or double-clicking `stop.bat`.

---

## 📁 Project Architecture

```
MeetMind/
├── 🚀 stealth-mode.bat       # Main Windows launcher (Runs silently with 0 console windows)
├── 🛑 stop.bat               # Main Windows shutdown button (Silently kills all processes)
│
├── 📁 skills/                # Modular Interview Domain Skills (Agent-managed)
│   ├── ⚡ salesforce.json    # Salesforce, Apex, SOQL, Agentforce & Data Cloud
│   ├── 🏗️ system-design.json # Scalable Systems, Microservices, Caching & Sharding
│   ├── 💻 fullstack.json     # Data Structures & Algorithms, Python, JS/TS, SQL
│   └── 🎯 general.json       # General Software Engineering & Behavioral
│
├── 🌐 index.html             # Web Application (Audio capture, STT, and Gemini AI engine)
├── ⚙️ server.ps1             # Local API Server & IPC bridge (http://localhost:3000)
├── 🛡️ stealth-hud.ps1        # Native WPF Stealth HUD (Invisible on screen share & taskbar)
│
├── 📜 stealth-launcher.vbs   # Silent VBS launcher (SW_HIDE execution)
├── 📜 stop-silent.vbs        # Silent VBS shutdown helper
├── 📜 stop.ps1               # Process cleanup logic
└── 📄 README.md              # Project documentation
```

---

## 🔄 How It Works (Process Flow)

```mermaid
flowchart TD
    A["Double-Click stealth-mode.bat"] --> B["stealth-launcher.vbs (SW_HIDE 0)"]
    B --> C["stealth-hud.ps1 (WPF Native HUD)"]
    C -->|Auto-starts| D["server.ps1 (Local Server on :3000)"]
    C -->|Auto-opens| E["Chrome / Edge (http://localhost:3000)"]
    
    subgraph Browser Engine ["Chrome / Edge (index.html)"]
        E --> F["Audio Capture: System Loopback + Mic"]
        F --> G["Speech-to-Text & Question Detection"]
        G --> H["Google Gemini API (Generates Answer)"]
        H --> I["POST /api/feed"]
    end
    
    subgraph Stealth HUD Window ["Native Stealth HUD (stealth-hud.ps1)"]
        C --> J["SetWindowDisplayAffinity (WDA_EXCLUDEFROMCAPTURE 0x11)"]
        J --> K["ShowInTaskbar=False + HWND_TOPMOST"]
        K --> L["IVirtualDesktopManager (Follows active virtual desktop)"]
        I -->|GET /api/feed (500ms polling)| M["Displays live answers & transcript"]
    end

    subgraph Shutdown
        N["Click '✕' / Tap 'Esc' / Double-Click stop.bat"] --> O["stop.ps1 terminates HUD & server cleanly"]
    end
```

---

## 🚀 Quick Start Guide

### Prerequisites
* **Operating System**: Windows 10 (version 2004 or newer) or Windows 11.
* **Browser**: Google Chrome or Microsoft Edge.
* **API Key**: A free [Google Gemini API Key](https://aistudio.google.com/app/apikey).

### Installation & Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/MohnishTak2725/MeetMind.git
   cd MeetMind
   ```

2. **Launch MeetMind**:
   * Simply double-click **`stealth-mode.bat`**.
   * MeetMind will launch silently in the background:
     * The floating **Stealth HUD** appears pinned on top of your screen.
     * Google Chrome or Edge will open `http://localhost:3000`.

3. **Configure Your API Key**:
   * On the web page in your browser, paste your Google Gemini API key into the Settings section (saved securely in your browser's local storage).

4. **Connect Meeting Audio**:
   * Click **`🔊 Capture Meeting Audio (Teams/Zoom/Meet)`**.
   * In the Chrome screen picker, choose **"Entire Screen"** and ensure **"Also share system audio"** is checked.
   * You can also enable microphone capture for your own voice.

5. **During the Meeting**:
   * Drag the HUD anywhere on your screen.
   * When the interviewer asks a question, MeetMind transcribes the speech and displays structured answers inside the HUD in real time.
   * Feel free to share your screen on Teams, Zoom, or Meet—**the HUD will not be visible to anyone else**.

6. **Shutting Down**:
   * Tap the **`Esc`** key on the HUD.
   * Or click the **`✕`** button on the HUD header.
   * Or double-click **`stop.bat`** to terminate all background processes instantly.

---

## 🔒 Privacy & Stealth Verification

| Protection Layer | Implementation | Benefit |
| :--- | :--- | :--- |
| **Screen Share Invisibility** | `WDA_EXCLUDEFROMCAPTURE` | Invisible on Teams, Zoom, Meet, and Snipping Tool. |
| **Window Hierarchy** | `HWND_TOPMOST` | Remains pinned above full-screen browser tabs. |
| **Zero Taskbar Footprint** | `ShowInTaskbar="False"` | No icon on the Windows taskbar. |
| **Zero Alt+Tab Footprint** | Tool window style affinity | HUD does not appear in `Alt + Tab` switcher. |
| **Headless Shell** | `WScript.Shell.Run ..., 0` | Zero flashing CMD or PowerShell windows. |
| **Multi-Desktop Sync** | `IVirtualDesktopManager` | Automatically follows you between Virtual Desktops. |

---

## 📄 License
This project is for personal educational and productivity use. Ensure you comply with meeting recording and transparency policies applicable in your jurisdiction.

