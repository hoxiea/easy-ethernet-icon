# Easy Ethernet Icon for macOS

A simple and lightweight macOS menu bar application that shows your Ethernet connection status at a glance — and lets you toggle it on or off instantly.

![Different icon styles](https://i.ibb.co/kD2KbCs/win.png)

## Features
- 🔌 Live ethernet connection status monitoring
- 🔁 One-click toggle to enable or disable your ethernet connection
- 📊 Live connection speed monitoring
- 🎨 Choice between macOS and Windows style icons
- 🚀 Launch at Login support
- 🏃‍♂️ Lightweight and efficient

## System Requirements
- macOS 13.5 or newer

## Installation
1. Download the latest release from the [Releases page](../../releases)
2. Unzip the downloaded file
3. Drag the app to your Applications folder
4. Double click to start the app
5. If the app cannot be opened due to security warnings:
	- Go to System Settings > Privacy & Security > Scroll down to "Security"
	- Click Open Anyway next to the blocked app
6. (Optional) Click the menu bar icon and select Settings to customize

## Usage
- The icon in the menu bar shows your current Ethernet connection status and (if enabled) the connection speed
- Click the icon to:
  - Enable or disable your ethernet connection (requires admin password)
  - See connection status
  - See connection speed
  - Access Network Settings
  - Configure app settings
  - Quit the application

## Build from Source
If you want to build the app yourself:
1. Clone this repository
2. Open the project in Xcode (14 or newer)
3. Build and run (⌘R), or build a release binary with:
```
xcodebuild -scheme "Easy Ethernet Icon" -configuration Release \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```

## Privacy
This app:
- Only monitors the ethernet connection status and speed
- Does not collect or transmit any data

---
Forked from [felixblome/easy-ethernet-icon](https://github.com/felixblome/easy-ethernet-icon)
