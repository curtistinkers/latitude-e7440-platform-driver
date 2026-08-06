# Dell Latitude E7440 Platform Driver

A lightweight hardware integration framework designed for the Dell Latitude E7440 laptop. This package enables unbuffered keyboard event handling for the screen brightness keys, instant display panel toggling on lid state transitions, and a standalone dynamic cooling fan controller driven by a secure systemd timer.

---

## Directory Structure

```text
~/latitude-e7440-platform-driver/
├── DEBIAN/
│   ├── control       # Package metadata and system dependencies
│   ├── postinst      # Force-reloads module parameters and starts services
│   └── prerm         # Stops services and tears down timers on package removal
├── build.sh          # Native, built-in only automated compilation script
└── usr/
    ├── lib/
    │   └── systemd/
    │       └── system/
    │           ├── brightness-keys-handler.service  # Continuous key handler service
    │           ├── lid-handler.service              # Continuous lid state monitor service
    │           ├── fan-handler.service              # Oneshot cooling adjustment service
    │           └── fan-handler.timer                # 10-second thermal polling timer
    └── libexec/
        └── latitude-e7440-platform-driver/
            ├── brightness-keys-handler.sh           # Brightness hardware execution script
            ├── lid-handler.sh                       # Unbuffered lid switch tracking script
            └── fan-handler.sh                       # Dynamic sensor parsing and fan control script
```

---

## System Dependencies

These packages are automatically checked and pulled by the package manager during installation:

* `coreutils`
* `grep`
* `awk`
* `systemd`
* `lm-sensors` (Provides the underlying sensor mapping interfaces needed to read the motherboard temperatures)

---

## Component Details

### 1. Brightness Keys Handler

Monitors the ACPI input event loop directly out of the video bus device folder. It intercepts the physical hardware keys and scales the display backlight brightness value by 10% steps up or down.

### 2. Lid Switch Handler

Tracks the physical magnetic lid sensor state using unbuffered data parsing. When the laptop lid closes, it saves your current brightness level to a temporary file in memory and sets the panel brightness to zero. When opened, it immediately restores your screen to the exact previous value.

### 3. Fan Regulation Handler

Fires every 10 seconds via a native systemd timer. It scans the motherboard directories for the `dell_smm` hardware interface, loops through all temperature files to find the one labelled CPU, and adjusts the fan speed using these specific thermal thresholds:

* **Under 55°C**: Fan is turned off completely (PWM 0).
* **55°C to 70°C**: Fan runs at low speed (PWM 128).
* **Above 70°C**: Fan runs at maximum factory speed (PWM 255).

---

## Sandbox Isolation

All long-running services inside this package utilize strict systemd security sandboxing profiles:

* `ProtectSystem=strict` locks down the filesystem to prevent unauthorized modifications.
* `NoNewPrivileges=yes` prevents processes from elevating their system privileges.
* `RuntimeDirectory=latitude-e7440-platform-driver` allocates a secure, ephemeral memory folder at `/run/latitude-e7440-platform-driver/` to store temporary state files safely away from global storage paths.

---

## Automated Compilation

The project contains a standalone `build.sh` file at the root level. This script uses native shell commands to copy only valid package files into a staging area, completely stripping away Git folders, text files, and documentation before compiling.

To build the package, move into the directory and execute the script:

```bash
cd ~/latitude-e7440-platform-driver
./build.sh
```

The script will generate a clean `latitude-e7440-platform-driver.deb` binary archive in the parent folder.

---

## Installation and Removal

### Install the Package

Run this command to unpack the files, configure system components, and start all background triggers automatically:

```bash
sudo apt install /root/latitude-e7440-platform-driver.deb
```

### Remove the Package

To cleanly stop all background loops, disable the timing clocks, and wipe out the package files completely from your server, execute:

```bash
sudo apt purge latitude-e7440-platform-driver
```
