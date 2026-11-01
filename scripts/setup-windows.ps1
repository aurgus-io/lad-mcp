$ErrorActionPreference = 'Stop'

$McpRepository = 'git+https://github.com/aurgus-io/lad-mcp.git'
$SetupBaseUrl = 'https://raw.githubusercontent.com/aurgus-io/lad-mcp/main/scripts'
$DefaultLadDirectory = Join-Path $HOME 'LAD'

Write-Host ''
Write-Host 'LAD MCP setup for Windows 10+' -ForegroundColor Cyan
Write-Host '1) Claude Desktop'
Write-Host '2) Claude Code'
$ClientChoice = Read-Host 'Choose your Claude app [1]'
if ([string]::IsNullOrWhiteSpace($ClientChoice)) { $ClientChoice = '1' }
if ($ClientChoice -notin @('1', '2')) { throw 'Choose 1 for Claude Desktop or 2 for Claude Code.' }

$LadDirectory = Read-Host "Path to your LAD directory [$DefaultLadDirectory]"
if ([string]::IsNullOrWhiteSpace($LadDirectory)) { $LadDirectory = $DefaultLadDirectory }
$LadDirectory = [System.IO.Path]::GetFullPath($LadDirectory)
if (-not (Test-Path -LiteralPath $LadDirectory -PathType Container)) {
    throw "LAD directory not found: $LadDirectory"
}

$EventsFile = Join-Path $LadDirectory 'daemon/logs/dashboard_events.jsonl'
if (-not (Test-Path -LiteralPath $EventsFile -PathType Leaf)) {
    throw "Cannot find $EventsFile. Start LAD and confirm it writes daemon/logs/dashboard_events.jsonl, then rerun setup."
}

$Uv = Get-Command uv -ErrorAction SilentlyContinue
if (-not $Uv) {
    $Winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $Winget) { throw 'Install uv (https://docs.astral.sh/uv/getting-started/installation/) and rerun setup.' }
    Write-Host 'Installing uv with winget...'
    winget install --id astral-sh.uv -e --accept-source-agreements --accept-package-agreements
    $UvCandidates = @(
        (Join-Path $HOME '.local/bin/uv.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs/uv/uv.exe')
    )
    foreach ($Candidate in $UvCandidates) {
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) { $Uv = Get-Item $Candidate; break }
    }
    if (-not $Uv) { $Uv = Get-Command uv -ErrorAction SilentlyContinue }
    if (-not $Uv) { throw 'uv was installed. Open a new PowerShell window and rerun setup.' }
}
$UvPath = $Uv.Source

if ($ClientChoice -eq '1') {
    $ConfigFile = Join-Path $env:APPDATA 'Claude/claude_desktop_config.json'
    $HelperFile = Join-Path $env:TEMP 'lad-mcp-configure-claude-desktop.py'
    Invoke-WebRequest -Uri "$SetupBaseUrl/configure-claude-desktop.py" -OutFile $HelperFile
    & $UvPath python install 3.12
    if ($LASTEXITCODE -ne 0) { throw 'Could not install Python 3.12 with uv.' }
    & $UvPath run --python 3.12 $HelperFile `
        --config $ConfigFile `
        --events-file $EventsFile `
        --uv-command $UvPath `
        --repository $McpRepository
    if ($LASTEXITCODE -ne 0) { throw 'Claude Desktop configuration failed.' }
    Write-Host 'Setup complete. Fully quit and reopen Claude Desktop.' -ForegroundColor Green
    Write-Host 'Ask Claude to list recent LAD anomalies to confirm the tools loaded.'
}
else {
    $Claude = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $Claude) {
        throw 'Claude Code is not installed or is not on PATH. Install it and sign in, then rerun: https://docs.anthropic.com/en/docs/claude-code/getting-started'
    }
    & $Claude.Source mcp get lad *> $null
    if ($LASTEXITCODE -eq 0) {
        throw 'Claude Code already has an MCP server named lad. Run `claude mcp remove lad`, then rerun setup.'
    }
    & $Claude.Source mcp add `
        --scope user `
        --transport stdio `
        --env "LAD_EVENTS_FILE=$EventsFile" `
        lad `
        -- $UvPath tool run --from $McpRepository lad-mcp
    if ($LASTEXITCODE -ne 0) { throw 'Claude Code configuration failed.' }
    Write-Host 'Setup complete. Check the connection with claude mcp list.' -ForegroundColor Green
    Write-Host 'Open Claude Code and run /mcp to confirm the LAD tools loaded.'
}
