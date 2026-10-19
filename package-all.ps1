$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$calendarConfig = Join-Path $projectRoot 'outlook-screensaver/source/config.brs'
if (-not (Test-Path -LiteralPath $calendarConfig)) {
    Copy-Item -LiteralPath (Join-Path $projectRoot 'outlook-screensaver/source/config.brs.example') -Destination $calendarConfig
}
& (Join-Path $projectRoot 'generate-previews.ps1')
$outputDirectory = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$clockOutput = Join-Path $outputDirectory 'night-clock-roku.zip'
$scheduleOutput = Join-Path $outputDirectory 'night-clock-outlook-roku.zip'

if (Test-Path -LiteralPath $clockOutput) { Remove-Item -LiteralPath $clockOutput }
if (Test-Path -LiteralPath $scheduleOutput) { Remove-Item -LiteralPath $scheduleOutput }

Compress-Archive -Path @(
    (Join-Path $projectRoot 'manifest'),
    (Join-Path $projectRoot 'source'),
    (Join-Path $projectRoot 'components'),
    (Join-Path $projectRoot 'images')
) -DestinationPath $clockOutput -CompressionLevel Optimal

$scheduleRoot = Join-Path $projectRoot 'outlook-screensaver'
Compress-Archive -Path @(
    (Join-Path $scheduleRoot 'manifest'),
    (Join-Path $scheduleRoot 'source'),
    (Join-Path $scheduleRoot 'components'),
    (Join-Path $scheduleRoot 'fonts'),
    (Join-Path $scheduleRoot 'images')
) -DestinationPath $scheduleOutput -CompressionLevel Optimal

Write-Host "Created $clockOutput"
Write-Host "Created $scheduleOutput"
& (Join-Path $projectRoot 'package-dashboard.ps1')
