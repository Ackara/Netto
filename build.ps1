<#
.SYNOPSIS
A psake bootstraper; This script runs one or more tasks defined in the psake file.

.EXAMPLE
.\build.ps1 -Help;
This example prints a list of all the available tasks.
#>

Param(
	[string[]]$Tasks = @("default"),

	[string]$ArtifactsDirectory = (Join-Path $PSScriptRoot "artifacts"),

	[switch]$Production,
	[switch]$Major,
	[switch]$Minor,
	[string]$VersionSuffix = "-rc",

	[Alias('h')]
	[switch]$Help,

	# ----------------------------------------------------------------------

	[Alias('d')]
	[string]$DeploymentDirectory = (Join-Path "\\IRB-DEVOPS01\Packages" "$(Split-Path $PSScriptRoot -Leaf)\vnext")
)

# Ensuring global dependencies are installed
# ----------------------------------------------------------------------

if (-not ((&npm --version) -match '\d+.\d+')) { throw "'npm' is not accessible."; }
if (-not ((&dotnet --version) -match '\d+.\d+')) { throw "'dotnet' is not accessible."; }
if (-not ((&git --version) -match 'git version \d+\.\d+')) { throw "'git' is not accessible."; }

# Install build dependencies
# ----------------------------------------------------------------------

$PowerShellDependencies = @(
	@{"Name"="psake";"Version"="5.0.4"},
	@{"Name"="Ncrement";"Version"="8.2.18"}
);

$toolsFolder = Join-Path $PSScriptRoot "tools";
foreach ($module in $PowerShellDependencies)
{
	$modulePath = Join-Path $ToolsFolder "$($module.Name)/*/*.psd1";
	if (-not (Test-Path $modulePath)) { Save-Module -Name $module.Name -MaximumVersion $module.Version -Path $ToolsFolder -Force -Confirm:$false; }
	Import-Module $modulePath -Force;
}

&dotnet tool restore | Out-Null;

Add-Type -AssemblyName System.Windows.Forms;

# Assign variables
# ----------------------------------------------------------------------

$buildConfiguration = "Debug";
if ($Production)
{
	$VersionSuffix = "";
    $buildConfiguration = "Release";
}

# Invoke PSAKE tasks
# ----------------------------------------------------------------------

$taskFile = Join-Path $PSScriptRoot "build/tasks.psake.ps1";
if ($Help) { Invoke-Psake -buildFile $taskFile -docs; }
else
{
	Write-Host -ForegroundColor DarkGray "Configuration:    $buildConfiguration";
	Write-Host -ForegroundColor DarkGray "Artifacts:        $ArtifactsDirectory";
	Write-Host "";

	Invoke-psake $taskFile -nologo -taskList $Tasks -properties @{
		"Major"=$Major.IsPresent;
		"Minor"=$Minor.IsPresent;
		"VersionSuffix"=$VersionSuffix;
        "BuildConfiguration"=$buildConfiguration;

		"ToolsFolder"=$toolsFolder;
		"SolutionFolder"=$PSScriptRoot;
		"ArtifactsFolder"=$ArtifactsDirectory;
	}
	if (-not $psake.build_success) { exit 1; }
}
