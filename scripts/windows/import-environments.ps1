# ==================================================
# Import existing environments (Windows)
# Localhost Manager - PowerShell Script
# ==================================================
# Reads Apache virtual hosts from already-configured local stacks
# (XAMPP, WAMP, Laragon) and imports them into the manager's hosts.json.
# All use standard Apache <VirtualHost> blocks, so one parser handles them all.
#
# Usage:
#   .\import-environments.ps1            # import (writes hosts.json, backs up)
#   .\import-environments.ps1 -DryRun    # preview only, no changes

param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$ManagerDir = "$env:USERPROFILE\localhost-manager"
$HostsJson  = "$ManagerDir\conf\hosts.json"

$SkipNames = @('___default___', '_default_', 'default')

# Collect candidate vhost files: @{ Label; Path }
$sources = @()

function Add-IfExists($label, $path) {
    if (Test-Path $path) {
        Write-Host "Found: $label -> $path"
        $script:sources += [PSCustomObject]@{ Label = $label; Path = $path }
    }
}

Add-IfExists "XAMPP" "C:\xampp\apache\conf\extra\httpd-vhosts.conf"

# WAMP (any installed apache version)
foreach ($base in @("C:\wamp64\bin\apache", "C:\wamp\bin\apache")) {
    if (Test-Path $base) {
        Get-ChildItem $base -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Add-IfExists "WAMP" "$($_.FullName)\conf\extra\httpd-vhosts.conf"
        }
    }
}

# Laragon (one file per site)
$laragonDir = "C:\laragon\etc\apache2\sites-enabled"
if (Test-Path $laragonDir) {
    Get-ChildItem $laragonDir -Filter *.conf -ErrorAction SilentlyContinue | ForEach-Object {
        Add-IfExists "Laragon" $_.FullName
    }
}

if ($sources.Count -eq 0) {
    Write-Host "No XAMPP / WAMP / Laragon virtual host files found."
    Write-Host "Nothing to import."
    exit 0
}

# Parse a single Apache conf file -> hashtable domain => @{docroot; aliases; ssl}
function Parse-Vhosts($path) {
    $result = @{}
    try { $text = Get-Content $path -Raw -ErrorAction Stop } catch { return $result }

    $blocks = [regex]::Matches($text, '(?s)<VirtualHost\s+([^>]*)>(.*?)</VirtualHost>')
    foreach ($b in $blocks) {
        $addr = $b.Groups[1].Value
        $body = $b.Groups[2].Value

        $port = $null
        $pm = [regex]::Match($addr, ':(\d+)')
        if ($pm.Success) { $port = [int]$pm.Groups[1].Value }

        $sn = [regex]::Match($body, '(?im)^\s*ServerName\s+(\S+)')
        if (-not $sn.Success) { continue }
        $domain = $sn.Groups[1].Value.Trim()
        if ($SkipNames -contains $domain) { continue }

        $aliases = New-Object System.Collections.Generic.HashSet[string]
        foreach ($am in [regex]::Matches($body, '(?im)^\s*ServerAlias\s+(.+)$')) {
            foreach ($a in ($am.Groups[1].Value -split '\s+')) {
                $a = $a.Trim()
                if ($a -and ($SkipNames -notcontains $a)) { [void]$aliases.Add($a) }
            }
        }

        $docroot = $null
        $dr = [regex]::Match($body, '(?im)^\s*DocumentRoot\s+"?([^"\r\n]+?)"?\s*$')
        if ($dr.Success) { $docroot = $dr.Groups[1].Value.Trim() }

        $ssl = ($port -eq 443) -or [regex]::IsMatch($body, '(?im)^\s*SSLEngine\s+on')

        if (-not $result.ContainsKey($domain)) {
            $result[$domain] = @{ docroot = $null; aliases = (New-Object System.Collections.Generic.HashSet[string]); ssl = $false }
        }
        if ($docroot) { $result[$domain].docroot = $docroot }
        foreach ($a in $aliases) { [void]$result[$domain].aliases.Add($a) }
        if ($ssl) { $result[$domain].ssl = $true }
    }
    return $result
}

# Merge all sources
$merged = @{}
foreach ($src in $sources) {
    $parsed = Parse-Vhosts $src.Path
    foreach ($domain in $parsed.Keys) {
        $e = $parsed[$domain]
        if (-not $merged.ContainsKey($domain)) {
            $merged[$domain] = @{ docroot = $e.docroot; aliases = $e.aliases; ssl = $e.ssl; group = "Imported ($($src.Label))" }
        } else {
            foreach ($a in $e.aliases) { [void]$merged[$domain].aliases.Add($a) }
            if ($e.docroot -and -not $merged[$domain].docroot) { $merged[$domain].docroot = $e.docroot }
            $merged[$domain].ssl = $merged[$domain].ssl -or $e.ssl
        }
    }
}

# Load existing hosts.json into an ordered hashtable
$existing = [ordered]@{}
if (Test-Path $HostsJson) {
    try {
        $obj = Get-Content $HostsJson -Raw | ConvertFrom-Json
        foreach ($p in $obj.PSObject.Properties) { $existing[$p.Name] = $p.Value }
    } catch { }
}

$added = @(); $skipped = @(); $nodoc = @()
foreach ($domain in $merged.Keys) {
    $e = $merged[$domain]
    if (-not $e.docroot) { $nodoc += $domain; continue }
    if ($existing.Contains($domain)) { $skipped += $domain; continue }

    $aliasObjs = @()
    foreach ($a in ($e.aliases | Sort-Object)) {
        $aliasObjs += [PSCustomObject]@{ id = "alias_" + ([guid]::NewGuid().ToString('N').Substring(0,9)); value = $a; active = $true }
    }

    $existing[$domain] = [PSCustomObject]@{
        domain      = $domain
        docroot     = $e.docroot
        aliases     = $aliasObjs
        group       = $e.group
        active      = $false
        ssl         = [bool]$e.ssl
        type        = "php"
        stack       = "frontend"
        php_version = $null
        port        = $null
        mode        = "local"
    }
    $added += $domain
}

Write-Host ""
Write-Host "Import summary: $($added.Count) new, $($skipped.Count) already present, $($nodoc.Count) skipped (no DocumentRoot)"
foreach ($d in $added)   { Write-Host "  + $d -> $($existing[$d].docroot)" }
foreach ($d in $skipped) { Write-Host "  = $d (already in manager)" }

if ($DryRun) {
    Write-Host ""
    Write-Host "[dry-run] No changes written. Re-run without -DryRun to apply."
} elseif ($added.Count -gt 0) {
    if (-not (Test-Path (Split-Path $HostsJson))) {
        New-Item -ItemType Directory -Path (Split-Path $HostsJson) -Force | Out-Null
    }
    if (Test-Path $HostsJson) { Copy-Item $HostsJson "$HostsJson.bak" -Force }
    $existing | ConvertTo-Json -Depth 10 | Out-File -FilePath $HostsJson -Encoding UTF8 -Force
    Write-Host ""
    Write-Host "[OK] Wrote $($added.Count) new host(s) to $HostsJson (backup: hosts.json.bak)"
    Write-Host "     Imported hosts are INACTIVE. Activate them in the app, then 'Apply'."
} else {
    Write-Host ""
    Write-Host "Nothing new to import."
}
