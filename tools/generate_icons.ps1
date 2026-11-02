# Regenerates every MYX-VPN app icon (Android, iOS, macOS, Windows, Flutter assets)
# from one drawing routine. Existing icon files are overwritten in place at
# their current pixel size.  Run:  powershell -ExecutionPolicy Bypass -File tools\generate_icons.ps1
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')

$Navy1 = [System.Drawing.Color]::FromArgb(255, 18, 28, 66)
$Navy2 = [System.Drawing.Color]::FromArgb(255, 7, 10, 20)
$Blue = [System.Drawing.Color]::FromArgb(255, 47, 107, 255)
$Violet = [System.Drawing.Color]::FromArgb(255, 106, 61, 255)
$Red = [System.Drawing.Color]::FromArgb(255, 255, 45, 85)

function New-ShieldPath([float]$x, [float]$y, [float]$w, [float]$h) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $pt = { param($fx, $fy) New-Object System.Drawing.PointF ($x + $w * $fx), ($y + $h * $fy) }
  $p.AddBezier((& $pt 0.5 0), (& $pt 0.68 0.09), (& $pt 0.84 0.12), (& $pt 0.96 0.13))
  $p.AddLine((& $pt 0.96 0.13), (& $pt 0.96 0.48))
  $p.AddBezier((& $pt 0.96 0.48), (& $pt 0.96 0.74), (& $pt 0.76 0.9), (& $pt 0.5 1))
  $p.AddBezier((& $pt 0.5 1), (& $pt 0.24 0.9), (& $pt 0.04 0.74), (& $pt 0.04 0.48))
  $p.AddLine((& $pt 0.04 0.48), (& $pt 0.04 0.13))
  $p.AddBezier((& $pt 0.04 0.13), (& $pt 0.16 0.12), (& $pt 0.32 0.09), (& $pt 0.5 0))
  $p.CloseFigure()
  return $p
}

function Draw-Shield($g, [float]$x, [float]$y, [float]$s, [bool]$mono) {
  $path = New-ShieldPath $x $y $s $s
  if ($mono) {
    $g.FillPath([System.Drawing.Brushes]::White, $path)
  } else {
    # Left half blue, right half red
    $g.SetClip($path)
    $lr = New-Object System.Drawing.RectangleF $x, $y, ($s / 2), $s
    $rr = New-Object System.Drawing.RectangleF ($x + $s / 2), $y, ($s / 2), $s
    $lb = New-Object System.Drawing.Drawing2D.LinearGradientBrush $lr, ([System.Drawing.Color]::FromArgb(255, 59, 123, 255)), ([System.Drawing.Color]::FromArgb(255, 19, 54, 168)), 90
    $rb = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rr, ([System.Drawing.Color]::FromArgb(255, 255, 75, 92)), ([System.Drawing.Color]::FromArgb(255, 184, 15, 46)), 90
    $g.FillRectangle($lb, $lr); $g.FillRectangle($rb, $rr)
    $sheenRect = New-Object System.Drawing.RectangleF $x, $y, $s, ($s * 0.45)
    $sheen = New-Object System.Drawing.Drawing2D.LinearGradientBrush $sheenRect, ([System.Drawing.Color]::FromArgb(77, 255, 255, 255)), ([System.Drawing.Color]::FromArgb(0, 255, 255, 255)), 90
    $g.FillRectangle($sheen, $sheenRect)
    $g.ResetClip()
    # Inner white rim
    $inner = New-ShieldPath ($x + $s * 0.08) ($y + $s * 0.075) ($s * 0.84) ($s * 0.84)
    $g.DrawPath((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(230, 255, 255, 255)), ([Math]::Max(1, $s * 0.035))), $inner)
  }
  # Padlock (knocked out of a mono shield, white on a colour one)
  $lockColor = if ($mono) { [System.Drawing.Color]::FromArgb(0, 0, 0, 0) } else { [System.Drawing.Color]::White }
  if ($mono) { $g.CompositingMode = 'SourceCopy' }
  $pen = New-Object System.Drawing.Pen $lockColor, ($s * 0.055)
  $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
  $g.DrawArc($pen, ($x + $s * 0.39), ($y + $s * 0.26), ($s * 0.22), ($s * 0.22), 180, 180)
  $g.DrawLine($pen, ($x + $s * 0.39), ($y + $s * 0.37), ($x + $s * 0.39), ($y + $s * 0.44))
  $g.DrawLine($pen, ($x + $s * 0.61), ($y + $s * 0.37), ($x + $s * 0.61), ($y + $s * 0.44))
  $body = New-Object System.Drawing.Drawing2D.GraphicsPath
  $bx = $x + $s * 0.33; $by = $y + $s * 0.43; $bw = $s * 0.34; $bh = $s * 0.27; $br = $s * 0.1
  $body.AddArc($bx, $by, $br, $br, 180, 90); $body.AddArc($bx + $bw - $br, $by, $br, $br, 270, 90)
  $body.AddArc($bx + $bw - $br, $by + $bh - $br, $br, $br, 0, 90); $body.AddArc($bx, $by + $bh - $br, $br, $br, 90, 90)
  $body.CloseFigure()
  $g.FillPath((New-Object System.Drawing.SolidBrush $lockColor), $body)
  if ($mono) { $g.CompositingMode = 'SourceOver' }
  else {
    $navy = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 19, 40, 107))
    $kc = $s * 0.035
    $g.FillEllipse($navy, ($x + $s * 0.5 - $kc), ($y + $s * 0.54 - $kc), (2 * $kc), (2 * $kc))
    $g.FillRectangle($navy, ($x + $s * 0.485), ($y + $s * 0.55), ($s * 0.03), ($s * 0.07))
  }
}

function Fill-Background($g, [int]$n, [string]$shape) {
  $rect = New-Object System.Drawing.Rectangle 0, 0, $n, $n
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(255, 255, 255, 255)), ([System.Drawing.Color]::FromArgb(255, 234, 240, 255)), 60
  switch ($shape) {
    'square' { $g.FillRectangle($bg, $rect) }
    'circle' { $g.FillEllipse($bg, $rect) }
    'rounded' {
      $r = [int]($n * 0.45)
      $p = New-Object System.Drawing.Drawing2D.GraphicsPath
      $p.AddArc(0, 0, $r, $r, 180, 90); $p.AddArc($n - $r - 1, 0, $r, $r, 270, 90)
      $p.AddArc($n - $r - 1, $n - $r - 1, $r, $r, 0, 90); $p.AddArc(0, $n - $r - 1, $r, $r, 90, 90)
      $p.CloseFigure(); $g.FillPath($bg, $p)
    }
  }
}

# kind: full-square | full-rounded | full-circle | foreground | mono
function Render([int]$n, [string]$kind) {
  $bmp = New-Object System.Drawing.Bitmap $n, $n, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'; $g.InterpolationMode = 'HighQualityBicubic'
  $g.Clear([System.Drawing.Color]::Transparent)
  switch ($kind) {
    'full-square'  { Fill-Background $g $n 'square';  $s = $n * 0.62 }
    'full-rounded' { Fill-Background $g $n 'rounded'; $s = $n * 0.62 }
    'full-circle'  { Fill-Background $g $n 'circle';  $s = $n * 0.52 }
    'foreground'   { $s = $n * 0.44 }   # adaptive icon safe zone (66% of 108dp)
    'mono'         { $s = $n * 0.40 }
  }
  $off = ($n - $s) / 2
  Draw-Shield $g $off ($off + $s * 0.02) $s ($kind -eq 'mono')
  $g.Dispose()
  return $bmp
}

function Save-Png($bmp, [string]$path) {
  New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

function Get-Size([string]$path) {
  # Width from the PNG IHDR chunk (GDI+ can't open every PNG variant).
  $b = [System.IO.File]::ReadAllBytes($path)
  $w = ([int]$b[16] -shl 24) -bor ([int]$b[17] -shl 16) -bor ([int]$b[18] -shl 8) -bor [int]$b[19]
  if ($w -gt 0 -and $w -le 4096) { return $w }
  # Non-standard header (e.g. macos "1024-mac.png"): fall back to the name.
  if ((Split-Path $path -Leaf) -match '^(\d+)') { return [int]$Matches[1] }
  throw "Can't determine icon size: $path"
}

$count = 0
# ---- Android launcher icons ----
Get-ChildItem "$root\android\app\src\main\res\mipmap-*\*.png" | ForEach-Object {
  $n = Get-Size $_.FullName
  $kind = switch -Wildcard ($_.Name) {
    # break: "foreground" also matches *round*
    '*foreground*' { 'foreground'; break } '*_round*' { 'full-circle'; break } default { 'full-rounded' }
  }
  Save-Png (Render $n $kind) $_.FullName; $count++
}
# Adaptive background colour
$colors = "$root\android\app\src\main\res\values\ic_launcher_background.xml"
if (Test-Path $colors) {
  [IO.File]::WriteAllText($colors, ((Get-Content $colors -Raw) -replace '#[0-9A-Fa-f]{6,8}', '#FFFFFF'))
}

# ---- Android launch-screen logo (shield on transparent) ----
Get-ChildItem "$root\android\app\src\main\res\drawable-*\splash_logo.png" | ForEach-Object {
  Save-Png (Render (Get-Size $_.FullName) 'foreground') $_.FullName; $count++
}

# ---- iOS / macOS app icons (opaque, the OS applies its own mask) ----
foreach ($dir in @("$root\ios\Runner\Assets.xcassets\AppIcon.appiconset", "$root\macos\Runner\Assets.xcassets\AppIcon.appiconset")) {
  if (-not (Test-Path $dir)) { continue }
  Get-ChildItem "$dir\*.png" | ForEach-Object {
    $n = Get-Size $_.FullName
    $kind = if ($dir -like '*macos*') { 'full-rounded' } else { 'full-square' }
    Save-Png (Render $n $kind) $_.FullName; $count++
  }
}

# ---- Flutter in-app logo assets that show the app icon ----
foreach ($rel in @('assets\images\lantern_logo_rounded.png', 'assets\images\app_icon.png', 'assets\images\lantern_app_icon.png')) {
  $p = Join-Path $root $rel
  if (Test-Path $p) { Save-Png (Render (Get-Size $p) 'full-rounded') $p; $count++ }
}

# ---- Windows .ico (PNG-compressed entries) ----
function Write-Ico([string]$path, [int[]]$sizes) {
  $streams = foreach ($n in $sizes) {
    $ms = New-Object System.IO.MemoryStream
    $b = Render $n 'full-rounded'; $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
    , $ms.ToArray()
  }
  $fs = [System.IO.File]::Create($path); $bw = New-Object System.IO.BinaryWriter $fs
  $bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$sizes.Count)
  $offset = 6 + 16 * $sizes.Count
  for ($i = 0; $i -lt $sizes.Count; $i++) {
    $n = $sizes[$i]; $d = $streams[$i]
    $bw.Write([byte]($(if ($n -ge 256) { 0 } else { $n }))); $bw.Write([byte]($(if ($n -ge 256) { 0 } else { $n })))
    $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([UInt16]1); $bw.Write([UInt16]32)
    $bw.Write([UInt32]$d.Length); $bw.Write([UInt32]$offset); $offset += $d.Length
  }
  foreach ($d in $streams) { $bw.Write($d) }
  $bw.Close()
}
Get-ChildItem "$root\windows" -Recurse -Filter *.ico | ForEach-Object { Write-Ico $_.FullName @(16, 24, 32, 48, 64, 128, 256); $count++ }

# ---- System tray icons (shield only; grey when disconnected) ----
function Render-Tray([int]$n, [bool]$connected, [bool]$darkTaskbar) {
  $bmp = New-Object System.Drawing.Bitmap $n, $n, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::Transparent)
  $s = $n * 0.92; $off = ($n - $s) / 2
  if ($connected) {
    Draw-Shield $g $off $off $s $false
  } else {
    $path = New-ShieldPath $off $off $s $s
    $grey = if ($darkTaskbar) { [System.Drawing.Color]::FromArgb(255, 200, 204, 214) } else { [System.Drawing.Color]::FromArgb(255, 110, 116, 132) }
    $g.FillPath((New-Object System.Drawing.SolidBrush $grey), $path)
  }
  $g.Dispose(); return $bmp
}
$img = "$root\assets\images"
foreach ($t in @(
    @{ f = 'lantern_connected.png'; c = $true; d = $false },
    @{ f = 'lantern_disconnected.png'; c = $false; d = $false },
    @{ f = 'tray_dark_connected.png'; c = $true; d = $true },
    @{ f = 'tray_dark_disconnected.png'; c = $false; d = $true })) {
  $p = Join-Path $img $t.f
  if (Test-Path $p) { Save-Png (Render-Tray (Get-Size $p) $t.c $t.d) $p; $count++ }
}
function Write-TrayIco([string]$path, [bool]$connected) {
  $sizes = @(16, 24, 32, 48)
  $streams = foreach ($n in $sizes) {
    $ms = New-Object System.IO.MemoryStream
    $b = Render-Tray $n $connected $true; $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
    , $ms.ToArray()
  }
  $fs = [System.IO.File]::Create($path); $bw = New-Object System.IO.BinaryWriter $fs
  $bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$sizes.Count)
  $offset = 6 + 16 * $sizes.Count
  for ($i = 0; $i -lt $sizes.Count; $i++) {
    $bw.Write([byte]$sizes[$i]); $bw.Write([byte]$sizes[$i]); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([UInt16]1); $bw.Write([UInt16]32); $bw.Write([UInt32]$streams[$i].Length); $bw.Write([UInt32]$offset)
    $offset += $streams[$i].Length
  }
  foreach ($d in $streams) { $bw.Write($d) }
  $bw.Close()
}
foreach ($t in @(@{ f = 'lantern_connected.ico'; c = $true }, @{ f = 'lantern_disconnected.ico'; c = $false })) {
  $p = Join-Path $img $t.f
  if (Test-Path $p) { Write-TrayIco $p $t.c; $count++ }
}

# Master PNG for stores / README
Save-Png (Render 1024 'full-rounded') "$root\docs\branding\myx-vpn-icon-1024.png"; $count++
Write-Host "Generated $count icon files"
