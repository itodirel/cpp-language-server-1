#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Diagnostic {
    param([Parameter(Mandatory)][string]$Message)

    [Console]::Error.WriteLine("[cpp-language-server] $Message")
}

try {
    $npxPath = Get-Command 'npx' -All -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandType -eq 'Application' } |
        Select-Object -First 1 -ExpandProperty Source
    if (-not $npxPath) {
        throw 'npx must be installed and available on PATH. See https://nodejs.org/.'
    }

    $sessionId = [Guid]::Empty
    if ($env:COPILOT_AGENT_SESSION_ID -and -not [Guid]::TryParse($env:COPILOT_AGENT_SESSION_ID, [ref]$sessionId)) {
        Write-Diagnostic 'Copilot session attribution is not a UUID. Using inherited working directory; exact-directory auto-configuration is not guaranteed.'
    }
    elseif ($env:COPILOT_AGENT_SESSION_ID) {
        $sessionId = $sessionId.ToString()
        $parentId = (Get-CimInstance Win32_Process -Filter "ProcessId = $PID").ParentProcessId
        $invocationId = "${parentId}-$((Get-Process -Id $parentId).StartTime.ToUniversalTime().Ticks)"
        $directoryFile = Join-Path $env:LOCALAPPDATA "Microsoft\CppLanguageServer\SessionDirectories\$sessionId.$invocationId.json"
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while (-not (Test-Path -LiteralPath $directoryFile) -and [DateTime]::UtcNow -lt $deadline) {
            Start-Sleep -Milliseconds 50
        }
        if (Test-Path -LiteralPath $directoryFile) {
            $sessionDirectory = Get-Content -LiteralPath $directoryFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($sessionDirectory.version -ne 1 -or $sessionDirectory.sessionId -ne $sessionId -or
                $sessionDirectory.invocationId -ne $invocationId -or
                $sessionDirectory.cwd -isnot [string] -or -not [IO.Path]::IsPathRooted($sessionDirectory.cwd) -or
                -not (Test-Path -LiteralPath $sessionDirectory.cwd -PathType Container)) {
                throw 'Invalid Copilot session directory.'
            }

            Set-Location -LiteralPath $sessionDirectory.cwd
            [Environment]::CurrentDirectory = $sessionDirectory.cwd
        }
        else {
            Write-Diagnostic 'No Copilot session directory after 30 seconds. Using inherited working directory; exact-directory auto-configuration is not guaranteed.'
        }
    }

    & $npxPath '@microsoft/cpp-language-server'
    exit $LASTEXITCODE
}
catch {
    Write-Diagnostic $_.Exception.Message
    exit 1
}
