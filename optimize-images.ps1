<#
.SYNOPSIS
  Optimise toutes les images (jpg, png, gif, webp, ico) d'un dossier avec ImageMagick.
  Les originaux ne sont jamais modifiés : le résultat va dans un dossier de sortie.

.EXAMPLE
  .\optimize-images.ps1
  .\optimize-images.ps1 -Source "C:\Photos" -Dest "C:\Photos_web" -MaxSize 800 -Quality 80 -Format webp -Recurse
#>
param(
  [string]$Source  = ".",
  [string]$Dest    = "optimized",
  [int]$MaxSize    = 1600,
  [int]$Quality    = 80,
  [ValidateSet("keep", "webp", "avif", "jpg")][string]$Format = "keep",
  [switch]$Recurse
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
  throw "ImageMagick (magick) est introuvable. Installez-le puis ouvrez un nouveau terminal."
}

$Source = (Resolve-Path $Source).Path
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
$Dest = (Resolve-Path $Dest).Path

$exts  = @(".jpg", ".jpeg", ".png", ".gif", ".webp", ".ico")
$files = Get-ChildItem -Path $Source -File -Recurse:$Recurse |
  Where-Object { $exts -contains $_.Extension.ToLower() -and -not $_.FullName.StartsWith($Dest) }

$totalBefore = 0
$totalAfter  = 0
$count       = 0

foreach ($f in $files) {
  $rel  = $f.FullName.Substring($Source.Length).TrimStart('\', '/')
  $base = $rel.Substring(0, $rel.Length - $f.Extension.Length)
  $ext  = $f.Extension.TrimStart('.').ToLower()

  if ($Format -eq "keep") {
    $target = if ($ext -eq "jpeg") { "jpg" } else { $ext }
  } else {
    $target = $Format
  }

  $out = Join-Path $Dest "$base.$target"
  New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null

  $inputFile = $f.FullName
  if ($ext -eq "ico" -and $target -eq "webp") {
    $iconSizes = [string](& magick identify -format '%w %h|' $f.FullName)
    if ($LASTEXITCODE -ne 0) {
      throw "Impossible de lire les tailles de l'icône : $rel"
    }

    $iconFrames = @($iconSizes.Split('|', [System.StringSplitOptions]::RemoveEmptyEntries))
    if ($iconFrames.Count -eq 0) {
      throw "Aucune taille trouvée dans l'icône : $rel"
    }

    $largestIndex = 0
    $largestArea = 0
    for ($i = 0; $i -lt $iconFrames.Count; $i++) {
      $dimensions = $iconFrames[$i] -split ' '
      $area = [int]$dimensions[0] * [int]$dimensions[1]
      if ($area -gt $largestArea) {
        $largestIndex = $i
        $largestArea = $area
      }
    }
    $inputFile = "$($f.FullName)[$largestIndex]"
  }

  $a = @($inputFile)
  if ($ext -eq "gif" -and $target -eq "webp") {
    $a += "-coalesce"
  }
  $a += @("-auto-orient", "-resize", "${MaxSize}x${MaxSize}>", "-strip")
  switch ($target) {
    "jpg"  { $a += @("-interlace", "Plane", "-sampling-factor", "4:2:0", "-quality", $Quality) }
    "png"  { $a += @("-define", "png:compression-level=9") }
    "webp" { $a += @("-quality", $Quality, "-define", "webp:method=6") }
    "avif" { $a += @("-quality", ($Quality - 22)) }
  }
  $a += $out

  & magick @a 2>$null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out)) {
    Write-Warning "ÉCHEC : $rel"
    continue
  }

  $before = $f.Length
  $after  = (Get-Item $out).Length

  # Si le résultat est plus lourd et que le format n'a pas changé, on garde l'original
  $sameFormat = ($target -eq $ext) -or ($target -eq "jpg" -and $ext -eq "jpeg")
  if ($after -ge $before -and $sameFormat) {
    Copy-Item $f.FullName $out -Force
    $after = $before
  }

  $gain = if ($before -gt 0) { [math]::Round(($before - $after) * 100 / $before) } else { 0 }
  "{0,-50} {1,8:N0} Ko -> {2,8:N0} Ko  (-{3}%)" -f $rel, ($before / 1KB), ($after / 1KB), $gain

  $totalBefore += $before
  $totalAfter  += $after
  $count++
}

"------------------------------------------------------------"
if ($count -eq 0) {
  "Aucune image trouvée dans $Source"
} else {
  $gain = [math]::Round(($totalBefore - $totalAfter) * 100 / $totalBefore)
  "{0} image(s) traitée(s) : {1:N0} Ko -> {2:N0} Ko (-{3}%)" -f $count, ($totalBefore / 1KB), ($totalAfter / 1KB), $gain
  "Résultat dans : $Dest"
}