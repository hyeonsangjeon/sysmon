# sysmon

A lightweight terminal CPU/memory monitor with **no external dependencies**.

- **macOS** → [`sysmon.sh`](sysmon.sh) (bash, uses `top` / `vm_stat` / `ps`)
- **Windows** → [`sysmon.ps1`](sysmon.ps1) (PowerShell, uses CIM + `GlobalMemoryStatusEx`)

## Preview

```
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    System Monitor                 15:17:42
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  CPU  [████████████████░░░░░░░░░░░░░░░░░░░░░░░░]  39.2%
  MEM  [█████████████████████████░░░░░░░░░░░░░░░]  61.5%  14.7G / 24.0G

  ▸ Top 5  CPU
      PID    CPU%    MEM%  PROCESS
      ...

  ▸ Top 5  MEM
      PID    CPU%    MEM%  PROCESS
      ...
```

## Features

- CPU / memory usage as colored bars (green < 50%, yellow < 80%, red above)
- Top 5 processes by CPU and by memory
- Refreshes every 2 seconds; press `q` to quit

## Usage

### macOS

```bash
chmod +x sysmon.sh
./sysmon.sh
```

### Windows

```powershell
# If scripts are blocked, allow this one for the current session:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\sysmon.ps1
```

Best viewed in Windows Terminal or PowerShell 7. Press `q` to quit.

## How memory usage is calculated

Both operating systems aggressively use spare RAM as a **file cache** that can be
reclaimed instantly. A naive "used / total" reading counts that cache as used and
reports a near-100% figure that does not reflect real memory pressure. This tool
avoids that on both platforms:

**macOS** — instead of `top`'s `PhysMem ... used` (which includes reclaimable
cache), it computes the Activity Monitor figure from `vm_stat`:

```
used  = (Wired + Compressed + (Anonymous − Purgeable)) × page size
usage = used / total RAM   (sysctl hw.memsize)
```

**Windows** — it calls `GlobalMemoryStatusEx`, the same API Task Manager uses, and
treats reclaimable standby cache as available rather than used:

```
used  = TotalPhys − AvailPhys
usage = used / TotalPhys
```

## Requirements

- **macOS:** `bash` (the script uses `/usr/bin/env bash`)
- **Windows:** Windows PowerShell 5.1+ or PowerShell 7+
