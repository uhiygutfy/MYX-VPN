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
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.PointF $x, $y), (New-Object System.Drawing.PointF ($x + $s), ($y + $s)), $Blue, $Red
    $blend = New-Object System.Drawing.Drawing2D.ColorBlend 3
    $blend.Colors = @($Blue, $Violet, $Red); $blend.Positions = @(0.0, 0.55, 1.0)
    $br.InterpolationColors = $blend
    $g.FillPath($br, $path)
    # sheen
    $g.SetClip($path)
    $sheenRect = New-Object System.Drawing.RectangleF $x, $y, $s, ($s * 0.42)
    $sheen = New-Object System.Drawing.Drawing2D.LinearGradientBrush $sheenRect, ([System.Drawing.Color]::FromArgb(70, 255, 255, 255)), ([System.Drawing.Color]::FromArgb(0, 255, 255, 255)), 90
    $g.FillRectangle($sheen, $sheenRect)
    $g.ResetClip()
  }
  # M chevron
  $pen = New-Object System.Drawing.Pen ($(if ($mono) { [System.Drawing.Color]::Transparent } else { [System.Drawing.Color]::White })), ($s * 0.1)
  $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
  $pts = @(
    (New-Object System.Drawing.PointF ($x + $s * 0.27), ($y + $s * 0.66)),
    (New-Object System.Drawing.PointF ($x + $s * 0.27), ($y + $s * 0.33)),
    (New-Object System.Drawing.PointF ($x + $s * 0.5), ($y + $s * 0.53)),
    (New-Object System.Drawing.PointF ($x + $s * 0.73), ($y + $s * 0.33)),
    (New-Object System.Drawing.PointF ($x + $s * 0.73), ($y + $s * 0.66))
  )
  if ($mono) {
    # Knock the M out of the white shield.
    $g.CompositingMode = 'SourceCopy'
    $pen.Color = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
    $g.DrawLines($pen, $pts)
    $g.CompositingMode = 'SourceOver'
  } else {
    $g.DrawLines($pen, $pts)
  }
}

function Fill-Background($g, [int]$n, [string]$shape) {
  $rect = New-Object System.Drawing.Rectangle 0, 0, $n, $n
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $Navy1, $Navy2, 45
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
  # soft blue glow top-left
  $glow = New-Object System.Drawing.Drawing2D.GraphicsPath
  $glow.AddEllipse([int](-$n * 0.3), [int](-$n * 0.3), [int]($n * 1.1), [int]($n * 1.1))
  $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush $glow
  $pgb.CenterColor = [System.Drawing.Color]::FromArgb(60, 47, 107, 255)
  $pgb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 47, 107, 255))
  if ($shape -eq 'circle') { $clip = New-Object System.Drawing.Drawing2D.GraphicsPath; $clip.AddEllipse($rect); $g.SetClip($clip) }
  elseif ($shape -eq 'rounded') { $g.SetClip($p) }
  $g.FillPath($pgb, $glow)
  $g.ResetClip()
}

# kind: full-square | full-rounded | full-circle | foreground | mono
function Render([int]$n, [string]$kind) {
  $bmp = New-Object System.Drawing.Bitmap $n, $n, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'; $g.InterpolationMode = 'HighQualityBicubic'
  $g.Clear([System.Drawing.Color]::Transparent)
  switch ($kind) {
    'full-square'  { Fill-Background $g $n 'square';  $s = $n * 0.56 }
    'full-rounded' { Fill-Background $g $n 'rounded'; $s = $n * 0.56 }
    'full-circle'  { Fill-Background $g $n 'circle';  $s = $n * 0.52 }
    'foreground'   { $s = $n * 0.40 }   # adaptive icon safe zone (66% of 108dp)
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
  (Get-Content $colors -Raw) -replace '#[0-9A-Fa-f]{6,8}', '#0B1022' | Set-Content $colors -Encoding utf8
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
