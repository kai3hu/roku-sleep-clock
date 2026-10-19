$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assetDirectory = Join-Path $PSScriptRoot 'dashboard-app/images'
$previewDirectory = Join-Path $PSScriptRoot 'dist/previews'
New-Item -ItemType Directory -Force -Path $assetDirectory,$previewDirectory | Out-Null
function Draw-DashboardText($Graphics,[string]$Text,[int]$Size,[single]$X,[single]$Y,[string]$Color) {
    $font = [Drawing.Font]::new('Segoe UI',$Size,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)
    $brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($Color))
    try {$Graphics.DrawString($Text,$font,$brush,$X,$Y)} finally {$brush.Dispose();$font.Dispose()}
}
function Draw-DashboardContent($Graphics,[string]$Layout,[string]$Color) {
    $clockX=0; $clockY=0; $todayX=12; $todayY=155; $bodyY=215; $weatherX=1000; $weatherY=10; $weatherScale=1.0
    if($Layout -eq 'Agenda Focus') {$weatherX=1160;$weatherY=30;$weatherScale=0.75}
    if($Layout -eq 'Minimal') {$clockX=300;$clockY=180;$todayX=312;$todayY=380;$bodyY=445;$weatherX=1150;$weatherY=215;$weatherScale=0.75}
    Draw-DashboardText $Graphics '23:48' 110 $clockX $clockY $Color
    Draw-DashboardText $Graphics 'TODAY / 3 events' 30 $todayX $todayY $Color
    Draw-DashboardText $Graphics '09:00   Design review' 34 $todayX $bodyY $Color
    if($Layout -ne 'Minimal') {
        Draw-DashboardText $Graphics '13:30   Project planning' 34 $todayX ($bodyY+70) $Color
        Draw-DashboardText $Graphics '17:00   Finish the weekly notes' 34 $todayX ($bodyY+140) $Color
        Draw-DashboardText $Graphics 'NEXT 7 DAYS' 26 12 555 $Color
        $rows=@('Mon  09:00   Team meeting','Tue  14:00   Research discussion','Wed  10:30   Review project milestones','Thu  16:00   Workshop','Fri  11:00   Prepare next week')
        for($i=0;$i -lt $rows.Count;$i++){Draw-DashboardText $Graphics $rows[$i] 24 12 (610+$i*44) $Color}
    }
    $state=$Graphics.Save()
    $Graphics.TranslateTransform($weatherX,$weatherY)
    $Graphics.ScaleTransform($weatherScale,$weatherScale)
    Draw-DashboardText $Graphics 'TUSCALOOSA 35406' 28 0 0 $Color
    Draw-DashboardText $Graphics '20°C' 60 125 45 $Color
    Draw-DashboardText $Graphics 'Clear' 28 0 160 $Color
    if($Layout -ne 'Minimal') {
        Draw-DashboardText $Graphics 'NEXT 24 HOURS' 28 0 220 $Color
        Draw-DashboardText $Graphics 'Low 15°C / High 25°C' 24 0 270 $Color
        $brush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($Color))
        try {for($i=0;$i -lt 24;$i++){$h=25+70*[Math]::Abs([Math]::Sin($i/6));$Graphics.FillRectangle($brush,[single]($i*25),[single](460-$h),14,[single]$h)}}finally{$brush.Dispose()}
        Draw-DashboardText $Graphics '00:00       06:00       12:00       18:00' 20 0 475 $Color
        Draw-DashboardText $Graphics '00:00        03:00        06:00        09:00' 22 0 535 $Color
        Draw-DashboardText $Graphics ' 20°C         18°C         16°C         19°C' 26 0 580 $Color
        Draw-DashboardText $Graphics '12:00        15:00        18:00        21:00' 22 0 650 $Color
        Draw-DashboardText $Graphics ' 24°C         25°C         22°C         20°C' 26 0 695 $Color
        Draw-DashboardText $Graphics 'Weather: Open-Meteo (CC BY 4.0)' 18 0 780 $Color
    }
    $Graphics.Restore($state)
}
foreach($item in @(@{Name='menu-hd.png';Width=290;Height=218},@{Name='menu-fhd.png';Width=540;Height=405})) {
    $bitmap=[Drawing.Bitmap]::new($item.Width,$item.Height)
    $graphics=[Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([Drawing.Color]::Black)
        $graphics.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $scale=[single]($item.Width/540.0);$graphics.ScaleTransform($scale,$scale)
        Draw-DashboardText $graphics '23:48' 100 36 42 '#B0B0B0'
        Draw-DashboardText $graphics 'AGENDA  /  WEATHER  /  READING' 21 42 194 '#888888'
        Draw-DashboardText $graphics 'Remote control. Your layout.' 24 42 240 '#888888'
        Draw-DashboardText $graphics 'Sleep Dashboard' 36 36 320 '#D0D0D0'
        $bitmap.Save((Join-Path $assetDirectory $item.Name),[Drawing.Imaging.ImageFormat]::Png)
    }finally{$graphics.Dispose();$bitmap.Dispose()}
}
foreach($layout in @('Balanced','Agenda Focus','Minimal','Pages settings','Black screen')) {
    $bitmap=[Drawing.Bitmap]::new(1920,1080)
    $graphics=[Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([Drawing.Color]::Black)
        $graphics.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        if($layout -eq 'Pages settings') {
            $state=$graphics.Save();$graphics.TranslateTransform(1020,250);$graphics.ScaleTransform(0.43,0.43)
            Draw-DashboardContent $graphics 'Balanced' '#999999';$graphics.Restore($state)
            Draw-DashboardText $graphics 'LIVE PREVIEW' 22 1020 180 '#484848'
            Draw-DashboardText $graphics 'SLEEP DASHBOARD / PAGES' 30 60 55 '#686868'
            $names=@('Startup page','1. Dashboard [On]','2. Agenda [Off]','3. Weather [Off]','4. News [On]','5. Telegram [On]','6. Clock [Off]')
            $brush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#161616'))
            try{$graphics.FillRectangle($brush,50,219,830,74)}finally{$brush.Dispose()}
            for($i=0;$i -lt $names.Count;$i++){Draw-DashboardText $graphics $names[$i] 23 70 (145+$i*82) '#888888'}
            Draw-DashboardText $graphics 'Dashboard' 21 70 179 '#484848'
            Draw-DashboardText $graphics 'OK: enable/disable   Left/Right: reorder page   Back: return' 20 60 825 '#585858'
            Draw-DashboardText $graphics 'Page 1 / 1 | Changes are saved only with Save.' 18 60 1015 '#404040'
        } elseif($layout -ne 'Black screen') {
            $graphics.TranslateTransform(120,80);Draw-DashboardContent $graphics $layout '#999999';$graphics.ResetTransform()
            Draw-DashboardText $graphics 'Left-Right: pages   Up-Down: items   OK: navigate   *: settings   Play: auto' 20 120 1035 '#777777'
        }
        $name='dashboard-'+$layout.ToLower().Replace(' ','-')+'-readable.png'
        $bitmap.Save((Join-Path $previewDirectory $name),[Drawing.Imaging.ImageFormat]::Png)
    }finally{$graphics.Dispose();$bitmap.Dispose()}
}
Write-Host 'Generated Sleep Dashboard menu tiles and offline layout simulations.'
