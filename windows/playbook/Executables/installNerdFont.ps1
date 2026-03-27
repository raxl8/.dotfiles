.\init.ps1

$systemDrive = Get-SystemDrive
$tempDir = Join-Path -Path $systemDrive -ChildPath $([System.Guid]::NewGuid())
New-Item -Force -ItemType Directory -Path $tempDir | Out-Null

$ProgressPreference = "SilentlyContinue"
$url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"
Invoke-WebRequest -Uri $url -OutFile "$tempDir\JetBrainsMono.zip"

$localFontsPath = "$tempDir\JetBrainsMono"
Expand-Archive -LiteralPath "$tempDir\JetBrainsMono.zip" -DestinationPath $localFontsPath
Remove-Item -Force "$tempDir\JetBrainsMono.zip"

$fontsPath = Join-Path -Path $systemDrive -ChildPath "Windows\Fonts"

$fontFiles = Get-ChildItem -Path $localFontsPath -File | Where-Object { $_.Name -like "JetBrainsMonoNerdFont-*.ttf" }
# credits: https://gist.github.com/cosine83/e83c44878a6bdeac0c7c59e3dbfd1f71
$shellFolder = (New-Object -COMObject Shell.Application).Namespace($localFontsPath)
foreach ($fontFile in $fontFiles) {
  $shellFile = $shellFolder.ParseName($fontFile.Name)
  $shellFileType = $shellFolder.GetDetailsOf($shellFile, 2)
  $isTTF = $shellFileType -like "*TrueType font file*"
  $fontName = $shellFolder.GetDetailsOf($shellFile, 21)
  if ($isTTF) {
    $fontName += " (TrueType)"
  }
  New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name $fontName -PropertyType String -Value $fontFile.Name -Force | Out-Null
  Copy-Item -Path $fontFile.FullName -Destination "$fontsPath\$($fontFile.Name)" -Force
}

Remove-Item -Force $tempDir -Recurse
