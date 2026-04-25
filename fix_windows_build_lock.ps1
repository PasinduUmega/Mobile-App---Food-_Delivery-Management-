$ErrorActionPreference = "SilentlyContinue"

Write-Host "Stopping processes that may lock build folders..."
$processes = @("java", "gradle", "adb", "dart", "flutter")
foreach ($p in $processes) {
  taskkill /F /IM "$p.exe" /T | Out-Null
}

function Remove-FolderHard($path) {
  if (-not (Test-Path $path)) { return }
  Write-Host "Removing: $path"
  # Try PowerShell first
  Remove-Item -Recurse -Force $path
  if (Test-Path $path) {
    # Fallback for stubborn/symlinked folders on OneDrive
    cmd /c "attrib -R /S /D `"$path\*`"" | Out-Null
    cmd /c "rd /s /q `"$path`"" | Out-Null
  }
}

Write-Host "Removing readonly attributes..."
attrib -R /S /D ".\*" | Out-Null

Write-Host "Deleting generated directories..."
$paths = @(
  ".dart_tool",
  "build",
  "android\.gradle",
  "windows\flutter\ephemeral",
  "linux\flutter\ephemeral",
  "macos\Flutter\ephemeral",
  "ios\Flutter\ephemeral"
)

foreach ($path in $paths) {
  Remove-FolderHard $path
}

# Extra cleanup for the current Gradle failure:
# "AssetManifest.bin: not a regular file"
Write-Host "Deleting problematic Android intermediates..."
Remove-FolderHard "build\app\intermediates\flutter"
Remove-FolderHard "build\app\intermediates\assets"
Remove-FolderHard "build\app\intermediates\incremental"

Write-Host "Running flutter clean..."
flutter clean

Write-Host "Running Gradle clean (no daemon)..."
if (Test-Path "android\gradlew.bat") {
  Push-Location "android"
  .\gradlew.bat clean --no-daemon
  Pop-Location
}

Write-Host "Running flutter pub get..."
flutter pub get

Write-Host "Done. If build still fails, move project outside OneDrive (e.g. C:\dev\food-delivery)."
