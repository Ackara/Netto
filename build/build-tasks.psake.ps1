<#
.SYNOPSIS
 Build, test, version, and clean the solution using a structured psake task graph.

.DESCRIPTION
This psakefile defines the core build operations for the solution:
	- BuildSolution: Compile all projects.
	- RunUnitTests: Execute the unit test suite.
	- IncrementVersionNumber: Update project version metadata.
	- Clean: Remove generated artifacts and intermediate build output.

.LINK
https://www.powershellgallery.com/packages/psake/
#>

Properties {
    # Arguments
	$Major = $false;
	$Minor = $false;
    $BuildConfiguration = "Debug";

	# Files & Folders
	$SolutionFolder = (Split-Path $PSScriptRoot -Parent);
	$ManifestFilePath = (Join-Path $PSScriptRoot "manifest.json");
}

Task "BuildSolution" -alias "compile" `
-description "Compile all projects defined in the solution file." `
-action {
	$solutionFile = Join-Path $SolutionFolder "*.slnx" | Get-Item;
	Exec { &dotnet build $solutionFile.FullName --configuration $BuildConfiguration; }
}


Task "RunUnitTests" -alias "test" `
-description "Execute the unit test suite excluding UI tests." `
-action {
	$sln = Join-Path $SolutionFolder "*.sln" | Get-Item;
	Exec { &dotnet test $sln.FullName --filter TestCategory!=ui --configuration $BuildConfiguration --no-build; }
}


Task "IncrementVersionNumber" -alias "version" `
-description "Increment the solution's version number and update all project metadata." `
-action {
	$manifest = $ManifestFilePath | Step-NcrementVersionNumber -Major:$Major -Minor:$Minor -Patch | Edit-NcrementManifest $ManifestFilePath;
	$newVersion = $ManifestFilePath | Select-NcrementVersionNumber;

	foreach ($item in @("*/*/*.*proj", "src/*/package.json"))
	{
		$itemPath = Join-Path $SolutionFolder $item;
		if (-not (Test-Path $itemPath)) { continue; }
		
		foreach ($project in Get-ChildItem $itemPath)
		{
			$project | Update-NcrementProjectFile $ManifestFilePath | Out-Null;
			Write-Host "  * incremented '$($project.Name)' version number to '$newVersion'.";
		}
	}
}


Task "Clean" `
-description "Remove all generated artifacts, test results, and intermediate build output." `
-action {
	foreach ($itemsToRemove in @(
		"artifacts",
		"TestResults",
		"*/*/bin/",
		"*/*/obj/",
		"*/*/node_modules/",
		"*/*/node_module.*",
		"*/*/package-lock.json"
	)) {
		$itemPath = Join-Path $SolutionFolder $itemsToRemove;
		if (Test-Path $itemPath)
		{
			Resolve-Path $itemPath `
				| Write-Value "  * deleted '{0}'." -PassThru `
				| Remove-Item -Recurse -Force;
		}
	}
}

