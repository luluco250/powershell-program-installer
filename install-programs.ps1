function isAdmin() {
	([Security.Principal.WindowsPrincipal] `
	[Security.Principal.WindowsIdentity]::GetCurrent() `
	).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function elevate() {
	if (-not (isAdmin)) {
		$ps = New-Object Diagnostics.ProcessStartInfo 'powershell.exe'
		$ps.Arguments = "-ExecutionPolicy RemoteSigned -File '$($Script:MyInvocation.MyCommand.Path)'"
		$ps.Verb = 'runas'
		[void][Diagnostics.Process]::Start($ps)
		Exit-PSHostProcess
	}
}

$webClient = [Net.WebClient]::new()
function downloadFile($url, $outputPath) {
	$webClient.DownloadFile($url, $outputPath)
}

function parsePrograms($csvFilePath) {
	Write-Host -NoNewLine 'Parsing programs csv...'
	Get-Content $csvFilePath | ConvertFrom-Csv
	Write-Host -ForegroundColor Green 'done!'
}

function downloadPrograms($programs) {
	Write-Host -ForegroundColor Cyan 'Downloading programs...'

	foreach ($p in $programs) {
		if (Test-Path "*$($p.filePath)") {
			Write-Host -ForegroundColor Yellow "Skipping $($p.name), already downloaded!"
			continue
		}

		Write-Host -NoNewline "Downloading $($p.name)..."
		downloadFile $p.url $p.filePath

		if (-not $?) {
			Write-Host -ForegroundColor Red 'failed!'
			continue
		}

		Write-Host -ForegroundColor Green 'done!'
	}

	Write-Host -ForegroundColor Cyan 'Finished downloading programs!'
}

function installPrograms($programs) {
	Write-Host -ForegroundColor Cyan 'Installing programs...'

	foreach ($p in $programs) {
		if (Test-Path "!$($p.filePath)") {
			Write-Host -ForegroundColor Yellow "Skipping $($p.name), already installed!"
			continue
		}

		Write-Host -NoNewLine "Installing $($p.name)..."
		
		if ($p.arguments) {
			$installer = Start-Process $p.filePath $p.arguments -Wait -PassThru -Verb RunAs
		} else {
			$installer = Start-Process $p.filePath -Wait -PassThru -Verb RunAs
		}

		if ($installer.ExitCode -ne 0) {
			Write-Host -ForegroundColor Red 'failed!'
			continue
		}

		Move-Item $p.filePath "!$($p.filePath)"
		Write-Host -ForegroundColor Green 'done!'
	}

	Write-Host -ForegroundColor Cyan 'Finished installing programs!'
}

function main() {
	#elevate

	$programs = parsePrograms '.\programs.csv'
	downloadPrograms $programs
	installPrograms $programs
	
	Write-Host -ForegroundColor Cyan 'Finished! Press any key to quit...'
	[void][Console]::ReadKey($true)
}
main