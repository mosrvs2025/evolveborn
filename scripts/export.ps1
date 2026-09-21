param([string]$Godot = 'godot', [string]$TemplateDirectory = '')
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$presetPath = Join-Path $project 'export_presets.cfg'
$original = Get-Content -Raw $presetPath
try {
 if($TemplateDirectory) {
  $templateRoot = (Resolve-Path $TemplateDirectory).Path.Replace('\','/')
  $patched = $original.Replace('custom_template/debug=""', ('custom_template/debug="'+$templateRoot+'/web_nothreads_debug.zip"'))
  $patched = $patched.Replace('custom_template/release=""', ('custom_template/release="'+$templateRoot+'/web_nothreads_release.zip"'))
  Set-Content $presetPath $patched
 }
 New-Item -ItemType Directory -Force (Join-Path $project 'build/web') | Out-Null
 & $Godot --headless --path $project --editor --import --quit
 if($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
 & $Godot --headless --path $project --export-release Web
 if($LASTEXITCODE -ne 0) { throw 'Web export failed' }
} finally { Set-Content $presetPath $original }
