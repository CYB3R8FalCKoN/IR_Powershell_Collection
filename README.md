# IR_Powershell_Collection

A Windows PowerShell incident response triage script that performs structured volatile-first, then non-volatile data collection from a live host. Output is written to a timestamped `.txt` file with a SHA-256 hash for chain-of-custody integrity.

## Requirements

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or higher
- **Must be run as Administrator**

---

## Usage

```powershell
# Run from an elevated PowerShell prompt
.\IR_Script.ps1
```

Output files are written to the current directory:
- `IR_<HOSTNAME>_<TIMESTAMP>.txt` — full collection log
- `IR_<HOSTNAME>_<TIMESTAMP>.txt.sha256` — SHA-256 hash for chain of custody

---

## Collection Sections

### Volatile (Order of Volatility)
| # | Section | Key Data |
|---|---------|----------|
| 1 | System Date and Time | Local, UTC, timezone, last boot |
| 2 | Running Processes and Services | PID, PPID, command line, owner, path |
| 3 | Open and Listening Ports | TCP/UDP with owning process |
| 4 | Routing Table | IPv4 and IPv6 routes |
| 5 | ARP Cache | IPv4 and IPv6 neighbors |
| 6 | NetBIOS / SMB | Sessions, connections, WINS config |
| 7 | Open Files and Handles | SMB open files, top handle consumers |
| 8 | DNS Cache | All cached entries |
| 9 | Memory | Physical/virtual usage, top consumers by working set |

### Non-Volatile
| # | Section | Key Data |
|---|---------|----------|
| 10 | Network Interfaces | Adapters, IP addresses, full config |
| 11 | Users | Active sessions, logon types, local accounts, admins |
| 12 | Registry | Run keys, Winlogon, LSA, USBSTOR history, IFEO |
| 13 | Event Logs | Top 30 logs by size; last 30 system errors; last 20 logon events (4624/4625/4634/4672) |
| 14 | Prefetch | Last 30 executed programs by write time |
| 15 | Directory Listings | System32, Tasks, Startup, Downloads, Desktop, Temp |
| 16 | Pagefile / Hibernation | pagefile.sys, swapfile.sys, hiberfil.sys |
| 17 | System Information | OS, BIOS, CPU, hotfixes, environment variables |
| 18 | Mounted Devices | Drives, disks, partitions, volumes |
| 19 | Browser Artifacts | Cache, cookies, history, login data (Chrome, Edge, Brave, Firefox) |
| 20 | Scheduled Tasks | All tasks with last run, result, next run, and action |
| 21 | Installed Drivers | PnP signed drivers and system drivers |

---

## MITRE ATT&CK Coverage

| Section | Relevant Techniques |
|---------|-------------------|
| Processes | T1055 Process Injection, T1036 Masquerading |
| Services | T1543.003 Windows Service |
| Network Ports | T1071 Application Layer Protocol, T1049 System Network Connections Discovery |
| Registry Run Keys | T1547.001 Registry Run Keys / Startup Folder |
| Scheduled Tasks | T1053.005 Scheduled Task |
| USBSTOR | T1200 Hardware Additions |
| Logon Events | T1078 Valid Accounts |
| Prefetch | T1059 Command and Scripting Interpreter |
| Browser Artifacts | T1555.003 Credentials from Web Browsers |
| IFEO | T1546.012 Image File Execution Options Injection |

---

## Chain of Custody

Every collection run automatically generates a SHA-256 hash of the output file:


Do not modify the output file after collection. Verify integrity at any time:

```powershell
Get-FileHash .\IR_<HOSTNAME>_<TIMESTAMP>.txt -Algorithm SHA256
```

---

## Disclaimer

This script is intended for authorized incident response and forensic triage only. Do not run against systems you do not own or have explicit written authorization to examine.
