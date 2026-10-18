$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-PreviewText {
    param($Graphics, [string]$Text, [single]$Size, [single]$X, [single]$Y, [string]$Color)
    $font = [Drawing.Font]::new('Segoe UI', $Size, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
    $brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($Color))
    try { $Graphics.DrawString($Text, $font, $brush, $X, $Y) }
    finally { $font.Dispose(); $brush.Dispose() }
}

function Draw-WeatherSymbol {
    param($Graphics, [string]$Kind, [string]$Color)
    $brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($Color))
    $pen = [Drawing.Pen]::new($brush, 5)
    $black = [Drawing.SolidBrush]::new([Drawing.Color]::Black)
    try {
        if ($Kind -in @('sun','partly')) {
            $Graphics.DrawEllipse($pen, 30, 20, 48, 48)
            foreach ($angle in @(0,45,90,135,180,225,270,315)) {
                $radians=$angle * [Math]::PI / 180
                $Graphics.DrawLine($pen, [single](54+33*[Math]::Cos($radians)), [single](44+33*[Math]::Sin($radians)), [single](54+43*[Math]::Cos($radians)), [single](44+43*[Math]::Sin($radians)))
            }
        }
        if ($Kind -in @('moon','partly-night')) {
            $Graphics.FillEllipse($brush, 26, 14, 66, 66)
            $Graphics.FillEllipse($black, 48, 6, 59, 59)
        }
        if ($Kind -notin @('sun','moon')) {
            $Graphics.FillEllipse($brush, 18, 48, 46, 40)
            $Graphics.FillEllipse($brush, 42, 32, 52, 56)
            $Graphics.FillEllipse($brush, 74, 48, 40, 40)
            $Graphics.FillRectangle($brush, 38, 62, 60, 26)
        }
        if ($Kind -eq 'rain') {
            foreach ($x in @(34,62,90)) { $Graphics.DrawLine($pen, $x, 98, ($x-8), 115) }
        }
        if ($Kind -eq 'snow') {
            foreach ($x in @(36,66,96)) {
                $Graphics.DrawLine($pen, ($x-6), 100, ($x+6), 112)
                $Graphics.DrawLine($pen, ($x+6), 100, ($x-6), 112)
            }
        }
        if ($Kind -eq 'fog') {
            $Graphics.DrawLine($pen, 18, 100, 110, 100)
            $Graphics.DrawLine($pen, 30, 114, 98, 114)
        }
        if ($Kind -eq 'storm') {
            $points=[Drawing.Point[]]@([Drawing.Point]::new(65,87),[Drawing.Point]::new(49,108),[Drawing.Point]::new(64,108),[Drawing.Point]::new(56,126),[Drawing.Point]::new(85,99),[Drawing.Point]::new(70,99))
            $Graphics.FillPolygon($brush, $points)
        }
    } finally { $brush.Dispose(); $pen.Dispose(); $black.Dispose() }
}

function Save-WeatherIcons {
    $directory=Join-Path $projectRoot 'outlook-screensaver/images/weather'
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    foreach ($kind in @('sun','moon','partly','partly-night','cloud','fog','rain','snow','storm')) {
        $bitmap=[Drawing.Bitmap]::new(128,128)
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([Drawing.Color]::Transparent)
            $graphics.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
            Draw-WeatherSymbol $graphics $kind '#242424'
            $bitmap.Save((Join-Path $directory "$kind.png"),[Drawing.Imaging.ImageFormat]::Png)
        } finally {$graphics.Dispose(); $bitmap.Dispose()}
    }
}

function Save-ScreenPreview {
    param([string]$Path, [bool]$Agenda, [string]$Color)
    $bitmap = [Drawing.Bitmap]::new(1920, 1080)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([Drawing.Color]::Black)
        $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        if ($Agenda) {
            Write-PreviewText $graphics '23:48' 110 120 80 $Color
            Write-PreviewText $graphics 'TODAY  /  3 events' 30 132 235 $Color
            Write-PreviewText $graphics '09:00   Team meeting' 34 132 295 $Color
            Write-PreviewText $graphics '13:30   Project review' 34 132 350 $Color
            Write-PreviewText $graphics '18:00   Dinner with friends' 34 132 405 $Color
            Write-PreviewText $graphics 'NEXT 7 DAYS' 26 132 635 $Color
            Write-PreviewText $graphics 'Mon 10/19   09:00   Team meeting' 24 132 690 $Color
            Write-PreviewText $graphics 'Tue 10/20   13:30   Project review' 24 132 730 $Color
            Write-PreviewText $graphics 'Wed 10/21   18:00   Dinner' 24 132 770 $Color
            Write-PreviewText $graphics 'Thu 10/22   10:00   Planning' 24 132 810 $Color
            Write-PreviewText $graphics 'Fri 10/23   14:00   Weekly review' 24 132 850 $Color
            Write-PreviewText $graphics 'TUSCALOOSA 35406' 28 1120 90 $Color
            $weatherState=$graphics.Save()
            $graphics.TranslateTransform(1120,145)
            $graphics.ScaleTransform(0.75,0.75)
            Draw-WeatherSymbol $graphics 'moon' $Color
            $graphics.Restore($weatherState)
            Write-PreviewText $graphics '20°C' 60 1245 135 $Color
            Write-PreviewText $graphics 'Clear' 28 1120 250 $Color
            Write-PreviewText $graphics 'NEXT 24 HOURS' 28 1120 310 $Color
            Write-PreviewText $graphics 'Low 15°C   /   High 24°C' 24 1120 360 $Color
            $temperatures=@(19,18,18,17,16,16,15,15,16,18,20,21,22,23,24,24,23,22,21,20,20,19,18,18)
            $barBrush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($Color))
            try {
                for($i=0;$i -lt 24;$i++) {
                    $height=12+($temperatures[$i]-15)/9.0*110
                    $graphics.FillRectangle($barBrush,[single](1120+$i*25),[single](550-$height),14,[single]$height)
                    if ($i -in @(0,6,12,18,23)) {
                        $labelX=if($i -eq 23){1640}else{1112+$i*25}
                        Write-PreviewText $graphics ('{0:00}:00' -f $i) 20 $labelX 565 $Color
                    }
                    if($i % 3 -eq 0) {
                        $sample=[int]($i/3)
                        $x=1120+($sample%4)*160
                        $y=610+[Math]::Floor($sample/4)*115
                        Write-PreviewText $graphics ('{0:00}:00' -f $i) 22 $x $y $Color
                        $symbol=if($i -lt 6 -or $i -ge 18){'moon'}else{'sun'}
                        $saved=$graphics.Save()
                        $graphics.TranslateTransform($x,($y+40))
                        $graphics.ScaleTransform(0.3125,0.3125)
                        Draw-WeatherSymbol $graphics $symbol $Color
                        $graphics.Restore($saved)
                        Write-PreviewText $graphics ($temperatures[$i].ToString()+'°C') 26 ($x+45) ($y+40) $Color
                    }
                }
            } finally {$barBrush.Dispose()}
            Write-PreviewText $graphics 'Weather: Open-Meteo (CC BY 4.0)' 18 1120 870 $Color
        } else {
            $format = [Drawing.StringFormat]::new()
            $format.Alignment = [Drawing.StringAlignment]::Center
            $format.LineAlignment = [Drawing.StringAlignment]::Center
            $font = [Drawing.Font]::new('Segoe UI', 110, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
            $brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($Color))
            try { $graphics.DrawString('23:48', $font, $brush, [Drawing.RectangleF]::new(180,480,520,150), $format) }
            finally { $format.Dispose(); $font.Dispose(); $brush.Dispose() }
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}

function Save-MenuThumbnail {
    param([string]$Path, [int]$Width, [int]$Height, [bool]$Agenda)
    $bitmap = [Drawing.Bitmap]::new($Width, $Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([Drawing.Color]::Black)
        $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $scale = [single]($Width / 540.0)
        $graphics.ScaleTransform($scale, $scale)
        Write-PreviewText $graphics '23:48' 100 36 70 '#B0B0B0'
        if ($Agenda) {
            Write-PreviewText $graphics 'NEXT 7 DAYS' 22 44 194 '#888888'
            Write-PreviewText $graphics 'Mon   09:00   Team meeting' 23 44 232 '#888888'
            Write-PreviewText $graphics '20°C' 30 360 112 '#B0B0B0'
            Write-PreviewText $graphics 'Sleep Clock + Agenda' 30 36 320 '#D0D0D0'
        } else {
            Write-PreviewText $graphics 'Sleep Clock' 36 36 310 '#D0D0D0'
        }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}

function Save-NewsPreview {
    param([string]$Path, [string]$Color)
    $bitmap = [Drawing.Bitmap]::new(1920, 1080)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $font = [Drawing.Font]::new('Segoe UI', 32, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
    $brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($Color))
    try {
        $graphics.Clear([Drawing.Color]::Black)
        $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        Write-PreviewText $graphics '23:48' 110 120 80 $Color
        Write-PreviewText $graphics 'KAGI NEWS  /  TECHNOLOGY  /  LAYOUT SAMPLE' 28 132 270 $Color
        Write-PreviewText $graphics 'Technology, science and the economy' 52 132 345 $Color
        # Original sample copy, not a live headline or downloaded news summary.
        $sample = 'One story at a time, selected from Technology, Science and Economy. Each page shows a headline, a short English summary, the edition date and a source link. Topics alternate through the collection. General world and politics feeds are excluded, and politics-heavy headlines receive lower priority within the selected categories.'
        $graphics.DrawString($sample, $font, $brush, [Drawing.RectangleF]::new(132,500,1656,330))
        Write-PreviewText $graphics 'https://news.kagi.com/' 20 132 860 $Color
        Write-PreviewText $graphics 'Layout sample / Original demo text / Live content credited to Kagi News (CC BY-NC 4.0)' 20 132 935 $Color
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $font.Dispose(); $brush.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
}

$previewDirectory = Join-Path $projectRoot 'dist/previews'
New-Item -ItemType Directory -Force -Path $previewDirectory | Out-Null
Save-WeatherIcons
Save-NewsPreview (Join-Path $previewDirectory 'news-page-readable.png') '#999999'
Save-NewsPreview (Join-Path $previewDirectory 'news-page-day.png') '#242424'
Save-NewsPreview (Join-Path $previewDirectory 'news-page-night.png') '#0C0C0C'
Save-ScreenPreview (Join-Path $projectRoot 'docs/agenda-preview.png') $true '#999999'
foreach ($agenda in @($false, $true)) {
    $assetRoot = if ($agenda) { Join-Path $projectRoot 'outlook-screensaver/images' } else { Join-Path $projectRoot 'images' }
    $name = if ($agenda) { 'sleep-clock-agenda' } else { 'sleep-clock' }
    New-Item -ItemType Directory -Force -Path $assetRoot | Out-Null
    Save-MenuThumbnail (Join-Path $assetRoot 'menu-hd.png') 290 218 $agenda
    Save-MenuThumbnail (Join-Path $assetRoot 'menu-fhd.png') 540 405 $agenda
    $actualColor = if ($agenda) { '#242424' } else { '#181818' }
    Save-ScreenPreview (Join-Path $previewDirectory "$name.png") $agenda $actualColor
    if ($agenda) {
        Save-ScreenPreview (Join-Path $previewDirectory "$name-night.png") $agenda '#0C0C0C'
    }
    Save-ScreenPreview (Join-Path $previewDirectory "$name-readable.png") $agenda '#999999'
}
