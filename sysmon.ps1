#Requires -Version 5.1
<#
.SYNOPSIS
    sysmon.ps1 - lightweight Windows CPU/MEM monitor (PowerShell port of sysmon.sh)
.DESCRIPTION
    Shows live CPU and memory usage as colored bars plus the top 5 processes by
    CPU and memory. Memory usage is read via GlobalMemoryStatusEx, the same API
    Task Manager uses, so it reflects real "in use" memory (reclaimable cache is
    treated as available, not used).
#>

$Interval = 2
$W        = 40

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# GlobalMemoryStatusEx: accurate memory load, matches Task Manager and is locale-independent.
if (-not ([System.Management.Automation.PSTypeName]'SysMonMem').Type) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class SysMonMem {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct MEMORYSTATUSEX {
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX lpBuffer);
}
"@
}

function Get-MemStatus {
    $m = New-Object SysMonMem+MEMORYSTATUSEX
    $m.dwLength = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf([type]'SysMonMem+MEMORYSTATUSEX')
    [void][SysMonMem]::GlobalMemoryStatusEx([ref]$m)
    return $m
}

function Write-Meter {
    param([string]$Label, [double]$Pct, [string]$Suffix = '')
    if     ($Pct -lt 50) { $col = 'Green'  }
    elseif ($Pct -lt 80) { $col = 'Yellow' }
    else                 { $col = 'Red'    }
    $n = [int][math]::Round($Pct * $W / 100)
    if ($n -gt $W) { $n = $W }
    if ($n -lt 0)  { $n = 0  }
    $bar = ('█' * $n) + ('░' * ($W - $n))
    Write-Host ("  {0}  " -f $Label) -NoNewline -ForegroundColor White
    Write-Host '[' -NoNewline
    Write-Host $bar -NoNewline -ForegroundColor $col
    Write-Host ']' -NoNewline
    Write-Host ("  {0,5:N1}%" -f $Pct) -NoNewline
    if ($Suffix) { Write-Host "  $Suffix" -ForegroundColor DarkGray } else { Write-Host '' }
}

function Get-ProcStats {
    param([double]$TotalBytes, [int]$Nproc)
    try {
        $raw = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop |
            Where-Object { $_.Name -ne '_Total' -and $_.Name -ne 'Idle' }
        return $raw | Select-Object `
            @{N = 'Name';   E = { $_.Name }},
            @{N = 'PID';    E = { $_.IDProcess }},
            @{N = 'CPU';    E = { [math]::Round($_.PercentProcessorTime / $Nproc, 1) }},
            @{N = 'MemPct'; E = { if ($TotalBytes -gt 0) { [math]::Round($_.WorkingSet / $TotalBytes * 100, 1) } else { 0 } }}
    } catch {
        return Get-Process | Select-Object `
            @{N = 'Name';   E = { $_.ProcessName }},
            @{N = 'PID';    E = { $_.Id }},
            @{N = 'CPU';    E = { 0 }},
            @{N = 'MemPct'; E = { if ($TotalBytes -gt 0) { [math]::Round($_.WorkingSet64 / $TotalBytes * 100, 1) } else { 0 } }}
    }
}

function Write-ProcTable {
    param([string]$Title, [string]$Color, $Rows)
    Write-Host ("  ▸ {0}" -f $Title) -ForegroundColor $Color
    Write-Host ("  {0,7}  {1,6}  {2,6}  {3}" -f 'PID', 'CPU%', 'MEM%', 'PROCESS') -ForegroundColor DarkGray
    foreach ($r in $Rows) {
        $name = [string]$r.Name
        if ($name.Length -gt 30) { $name = $name.Substring(0, 30) }
        Write-Host ("  {0,7}  {1,6:N1}  {2,6:N1}  {3,-30}" -f $r.PID, $r.CPU, $r.MemPct, $name)
    }
}

$nproc = [int](Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
if ($nproc -lt 1) { $nproc = 1 }
$line = '━' * 45

# Probe once whether the host exposes an interactive console. Hosts such as the
# VS Code Integrated Console, the ISE, or redirected input throw on KeyAvailable;
# in those cases we just keep refreshing (parity with the bash version).
$canReadKeys = $true
try { $null = [Console]::KeyAvailable } catch { $canReadKeys = $false }

try { [Console]::CursorVisible = $false } catch {}
try {
    while ($true) {
        $mem     = Get-MemStatus
        $totalB  = [double]$mem.ullTotalPhys
        $usedB   = [double]($mem.ullTotalPhys - $mem.ullAvailPhys)
        $memPct  = if ($totalB -gt 0) { $usedB / $totalB * 100 } else { 0 }
        $usedG   = $usedB  / 1GB
        $totalG  = $totalB / 1GB

        try {
            $cpu = [double](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop).PercentProcessorTime
        } catch {
            $cpu = [double]((Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average)
        }

        $procs  = Get-ProcStats -TotalBytes $totalB -Nproc $nproc
        $topCpu = $procs | Sort-Object CPU    -Descending | Select-Object -First 5
        $topMem = $procs | Sort-Object MemPct -Descending | Select-Object -First 5

        Clear-Host
        Write-Host ''
        Write-Host "  $line" -ForegroundColor Cyan
        Write-Host ("  Windows System Monitor         {0}" -f (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Cyan
        Write-Host "  $line" -ForegroundColor Cyan
        Write-Host ''
        Write-Meter -Label 'CPU' -Pct $cpu
        Write-Meter -Label 'MEM' -Pct $memPct -Suffix ("{0:N1}G / {1:N1}G" -f $usedG, $totalG)
        Write-Host ''
        Write-ProcTable -Title 'Top 5  CPU' -Color Cyan    -Rows $topCpu
        Write-Host ''
        Write-ProcTable -Title 'Top 5  MEM' -Color Magenta -Rows $topMem
        Write-Host ''
        Write-Host ("  [q] Quit  -  refresh every {0}s" -f $Interval) -ForegroundColor DarkGray
        Write-Host ''

        $elapsed = 0.0
        $quit = $false
        while ($elapsed -lt $Interval) {
            if ($canReadKeys) {
                try {
                    if ([Console]::KeyAvailable -and [Console]::ReadKey($true).KeyChar -eq 'q') {
                        $quit = $true; break
                    }
                } catch { $canReadKeys = $false }
            }
            Start-Sleep -Milliseconds 100
            $elapsed += 0.1
        }
        if ($quit) { break }
    }
}
finally {
    try { [Console]::CursorVisible = $true } catch {}
}
