# SYNOPSIS: This is a PSAKE task file.

Include "build-tasks.psake.ps1";

FormatTaskName "$([string]::Concat([System.Linq.Enumerable]::Repeat('-', 70)))`r`n  {0}`r`n$([string]::Concat([System.Linq.Enumerable]::Repeat('-', 70)))";

Properties {
	$Dependencies = @(@{"Name"="Ncrement";"Version"="8.2.18"});
    
    # Arguments
	$Major = $false;
	$Minor = $false;
	$VersionSuffix = $null;
    $BuildConfiguration = "Debug";

	# Files & Folders
	$ToolsFolder = $null;
	$SolutionFolder = $null;
	$ArtifactsFolder = $null;
	$DeploymentFolder = $null;
	$ManifestFilePath = (Join-Path $PSScriptRoot "manifest.json");
}

Task "Default" -depends @("restore");

#region ----- DEPLOYMENT -----------------------------------------------

Task "Publish-WepAppToIIS" -alias "pack" `
-description "This task deploys the ASP.NET web application to IIS by stopping the site, cleaning the installation folder, copying new files, and restarting the site." `
-depends @("pack-msbuild");


Task "Package-MSBuildProject" -alias "pack-msbuild" `
-description "" `
-action {
	if (Test-Path $ArtifactsFolder) { Remove-Item $ArtifactsFolder -Recurse -Force; }
	New-Item $ArtifactsFolder -ItemType Directory | Out-Null;

	$VersionSuffix = "";
	$version = ($ManifestFilePath | Select-NcrementVersionNumber -Format "C") + $VersionSuffix;
	$releaseNotes = "abc def";

	foreach ($pattern in @("src/*.MSBuild/*.csproj"))
	{
		$project = Join-Path $SolutionFolder $pattern | Get-Item;
		Exec { &dotnet pack $project.FullName --version $version --configuration $BuildConfiguration --output $ArtifactsFolder -p:PackageReleaseNotes=$releaseNotes; }
	}
}


Task "Publish-NuGetPackages" -alias "push" `
-description "" `
-precondition { return (Test-Path $ArtifactsFolder -PathType Container) } `
-action {
	foreach ($nupkg in (Get-ChildItem $ArtifactsFolder -Filter "*.nupkg"))
	{
		$nupkg;
	}
}

#endregion


#region ----- FUNCTIONS ------------------------------------------------

function Select-File($description="")
{
	$dialog = New-Object System.Windows.Forms.OpenFileDialog;
	$dialog.InitialDirectory = $SolutionFolder;
	$dialog.Filter = "All files (*.*)|*.*";
	$dialog.Multiselect = $false;
	$dialog.Title = $description;

	if ($dialog.ShowDialog() -eq "OK") {
			return $dialog.FileName;
	}
}

function Write-Separator([string]$Title = "", [int]$length = 70)
{
	$header = [string]::Concat([System.Linq.Enumerable]::Repeat('-', $length));
	if (-not [String]::IsNullOrEmpty($Title))
	{
		$header = $header.Insert(4, " $Title ");
		if ($header.Length -gt $length) { $header = $header.Substring(0, $length); }
	}
	Write-Host "`r`n$header`r`n" -ForegroundColor DarkGray;
}

function Write-Value
{
	Param(
		[Parameter(Mandatory)]
		[string]$FormatString,

		$Arg1, $Arg2,

		[Alias('c', "fg")]
		[System.ConsoleColor]$ForegroundColor = [System.ConsoleColor]::Gray,

		[Parameter(ValueFromPipeline)]
		$InputObject,

		[switch]$PassThru
	)

	PROCESS
	{
		Write-Host ([string]::Format($FormatString, $InputObject, $Arg1, $Arg2)) -ForegroundColor $ForegroundColor;
		if ($PassThru -and $InputObject) { return $InputObject }
	}
}

#endregion
