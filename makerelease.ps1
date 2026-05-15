# @makerelease.ps1
# Automates the build and release process for XkcdDelphiCli

$ErrorActionPreference = "Stop"

Write-Host "Starting release process..." -ForegroundColor Cyan

# 0. Stamp the actual commit hash
$ShortHash = (git rev-parse --short HEAD).Trim()
Write-Host "Stamping binaries with commit hash: $ShortHash" -ForegroundColor Yellow

$FilesToStamp = Get-ChildItem -Path "src/*.dproj", "src/xkcdversion.pas"
foreach ($File in $FilesToStamp) {
    $Content = Get-Content -Path $File.FullName -Raw
    if ($Content -match "\?hash\?") {
        Write-Host "Stamping $($File.Name)..."
        $NewContent = $Content -replace "\?hash\?", $ShortHash
        $NewContent | Out-File -FilePath $File.FullName -Encoding utf8 -NoNewline
    }
}

# Get the version string from the stamped file for tagging
$VersionLine = Get-Content "src/xkcdversion.pas" | Where-Object { $_ -match "CAppVersion = '(.+)';" }
if ($VersionLine -match "'(.+)'") {
    $Version = $Matches[1]
} else {
    Write-Error "Could not determine version from src/xkcdversion.pas"
}

$Tag = "v$Version"
Write-Host "Building version $Version..." -ForegroundColor Cyan

try {
    # 1. Build for all platforms in Release mode
    $Platforms = @("Win32", "Win64", "Linux64")
    $ProjectFile = "src\xkcd.dproj"
    $BuildScript = "C:\Users\jim\.agents\skills\delphi-build\scripts\DelphiBuildDPROJ.ps1"

    foreach ($Platform in $Platforms) {
        Write-Host "Building for $Platform..." -ForegroundColor Yellow
        pwsh -File $BuildScript -ProjectFile $ProjectFile -Config Release -Platform $Platform
    }

    # 2. Generate PDF Documentation
    Write-Host "Generating PDF documentation using Pandoc..." -ForegroundColor Yellow
    $HtmlFile = Join-Path $PWD "README.html"
    $PdfFile  = Join-Path $PWD "README.pdf"
    $EdgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

    if (Test-Path $PdfFile) { Remove-Item $PdfFile }
    pandoc README.md -s -o $HtmlFile

    if (Test-Path $HtmlFile) {
        $HtmlUri = "file:///" + $HtmlFile.Replace('\', '/')
        & $EdgePath --headless --disable-gpu --print-to-pdf=$PdfFile $HtmlUri
        
        $MaxRetries = 5
        $RetryCount = 0
        while (!(Test-Path $PdfFile) -and ($RetryCount -lt $MaxRetries)) {
            Start-Sleep -Seconds 1
            $RetryCount++
        }
        
        if (Test-Path $PdfFile) {
            Write-Host "PDF generated successfully." -ForegroundColor Green
            Remove-Item $HtmlFile
        } else {
            Write-Error "Failed to generate README.pdf"
        }
    }

    # 3. Package archives
    Write-Host "Packaging archives..." -ForegroundColor Yellow
    $ReleaseDir = Join-Path $PWD "releases"
    $StagingDir = Join-Path $PWD "staging"
    if (!(Test-Path $ReleaseDir)) { New-Item -ItemType Directory -Path $ReleaseDir }

    foreach ($Platform in $Platforms) {
        $ArchiveName = "xkcd-$Version-$Platform.7z"
        $ArchivePath = Join-Path $ReleaseDir $ArchiveName
        
        # Create a fresh staging directory for this platform to ensure flatness
        $PlatformStaging = Join-Path $StagingDir $Platform
        if (Test-Path $PlatformStaging) { Remove-Item -Recurse -Force $PlatformStaging }
        New-Item -ItemType Directory -Path $PlatformStaging
        
        $BinDir = "bin\$Platform\Release"
        $FilesToStage = @(
            (Join-Path $BinDir "xkcd.exe")
            (Join-Path $BinDir "xkcd")
            (Join-Path $BinDir "sk4d.dll")
            (Join-Path $BinDir "libsk4d.so")
            "README.pdf"
            "LICENSE"
        )
        
        foreach ($File in $FilesToStage) {
            if (Test-Path $File) {
                Copy-Item $File $PlatformStaging
            }
        }

        Write-Host "Creating $ArchiveName..."
        if (Test-Path $ArchivePath) { Remove-Item $ArchivePath }
        
        # Run 7z from inside the staging directory to avoid path preservation
        Push-Location $PlatformStaging
        & 7z a -t7z $ArchivePath *
        Pop-Location
    }
    
    if (Test-Path $StagingDir) { Remove-Item -Recurse -Force $StagingDir }

    # 4. GitHub Release
    if ($args -contains "--push") {
        Write-Host "Generating changelog..." -ForegroundColor Yellow
        $LastTag = (git describe --tags --abbrev=0 2>$null)
        if ($LastTag) {
            $Changelog = (git log "$LastTag..HEAD" --pretty=format:"* %s") -join "`n"
            Write-Host "Changelog generated since $LastTag" -ForegroundColor Gray
        } else {
            $Changelog = (git log -n 20 --pretty=format:"* %s") -join "`n"
            Write-Host "No previous tag found. Using last 20 commits for changelog." -ForegroundColor Gray
        }

        Write-Host "Pushing release to GitHub..." -ForegroundColor Yellow
        $Archives = Get-ChildItem -Path $ReleaseDir -Filter "xkcd-$Version-*.7z" | Select-Object -ExpandProperty FullName
        
        # Write changelog to a temp file to avoid command line length issues
        $NotesFile = [System.IO.Path]::GetTempFileName()
        $Changelog | Out-File -FilePath $NotesFile -Encoding utf8
        
        & gh release create $Tag $Archives --title "Release $Version" --notes-file $NotesFile
        
        Remove-Item $NotesFile -ErrorAction SilentlyContinue
        Write-Host "Release $Tag pushed successfully!" -ForegroundColor Green
    }

} finally {
    # 5. Revert the hash stamping to keep the repo clean
    Write-Host "Cleaning up stamped files..." -ForegroundColor Gray
    git restore src/*.dproj src/xkcdversion.pas
}

Write-Host "Release process completed." -ForegroundColor Green
