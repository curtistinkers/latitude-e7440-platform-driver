# Dell Latitude E7440 Platform Driver

An ACPI integration package for the Dell Latitude E7440. It handles the laptop's lid, brightness, and AC-adapter events,
configures systemd-logind not to perform its own lid, power, sleep, suspend, or hibernate actions, and installs a
`fancontrol` configuration for Dell and Intel hwmon devices. It also includes my own `linux-laptop-nut-bridge` module,
which publishes the laptop battery's telemetry through Network UPS Tools (NUT) as a virtual `[battery]` UPS.

The package expects `/sys/class/backlight/intel_backlight` and is therefore intended for the E7440's Intel graphics and
kernel backlight interface.

## Clone with submodules

```bash
git clone --recurse-submodules https://github.com/curtistinkers/latitude-e7440-platform-driver.git
```

## What It Does

### Backlight keys

ACPI events for `video/brightnessdown` and `video/brightnessup` call `brightness-keys-handler.sh`. The script changes
`/sys/class/backlight/intel_backlight/brightness` by one tenth of `max_brightness`, clamped to the supported minimum
and maximum.

### Lid switch

ACPI reports for `button/lid` dispatch to `lid-switch-handler.sh`.

- On `close`, the script saves the current backlight value in
`/run/latitude-e7440-platform-driver/lid_switch_brightness_save` and sets the backlight to zero.
- On `open`, it restores the saved value and removes the save file.

The runtime directory is created mode `0700`. It uses volatile `/run` storage, so saved state is lost after a reboot.

### AC adapter

AC adapter events dispatch to `ac-adapter-handler.sh`.

- On battery power, the screen is reduced to 30 percent of `max_brightness` and the previous value is saved. If it is
  already at or below 30 percent, no file is created.
- On AC power, the saved value is restored. If there is no saved value and the screen is exactly at the 30-percent
  target, it is set to `max_brightness`.

The save file is `/run/latitude-e7440-platform-driver/power_brightness_save`.

### Fan control

The package depends on `lm-sensors` and `fancontrol` and installs `/etc/fancontrol`. The configuration reads CPU
temperature from `hwmon4/temp1_input` and controls the Dell SMM fan PWM (`hwmon3/pwm1`) with a 10-second polling interval.

The supplied thresholds are:

- Minimum temperature: 45 C
- Maximum temperature: 70 C
- Minimum start PWM: 150
- Minimum stop PWM: 60

Fan control behavior is applied by the system's `fancontrol` service and should be reviewed or regenerated if
`sensors-detect` assigns different hwmon numbers on a different kernel or hardware configuration.

### Battery telemetry through NUT

The package installs the `linux-laptop-nut-bridge` timer and its one-shot systemd service. The timer runs every two
seconds and starts the bridge service to refresh battery and AC telemetry from `/sys/class/power_supply`.

The bridge dynamically finds a battery path (`BAT*` or `BATT*`) and an AC adapter path (`AC*`, `ADP*`, or `ACAD*`). It
writes a dummy UPS status file to:

```sh
/run/linux-laptop-nut-bridge/internal_battery_status
```

The status file includes UPS state and battery charge, voltage, current, cycle, health, charge, threshold, manufacturer,
model, and serial telemetry. AC power maps to `OL` (and `CHRG` while charging); battery power maps to `OB` (and
`DISCHRG` while discharging). Charge at or below 15 percent adds `LB`.

During configuration, the package:

- sets NUT to standalone mode in `/etc/nut/nut.conf`;
- adds a `[battery]` entry using the `dummy-ups` driver to `/etc/nut/ups.conf`;
- enables and starts `linux-laptop-nut-bridge.timer`;
- runs the bridge once immediately;
- restarts the NUT driver enumerator and starts `nut-driver@battery.service`;
- restarts `nut-server.service`.

The bridge service runs as the `nut` user and group under strict systemd filesystem, process, network, device, and
privilege restrictions. Its runtime directory is `/run/linux-laptop-nut-bridge`, mode `0700`, and is recreated
automatically with the service.

### Systemd-logind overrides

`usr/lib/systemd/logind.conf.d/99-disable-buttons.conf` ignores lid-close, sleep, suspend, hibernate, power, and reboot
actions. This allows the package's ACPI handlers to own lid and power-button-related behavior rather than having logind
act on them as well.

## Package Layout

```text
etc/
├── acpi/
│   ├── events/
│   │   ├── ac_adapter
│   │   ├── brightness-down
│   │   ├── brightness-up
│   │   └── lid-switch
│   └── handlers/
│       ├── ac_adapter.sh
│       └── lid-switch.sh
└── fancontrol
usr/
├── lib/
│   └── systemd/
│       ├── logind.conf.d/99-disable-buttons.conf
│       └── system/
│           ├── linux-laptop-nut-bridge.service
│           └── linux-laptop-nut-bridge.timer
└── libexec/latitude-e7440-platform-driver/
    ├── ac-adapter-handler.sh
    ├── battery-nut-sync.sh
    ├── brightness-keys-handler.sh
    └── lid-switch-handler.sh
debian/
├── control
├── install
├── postinst
├── postrm
├── prerm
└── rules
build.sh
```

## Dependencies

The Debian package declares:

- `systemd`
- `acpid`
- `lm-sensors`
- `fancontrol`
- `nut-server`
- `nut-client`

Debhelper compatibility is also used while building. The maintainer script runs:

```bash
sensors-detect --auto
```

during installation or initial configuration. It reloads systemd-logind, restarts `fancontrol`, configures NUT, and
enables the NUT bridge as described above.

The package conflicts with, replaces, and provides `linux-battery-nut-bridge`, my generic NUT bridge integration.

## Building

Install Debian packaging dependencies, including `debuild`/`devscripts`, `debhelper`, and the build dependencies from
`debian/control`. Then run:

```bash
./build.sh
```

`build.sh` invokes:

```bash
debuild -uc -us -b .
```

This performs an unsigned binary-only build. The resulting `.deb` and associated artifacts are written in the parent
directory of the repository.

## Installation

Build the package, then install the generated archive with:

```bash
sudo apt install ../latitude-e7440-platform-driver_<version>_<arch>.deb
```

After installation, ensure the `acpid` and `fancontrol` services are active and that
`/sys/class/backlight/intel_backlight` exists on your kernel. Verify sensor and fan mappings with:

```bash
sensors
sudo pwmconfig
```

Use `pwmconfig` carefully: it tests fan control hardware and can change configuration files and fan behavior.

Verify that the NUT bridge is active and publishing battery data with:

```bash
systemctl status linux-laptop-nut-bridge.timer
systemctl status linux-laptop-nut-bridge.service
upsc battery
```

The virtual UPS should expose a status such as `OL`, `OL CHRG`, `OB`, or `OB DISCHRG`, plus battery charge and health information.

## Removal

```bash
sudo apt purge latitude-e7440-platform-driver
```

Purge removes the `[battery]` entry from `/etc/nut/ups.conf`, disables the bridge units, and removes the bridge
runtime directory.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
