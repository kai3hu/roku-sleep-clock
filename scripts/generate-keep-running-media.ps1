param([Parameter(Mandatory=$true)][string]$Ffmpeg)
$ErrorActionPreference = 'Stop'
$destination = Join-Path $PSScriptRoot '../dashboard-app/media/hourly-black.mp4'
# Generated asset only: ten seconds of SDR black, with no audio stream.
& $Ffmpeg -hide_banner -loglevel error -f lavfi -i 'color=c=black:s=320x180:r=24:d=10' -an -c:v libx264 -profile:v baseline -level:v 3.0 -pix_fmt yuv420p -color_range tv -colorspace bt709 -color_trc bt709 -color_primaries bt709 -crf 35 -g 24 -keyint_min 24 -sc_threshold 0 -map_metadata -1 -movflags +faststart -y $destination
if ($LASTEXITCODE -ne 0) {throw 'Black media generation failed'}
Write-Host "Generated $destination"
