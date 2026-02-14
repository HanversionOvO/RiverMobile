param(
  [Parameter(Mandatory = $true)][string]$Project,
  [Parameter(Mandatory = $true)][string]$AppId,
  [Parameter(Mandatory = $true)][string]$Name,
  [string]$IconFile = "",
  [string]$Description = "",
  [string]$Tags = "Vue,scaffold",
  [string]$Version = "1.0.0",
  [switch]$SkipBuild,
  [switch]$SkipPackage
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$py = "python"
$cmd = @(
  "$scriptDir/import_scaffold_app.py",
  "--project", $Project,
  "--app-id", $AppId,
  "--name", $Name,
  "--framework", "vue",
  "--version", $Version,
  "--tags", $Tags
)

if ($IconFile) { $cmd += @("--icon-file", $IconFile) }
if ($Description) { $cmd += @("--description", $Description) }
if ($SkipBuild) { $cmd += "--skip-build" }
if ($SkipPackage) { $cmd += "--skip-package" }

& $py @cmd
exit $LASTEXITCODE
