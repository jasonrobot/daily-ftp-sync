# FTP Sync Script
# Downloads files from a remote FTP path to a local directory
# Designed to be run via Windows Task Scheduler

# ---- Configuration ----
$FTP_HOST     = "ftp.example.com"
$FTP_PORT     = 21
$FTP_USER     = "your_username"
$FTP_PASS     = "your_password"
$FTP_PATH     = "/remote/path/to/sync"   # Remote directory to download
$LOCAL_DIR    = "C:\ftp-sync\downloads"  # Local destination directory
$LOG_FILE     = "C:\ftp-sync\logs\sync.log"
# -----------------------

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Write-Host $line
    Add-Content -Path $LOG_FILE -Value $line
}

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-FtpListing {
    param([string]$RemotePath)

    $uri = "ftp://${FTP_HOST}:${FTP_PORT}$RemotePath"
    $request = [System.Net.FtpWebRequest]::Create($uri)
    $request.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
    $request.Credentials = New-Object System.Net.NetworkCredential($FTP_USER, $FTP_PASS)
    $request.UsePassive = $true
    $request.UseBinary = $true
    $request.KeepAlive = $false

    try {
        $response = $request.GetResponse()
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $listing = $reader.ReadToEnd()
        $reader.Close()
        $response.Close()
        return $listing
    } catch {
        Write-Log "ERROR listing $RemotePath`: $_"
        return $null
    }
}

function Download-FtpFile {
    param([string]$RemotePath, [string]$LocalPath)

    $uri = "ftp://${FTP_HOST}:${FTP_PORT}$RemotePath"
    $request = [System.Net.FtpWebRequest]::Create($uri)
    $request.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
    $request.Credentials = New-Object System.Net.NetworkCredential($FTP_USER, $FTP_PASS)
    $request.UsePassive = $true
    $request.UseBinary = $true
    $request.KeepAlive = $false

    try {
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $fileStream = [System.IO.File]::Create($LocalPath)
        $stream.CopyTo($fileStream)
        $fileStream.Close()
        $stream.Close()
        $response.Close()
        return $true
    } catch {
        Write-Log "ERROR downloading $RemotePath`: $_"
        return $false
    }
}

function Sync-FtpDirectory {
    param([string]$RemotePath, [string]$LocalPath)

    Ensure-Dir $LocalPath

    $listing = Get-FtpListing $RemotePath
    if (-not $listing) { return }

    foreach ($line in ($listing -split "`n")) {
        $line = $line.Trim()
        if (-not $line) { continue }

        # Parse Unix-style FTP listing: permissions links owner group size month day time/year name
        if ($line -match '^([\-d])[\w\-]{9}\s+\d+\s+\S+\s+\S+\s+\d+\s+\w+\s+[\d:]+\s+[\d:]+\s+(.+)$') {
            $type = $Matches[1]
            $name = $Matches[2].Trim()
        } else {
            continue
        }

        if ($name -in @(".", "..")) { continue }

        $remoteItem = "$RemotePath/$name".Replace("//", "/")
        $localItem  = Join-Path $LocalPath $name

        if ($type -eq "d") {
            Write-Log "Entering directory: $remoteItem"
            Sync-FtpDirectory -RemotePath $remoteItem -LocalPath $localItem
        } else {
            if (Test-Path $localItem) {
                Write-Log "Skipping (already exists): $name"
            } else {
                Write-Log "Downloading: $remoteItem"
                $ok = Download-FtpFile -RemotePath $remoteItem -LocalPath $localItem
                if ($ok) {
                    Write-Log "  -> OK"
                }
            }
        }
    }
}

# ---- Main ----
Ensure-Dir (Split-Path $LOG_FILE)
Ensure-Dir $LOCAL_DIR

Write-Log "=== FTP Sync started ==="
Write-Log "Host: ${FTP_HOST}:${FTP_PORT}  Remote: $FTP_PATH  Local: $LOCAL_DIR"

Sync-FtpDirectory -RemotePath $FTP_PATH -LocalPath $LOCAL_DIR

Write-Log "=== FTP Sync complete ==="
