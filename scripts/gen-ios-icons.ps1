$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$src = Resolve-Path 'assets/app_icon.png'
$set = Resolve-Path 'ios/Runner/Assets.xcassets/AppIcon.appiconset'

$sizes = @(20, 29, 40, 60, 76, 83.5, 1024)
$scales = @(1, 2, 3)

foreach ($s in $sizes) {
  foreach ($sc in $scales) {
    if ($s -eq 1024 -and $sc -ne 1) { continue }
    if ($s -eq 83.5 -and $sc -ne 2) { continue }
    if ($s -eq 76 -and $sc -gt 2) { continue }
    if ($s -eq 60 -and $sc -eq 1) { continue }

    $px = [int]([math]::Round($s * $sc))
    $fname = "Icon-App-$($s)x$($s)@$($sc)x.png"
    $path = Join-Path $set $fname

    $img = [System.Drawing.Image]::FromFile($src)
    $bmp = New-Object System.Drawing.Bitmap $px, $px
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gfx.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $gfx.DrawImage($img, 0, 0, $px, $px)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $gfx.Dispose()
    $bmp.Dispose()
    $img.Dispose()
  }
}