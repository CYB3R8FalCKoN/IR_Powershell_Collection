# Incident Response Quick Reference Guide
**Live Response: Volatile & Non-Volatile Data Collection**  
_CYB3R8 (AKA DarkFalckon) Network Forensics_

> **Locard's Exchange Principle:** Interacting with a live system will cause changes — document everything. Maintain a chain of custody throughout your investigation.

---

## 🛑 Prerequisites & Evidence Handling
Before you begin data collection, strictly follow these handling procedures:
1. **Prepare a Trusted Toolkit:** Use a trusted USB thumb drive (TD) containing your own compiled/verified binaries of all tools listed below. Do not rely on the compromised system's binaries; an attacker may have replaced them with trojans.
2. **Label All Media:** Label all collection media with Case #, Date, Start/Stop Time, Examiner Name, and Evidence Type.
3. **Compute Checksums:** Generate MD5/SHA-256 checksums of all toolkit binaries before deployment/pre-incident.
4. **Redirect All Output:** Redirect all output to your collection media (e.g., `/mnt/usb/case/` or `K:\case\`). **Never** write to the target system's local disk.
5. **Admin Rights:** Run all commands from an elevated (root/Administrator) prompt.
6. **Documentation:** Document the chain of custody for all collected evidence.

---

## 🐧 UNIX / LINUX Collection

### Volatile Data Collection (Collect First)

1. **Open a Trusted Shell:** Execute your shell from the trusted USB toolkit, not the local system binaries. This ensures commands are not trojaned.
   ```bash
   /mnt/usb/tools/bash
   ```
2. **Record System Date & Time:** Record both the system clock and the actual (wall clock) time for timeline correlation across multiple systems.
   ```bash
   date > /mnt/usb/case/datetime.txt
   hwclock >> /mnt/usb/case/datetime.txt
   ```
3. **Capture System Memory (RAM):** Memory contains running processes, encryption keys, passwords, network connections, and malware artifacts that exist only in RAM. Use a trusted memory acquisition tool. (_3rd Party: AVML_)
   ```bash
   ./avml /mnt/usb/case/memory.raw
   strings memory.raw > /mnt/usb/case/strings_ascii.txt
   strings -el memory.raw > /mnt/usb/case/strings_uni.txt
   ```
4. **Identify Logged-In Users:** Determine all users currently logged in and their session details. Reveals unauthorized access.
   ```bash
   w > /mnt/usb/case/users.txt
   who >> /mnt/usb/case/users.txt
   last -a >> /mnt/usb/case/users.txt
   ```
5. **Capture Running Processes:** List all running processes with full detail. Compare against known-good baselines to identify suspicious activity.
   ```bash
   ps auxeww > /mnt/usb/case/processes.txt
   ps -eo pid,ppid,uid,cmd --forest >> /mnt/usb/case/proctree.txt
   ls -la /proc/*/exe >> /mnt/usb/case/proc_exe.txt
   ```
6. **Capture Network Connections & Open Ports:** Active connections reveal C2 (command and control) channels, data exfiltration, and lateral movement. Record both TCP and UDP.
   ```bash
   netstat -tulpan > /mnt/usb/case/netstat.txt
   ss -tulpan >> /mnt/usb/case/ss.txt
   lsof -i -n -P >> /mnt/usb/case/lsof_net.txt
   ```
7. **Capture Routing Table:** The routing table shows how traffic is directed and may reveal unauthorized routes or VPN tunnels.
   ```bash
   route -n > /mnt/usb/case/routes.txt
   ip route show >> /mnt/usb/case/routes.txt
   iptables -L -n -v >> /mnt/usb/case/iptables.txt
   ```
8. **Capture ARP Cache:** ARP cache maps IP addresses to MAC addresses. Useful for identifying hosts the system communicated with recently.
   ```bash
   arp -an > /mnt/usb/case/arp.txt
   ip neigh show >> /mnt/usb/case/arp.txt
   ```
9. **Capture DNS Cache:** DNS cache reveals recent domain lookups that may point to malicious infrastructure.
   ```bash
   cat /etc/resolv.conf > /mnt/usb/case/dns.txt
   systemd-resolve --statistics >> /mnt/usb/case/dns.txt 2>&1
   cat /etc/hosts >> /mnt/usb/case/dns.txt
   ```
10. **Capture Open Files & File Handles:** Open files show what the system and its processes are actively accessing, including hidden or deleted files still held open.
    ```bash
    lsof +L1 > /mnt/usb/case/openfiles.txt
    lsof -n >> /mnt/usb/case/lsof_all.txt
    ```
11. **Record Ending Date & Time:** Bookend your collection with a closing timestamp to establish the total duration of the evidence collection window.
    ```bash
    date >> /mnt/usb/case/datetime.txt
    ```
12. **Save Command History:** Document every command executed during collection for reproducibility and court testimony.
    ```bash
    history > /mnt/usb/case/history.txt
    cat ~/.bash_history >> /mnt/usb/case/history.txt
    ```

### Non-Volatile Data Collection (Collect Second)

13. **Capture Network Interface Configuration:** Record all interface details including IP addresses, MAC addresses, and promiscuous mode status.
    ```bash
    ifconfig -a > /mnt/usb/case/ifconfig.txt
    ip addr show >> /mnt/usb/case/ipaddr.txt
    ip link show >> /mnt/usb/case/iplink.txt
    ```
14. **Capture System Information:** Collect kernel version, hostname, uptime, and hardware details for system identification.
    ```bash
    uname -a > /mnt/usb/case/sysinfo.txt
    hostname >> /mnt/usb/case/sysinfo.txt
    uptime >> /mnt/usb/case/sysinfo.txt
    cat /etc/*release >> /mnt/usb/case/sysinfo.txt
    ```
15. **Collect System Logs:** Logs are critical evidence. Copy all logs from `/var/log/` to your collection media for offline analysis.
    ```bash
    cp -r /var/log/ /mnt/usb/case/logs/
    journalctl --no-pager > /mnt/usb/case/journal.txt
    dmesg > /mnt/usb/case/dmesg.txt
    ```
16. **Capture Scheduled Tasks (Cron Jobs):** Attackers commonly use cron jobs for persistence. Collect all user and system cron entries.
    ```bash
    crontab -l > /mnt/usb/case/cron_root.txt 2>&1
    ls -la /etc/cron* >> /mnt/usb/case/crontabs.txt
    cat /etc/crontab >> /mnt/usb/case/crontabs.txt
    for u in $(cut -d: -f1 /etc/passwd); do echo "--- $u ---" >> /mnt/usb/case/cron_all.txt; crontab -u $u -l >> /mnt/usb/case/cron_all.txt; done
    ```
17. **Capture User & Group Accounts:** User accounts reveal unauthorized additions. Check for UID 0 accounts (root-level) beyond the root user.
    ```bash
    cat /etc/passwd > /mnt/usb/case/passwd.txt
    cat /etc/shadow > /mnt/usb/case/shadow.txt
    cat /etc/group > /mnt/usb/case/group.txt
    awk -F: '$3==0' /etc/passwd >> /mnt/usb/case/uid0.txt
    ```
18. **Record File Timestamps (Directory Listings):** File metadata (Modified, Accessed, Changed) is essential for timeline analysis. Check `/tmp` and `/dev/shm` for attacker staging areas.
    ```bash
    find / -xdev -printf '%T+ %m %u %g %s %p\n' > /mnt/usb/case/timeline.txt 2>/dev/null
    ls -laR /tmp /dev/shm >> /mnt/usb/case/temp.txt
    ```
19. **Capture Mounted Filesystems & Devices:** Identify all mounted drives, network shares, and connected devices for complete scope of the incident.
    ```bash
    mount > /mnt/usb/case/mounts.txt
    df -h >> /mnt/usb/case/diskusage.txt
    fdisk -l >> /mnt/usb/case/partitions.txt
    lsblk >> /mnt/usb/case/blocks.txt
    ```
20. **Capture Loaded Kernel Modules:** Kernel modules are a vector for rootkits. Compare loaded modules against known-good baselines.
    ```bash
    lsmod > /mnt/usb/case/modules.txt
    cat /proc/modules >> /mnt/usb/case/modules.txt
    ```
21. **Capture Startup / Persistence Mechanisms:** Check init scripts, systemd services, and autostart locations for persistence mechanisms planted by attackers.
    ```bash
    systemctl list-unit-files --type=service > /mnt/usb/case/services.txt
    ls -la /etc/init.d/ >> /mnt/usb/case/initd.txt
    ls -la /etc/rc*.d/ >> /mnt/usb/case/rcd.txt
    cat ~/.bashrc ~/.profile >> /mnt/usb/case/shell_rc.txt 2>&1
    ```
22. **Create Disk Image (If Required):** Imaging takes significant time. Begin only after all volatile data is captured. Use a write-blocker if available. (_3rd Party: dc3dd_)
    ```bash
    dd if=/dev/sda of=/mnt/usb/case/disk.raw hash=md5 hash=sha256 log=/mnt/usb/case/img.log
    ```
23. **Capture Swap / Virtual Memory:** Swap space may contain memory pages that have been paged out, potentially including passwords, encryption keys, and malware fragments.
    ```bash
    swapon --show > /mnt/usb/case/swap.txt
    cat /proc/swaps >> /mnt/usb/case/swap.txt
    ```

---

## 🪟 WINDOWS Collection

> **Note:** $K:\$ denotes your trusted USB toolkit drive. Sysinternals tools require `/accepteula` on first run.

### Volatile Data Collection (Collect First)

1. **Execute a Trusted Command Shell:** Launch `cmd.exe` from your trusted USB, NOT the local system copy. Prevents trojaned shell execution.
   ```cmd
   K:\cmd.exe
   ```
2. **Record System Date & Time:** Record the machine date/time AND actual wall-clock time. Required for timeline correlation across multiple victim machines.
   ```cmd
   K:\date /t > K:\case\datetime.txt
   K:\time /t >> K:\case\datetime.txt
   ```
3. **Capture System Memory (RAM):** Memory contains passwords, encryption keys, memory-resident-only PEs, running malware, and all volatile network data. Capture early memory tools can rarely blue-screen the system. (_3rd Party: DumpIt / Magnet RAM Capture_)
   ```cmd
   K:\tools\DumpIt.exe
   K:\tools\strings64.exe memory.dmp > K:\case\str_ascii.txt
   K:\tools\strings64.exe -el memory.dmp > K:\case\str_uni.txt
   ```
4. **Determine Who Is Logged In:** All users currently logged on. Reveals unauthorized sessions. Run both `PsLoggedOn` and `net user` and compare output. (_3rd Party: PsLoggedOn_)
   ```cmd
   K:\tools\PsLoggedOn.exe > K:\case\users.txt
   K:\net user >> K:\case\users.txt
   ```
5. **List All Running Processes & Services:** All processes with services and PIDs. Compare against known good. `/svc` maps services; `/v` gives verbose detail including memory usage.
   ```cmd
   K:\tasklist /svc > K:\case\processes1.txt
   K:\tasklist /v >> K:\case\processes2.txt
   ```
6. **List Open & Listening Ports with Associated Apps:** Active connections reveal C2 channels, exfiltration, lateral movement. `-b` shows executable per connection. `Tcpvcon` adds CSV output. (_3rd Party: Tcpvcon_)
   ```cmd
   K:\netstat -anob > K:\case\netstat.txt
   K:\tools\Tcpvcon.exe -a -c -n > K:\case\tcpvcon.txt
   ```
7. **Determine Routing Table:** Shows network paths. May reveal unauthorized routes or VPN tunnels.
   ```cmd
   K:\netstat -rn > K:\case\routes.txt
   ```
8. **Capture ARP Cache:** Maps IP to MAC addresses. Shows recently communicated hosts on local network, key for lateral movement detection.
   ```cmd
   K:\arp -a > K:\case\arp.txt
   ```
9. **Capture NetBIOS Sessions & Cache:** NetBIOS reveals file/print sharing connections and network neighborhood communications. Critical in Windows environments for lateral movement.
   ```cmd
   K:\nbtstat -c > K:\case\netbios.txt
   K:\nbtstat -S >> K:\case\netbios.txt
   K:\nbtstat -n >> K:\case\netbios.txt
   ```
10. **Capture DNS Cache & IP Configuration:** DNS cache shows recently resolved domains (may point to C2/phishing). Full IP config includes DHCP, DNS servers, MACs, and adapter details.
    ```cmd
    K:\ipconfig /all > K:\case\ipconfig.txt
    K:\ipconfig /displaydns >> K:\case\dns_cache.txt
    ```
11. **List Open Files & Registry Handles:** Files actively accessed by processes, including deleted files still held open. _Note: `openfiles /Local ON` requires a reboot._
    ```cmd
    K:\openfiles /Query > K:\case\openfiles.txt
    K:\net file >> K:\case\openfiles.txt
    ```
12. **Record Ending Date & Time:** Bookend the collection window. Establishes total duration of evidence gathering for the forensic timeline.
    ```cmd
    K:\date /t >> K:\case\datetime.txt
    K:\time /t >> K:\case\datetime.txt
    ```
13. **Save Command History:** Document every command executed during your session for reproducibility and potential court testimony.
    ```cmd
    K:\doskey /history > K:\case\cmd_history.txt
    ```

### Non-Volatile Data Collection (Collect Second)

14. **Capture System Information:** Collect OS version, hostname, hardware details, hotfixes, and boot time. Essential for establishing system identity.
    ```cmd
    K:\systeminfo > K:\case\sysinfo.txt
    K:\hostname >> K:\case\sysinfo.txt
    ```
15. **Export Event Logs:** Event logs (Security, System, Application) cannot be simply copied; use `wevtutil` to export them. Logs contain authentication events, service changes, and errors.
    ```cmd
    K:\wevtutil epl SYSTEM K:\case\system.evtx
    K:\wevtutil epl SECURITY K:\case\security.evtx
    K:\wevtutil epl APPLICATION K:\case\application.evtx
    ```
16. **Export Registry Hives:** Registry contains autostart entries, USB history, installed software, user MRU lists. Requires a custom tool for active hives (`reg save`).
    ```cmd
    K:\reg save HKLM\SOFTWARE K:\case\software.hiv
    K:\reg save HKLM\SYSTEM K:\case\system.hiv
    K:\reg save HKLM\SAM K:\case\sam.hiv
    K:\reg save HKCU K:\case\hkcu.hiv
    ```
17. **Record File Timestamps (Directory Listings):** Capture all three timestamp types for timeline analysis. _Note: NTFS Last Access time may not be turned on; Last Access is not available on FAT-32._
    ```cmd
    K:\dir /t:a /a /s /o:d C:\ > K:\case\dir_access.txt
    K:\dir /t:w /a /s /o:d C:\ > K:\case\dir_modified.txt
    K:\dir /t:c /a /s /o:d C:\ > K:\case\dir_created.txt
    ```
18. **Capture Prefetch Files:** Prefetch (`C:\Windows\Prefetch`) records program execution history even for programs since deleted from the system.
    ```cmd
    K:\xcopy C:\Windows\Prefetch\*.pf K:\case\prefetch\ /E /H
    ```
19. **Capture Pagefile & Hibernation File:** `Pagefile.sys` and `hiberfil.sys` may contain memory fragments paged to disk, passwords, encryption keys, and malware artifacts. Copy for offline analysis.
    ```cmd
    K:\xcopy C:\pagefile.sys K:\case\ /H
    K:\xcopy C:\hiberfil.sys K:\case\ /H
    ```
20. **Capture Scheduled Tasks:** Attackers use scheduled tasks for persistence. List all tasks with full verbosity to identify unauthorized entries.
    ```cmd
    K:\schtasks /query /fo LIST /v > K:\case\schtasks.txt
    ```
21. **Capture Installed Drivers:** Drivers operate at kernel level and are a common vector for rootkits. Compare against baseline known-good drivers.
    ```cmd
    K:\driverquery /v > K:\case\drivers.txt
    K:\driverquery /FO CSV /SI >> K:\case\drivers_sig.csv
    ```
22. **Capture User Account, Shares, & Sessions:** Enumerate accounts, admin group, mapped drives, active sessions, and shares. Detects unauthorized accounts and lateral movement staging.
    ```cmd
    K:\net user > K:\case\accounts.txt
    K:\net localgroup administrators >> K:\case\accounts.txt
    K:\net use >> K:\case\netuse.txt
    K:\net session >> K:\case\netsess.txt
    K:\net share >> K:\case\netshare.txt
    ```
23. **Capture Browser Cache:** Browser cache contains visited URLs, downloaded files, cookies, and cached web content. May reveal attacker download sites, phishing pages, or webshell access.
    ```cmd
    K:\xcopy "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" K:\case\browser_cache\chrome\ /E /H /I
    K:\xcopy "%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache" K:\case\browser_cache\edge\ /E /H /I
    ```
24. **Capture Startup/Autorun Programs:** Autoruns enumerates ALL programs set to run at boot/login. Critical for detecting persistence mechanisms planted by attackers. (_3rd Party: Autoruns_)
    ```cmd
    K:\tools\autorunsc.exe /accepteula -a * -c > K:\case\autoruns.csv
    ```
25. **WMIC Artifact Collection:** Deep system interrogation. Output in HTML table format for structured review of processes, services, NICs, startup items, and timezone.
    ```cmd
    K:\wmic process list full /FORMAT:htable > K:\case\wmic_proc.html
    K:\wmic startup list full /FORMAT:htable > K:\case\wmic_start.html
    K:\wmic service list full /FORMAT:htable > K:\case\wmic_svc.html
    K:\wmic nicconfig list full /FORMAT:htable > K:\case\wmic_nic.html
    ```
26. **Create Disk Image (If Required):** Disk imaging takes significant time (modern drives are TBs). Begin only after all other data is collected. You can start analysis before imaging completes. (_3rd Party: FTK Imager_)
    ```cmd
    K:\tools\FTK_Imager_CLI.exe
    ```

---
_**Evidence Integrity Note:** All commands are native unless labeled 3rd Party. After collection, hash all evidence: `md5sum /mnt/usb/case/* > hashes.txt` (Unix) or `md5deep64.exe K:\case\* > hashes.txt` (Windows)._
