# FTP Sync

A PowerShell script that recursively downloads files from an FTP server to a local directory, designed to run daily via Windows Task Scheduler.

## Configuration

Edit the configuration block at the top of `sync-ftp.ps1`:

```powershell
$FTP_HOST  = "ftp.example.com"
$FTP_PORT  = 21
$FTP_USER  = "your_username"
$FTP_PASS  = "your_password"
$FTP_PATH  = "/remote/path/to/sync"
$LOCAL_DIR = "C:\ftp-sync\downloads"
$LOG_FILE  = "C:\ftp-sync\logs\sync.log"
```

## Usage

Run manually:

```powershell
powershell.exe -ExecutionPolicy Bypass -File C:\ftp-sync\sync-ftp.ps1
```

## Scheduling (Windows Task Scheduler)

Run the following in PowerShell as Administrator to create a daily task at 2:00 AM:

```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NonInteractive -ExecutionPolicy Bypass -File C:\ftp-sync\sync-ftp.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At "02:00"

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable

Register-ScheduledTask -TaskName "FTP Daily Sync" `
    -Action $action -Trigger $trigger -Settings $settings `
    -RunLevel Highest -Force
```

`-StartWhenAvailable` ensures the task runs on next boot if the machine was off at the scheduled time.

Run immediately to test:

```powershell
Start-ScheduledTask -TaskName "FTP Daily Sync"
```

View task history: open **Task Scheduler** → Task Scheduler Library → "FTP Daily Sync" → History tab.

## Notes

- Files that already exist locally are skipped. To re-download changed files, remove the `Test-Path` check (~line 100 of the script).
- **FTPS** (FTP over TLS): supported by the script — add `$request.EnableSsl = $true` to each request block.
- **SFTP** (SSH-based): not supported by `FtpWebRequest`. Use [WinSCP](https://winscp.net) CLI instead.
- Credentials are stored in plaintext. Restrict read permissions on the script file, or use Windows Credential Manager.
