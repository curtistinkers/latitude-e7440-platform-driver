# Dell Latitude E7440 Platform Driver

An ACPI integration package for the Dell Latitude E7440. It handles the laptop's
lid, brightness, and AC-adapter events, configures systemd-logind not to perform
its own lid, power, sleep, suspend, or hibernate actions, and installs an
`fancontrol` configuration for Dell and Intel hwmon devices.

The package expects `/sys/class/backlight/intel_backlight` and is therefore
intended for the E7440's Intel graphics and kernel backlight interface.

## Clone with submodules

```bash
git clone --recurse-submodules https://github.com/curtistinkers/latitude-e7440-platform-driver.git
```

## What It Does

### Backlight keys

ACPI events for `video/brightnessdown` and `video/brightnessup` call
`brightness-keys-handler.sh`. The script changes
`/sys/class/backlight/intel_backlight/brightness` by one tenth of
`max_brightness`, clamped to the supported minimum and maximum.

### Lid switch

ACPI reports for `button/lid` dispatch to `lid-switch-handler.sh`.

- On `close`, the script saves the current backlight value in
  `/run/latitude-e7440-platform-driver/lid_switch_brightness_save` and sets the
  backlight to zero.
- On `open`, it restores the saved value and removes the save file.

The runtime directory is created mode `0700`. It uses volatile `/run` storage,
so saved state is lost after a reboot.

### AC adapter

AC adapter events dispatch to `ac-adapter-handler.sh`.

- On battery power, the screen is reduced to 30 percent of
  `max_brightness` and the previous value is saved. If it is already at or
  below 30 percent, no file is created.
- On AC power, the saved value is restored. If there is no saved value and the
  screen is exactly at the 30-percent target, it is set to
  `max_brightness`.

The save file is `/run/latitude-e7440-platform-driver/power_brightness_save`.

### Fan control

The package depends on `lm-sensors` and `fancontrol` and installs
`/etc/fancontrol`. The configuration reads CPU temperature from
`hwmon4/temp1_input` and controls the Dell SMM fan PWM
(`hwmon3/pwm1`) with a 10-second polling interval.

The supplied thresholds are:

- Minimum temperature: 45 C
- Maximum temperature: 70 C
- Minimum start PWM: 150
- Minimum stop PWM: 60

Fan control behavior is applied by the system's `fancontrol` service and should
be reviewed or regenerated if `sensors-detect` assigns different hwmon numbers
on a different kernel or hardware configuration.

### Systemd-logind overrides

`usr/lib/systemd/logind.conf.d/99-disable-buttons.conf` ignores lid-close,
sleep, suspend, hibernate, power, and reboot actions. This allows the package's
ACPI handlers to own lid and power-button-related behavior rather than having
logind act on them as well.

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
│   └── systemd/logind.conf.d/99-disable-buttons.conf
└── libexec/latitude-e7440-platform-driver/
    ├── ac-adapter-handler.sh
    ├── brightness-keys-handler.sh
    └── lid-switch-handler.sh
debian/
├── control
├── install
├── postinst
└── rules
build.sh
```

## Dependencies

The Debian package declares:

- `systemd`
- `acpid`
- `lm-sensors`
- `fancontrol`

Debhelper compatibility is also used while building. The maintainer script runs:

```text
sensors-detect --auto
```

during installation or configuration. It does not explicitly start or stop
services; Debian's normal service management and the package dependencies handle
the relevant services.

## Building

Install Debian packaging dependencies, including `debuild`/`devscripts`,
`debhelper`, and the build dependencies from `debian/control`. Then run:

```bash
./build.sh
```

`build.sh` invokes:

```bash
debuild -uc -us -b .
```

This performs an unsigned binary-only build. The resulting `.deb` and associated
artifacts are written in the parent directory of the repository.

## Installation

Build the package, then install the generated archive with:

```bash
sudo apt install ../latitude-e7440-platform-driver_<version>_<arch>.deb
```

After installation, ensure the `acpid` and `fancontrol` services are active and
that `/sys/class/backlight/intel_backlight` exists on your kernel. Verify sensor
and fan mappings with:

```bash
sensors
sudo pwmconfig
```

Use `pwmconfig` carefully: it tests fan control hardware and can change
configuration files and fan behavior.

## Removal

```bash
sudo apt purge latitude-e7440-platform-driver
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
