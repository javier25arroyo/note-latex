<#
.SYNOPSIS
    Sets up a self-contained LaTeX environment on Windows and provides a function to build .tex files.

.DESCRIPTION
    This script performs the following actions:
    1. Verifies the environment (Windows, PowerShell 5+).
    2. Creates a standard directory structure for LaTeX projects.
    3. Installs MiKTeX (a LaTeX distribution) if it's not already installed, using winget or Chocolatey.
    4. Defines a PowerShell function 'Invoke-LatexBuild' to compile LaTeX documents using latexmk.

.USAGE
    1) Run once to set up the environment:
       .\setup-latex-env.ps1

    2) Place your LaTeX source files in the '.\latex-env\src\' directory.
       A template file 'main.tex' is created for you.

    3) Compile your project using the provided function:
       Invoke-LatexBuild -Path '.\latex-env\src\main.tex'

    4) To use a different source file:
       Invoke-LatexBuild -Path '.\latex-env\src\my-document.tex'
#>

# --- Environment Verification ---
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "This script requires PowerShell 5.0 or higher."
    exit 1
}

if (-not ((Get-CimInstance Win32_OperatingSystem).Caption -like "*Windows*")) {
    Write-Error "This script is designed to run on Windows only."
    exit 1
}

# --- Directory Structure Setup ---
$baseDir = ".\latex-env"
$srcDir = Join-Path $baseDir "src"
$buildDir = Join-Path $baseDir "build"
$logsDir = Join-Path $baseDir "logs"
$templatesDir = Join-Path $baseDir "templates"

@(
    $baseDir,
    $srcDir,
    $buildDir,
    $logsDir,
    $templatesDir
) | ForEach-Object {
    if (-not (Test-Path -Path $_ -PathType Container)) {
        Write-Host "Creating directory: $_"
        New-Item -Path $_ -ItemType Directory -Force | Out-Null
    }
}

# --- Create a default main.tex if it doesn't exist ---
$defaultTexFile = Join-Path $srcDir "main.tex"
if (-not (Test-Path $defaultTexFile)) {
    Write-Host "Creating a sample 'main.tex' file in '$srcDir'."
    @'
\documentclass{article}
\title{My First LaTeX Document}
\author{Your Name}
\date{\today}
\begin{document}
\maketitle
\section{Introduction}
Hello, world! This is a sample LaTeX document.
You can edit this file and then run the `Invoke-LatexBuild` command to compile it.
\end{document}
'@ | Set-Content -Path $defaultTexFile -Encoding UTF8
}


# --- LaTeX Installation ---
function Test-LatexTools {
    $pdflatexPath = Get-Command pdflatex -ErrorAction SilentlyContinue
    $latexmkPath = Get-Command latexmk -ErrorAction SilentlyContinue
    return ($null -ne $pdflatexPath) -and ($null -ne $latexmkPath)
}

if (-not (Test-LatexTools)) {
    Write-Host "LaTeX tools (pdflatex, latexmk) not found. Attempting to install MiKTeX..."

    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    $chocoPath = Get-Command choco -ErrorAction SilentlyContinue

    if ($null -ne $wingetPath) {
        Write-Host "Found winget. Installing MiKTeX via winget..."
        Write-Host "This may require administrator privileges. If prompted, please approve the installation."
        try {
            winget install --id MiKTeX.MiKTeX --silent --accept-source-agreements --accept-package-agreements
        } catch {
            Write-Error "Winget installation failed. Please try running PowerShell as an administrator. Error: $_"
            exit 1
        }
    }
    elseif ($null -ne $chocoPath) {
        Write-Host "Found Chocolatey. Installing MiKTeX via choco..."
        Write-Host "This may require administrator privileges. If prompted, please approve the installation."
        try {
            choco install miktex.install -y --force
        } catch {
            Write-Error "Chocolatey installation failed. Please try running PowerShell as an administrator. Error: $_"
            exit 1
        }
    }
    else {
        Write-Host "Neither winget nor Chocolatey were found. Attempting to install MiKTeX using the setup utility..."
        $zipUrl = "https://miktex.org/download/ctan/systems/win32/miktex/setup/windows-x64/miktexsetup-5.5.0+1763023-x64.zip"
        $tempDir = Join-Path $env:TEMP "miktex-setup"
        $zipPath = Join-Path $tempDir "miktex-setup.zip"
        $unzipDir = Join-Path $tempDir "unzipped"
        
        # Create a temporary directory for the setup files
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force
        }
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        New-Item -Path $unzipDir -ItemType Directory -Force | Out-Null

        try {
            Write-Host "Downloading MiKTeX setup utility from $zipUrl..."
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
            
            Write-Host "Extracting setup utility..."
            Expand-Archive -Path $zipPath -DestinationPath $unzipDir -Force
            
            $setupExecutable = Get-ChildItem -Path $unzipDir -Recurse -Filter "miktexsetup_standalone.exe" | Select-Object -First 1 -ExpandProperty FullName
            
            if (-not (Test-Path $setupExecutable)) {
                Write-Error "Could not find 'miktexsetup_standalone.exe' in the extracted archive."
                exit 1
            }

            Write-Host "Starting MiKTeX download via setup utility... This might take a while."
            $downloadProc = Start-Process -FilePath $setupExecutable -ArgumentList "--package-set=basic download" -Wait -PassThru -NoNewWindow
            if ($downloadProc.ExitCode -ne 0) {
                Write-Error "MiKTeX download failed with exit code $($downloadProc.ExitCode)."
                exit 1
            }

            $installDir = Join-Path (Get-Location) "latex-env\miktex"
            New-Item -Path $installDir -ItemType Directory -Force | Out-Null
            
            Write-Host "Starting MiKTeX installation into: $installDir"
            $installProc = Start-Process -FilePath $setupExecutable -ArgumentList "install --user-install=`"$installDir`"" -Wait -PassThru -NoNewWindow
            if ($installProc.ExitCode -ne 0) {
                Write-Error "MiKTeX installation failed with exit code $($installProc.ExitCode)."
                exit 1
            }

            Write-Host "MiKTeX setup complete."

        }
        catch {
            Write-Error "An error occurred during the download or installation of MiKTeX. Error: $_"
            Write-Error "Please try installing MiKTeX manually from https://miktex.org/download"
            exit 1
        }
        finally {
             if (Test-Path $tempDir) {
                Write-Host "Cleaning up temporary setup files..."
                Remove-Item $tempDir -Recurse -Force
            }
        }
    }

    # Refresh environment variables to find the new commands
    Write-Host "Refreshing environment variables to detect the new LaTeX installation..."
    $miktexPath = Join-Path (Get-Location) "latex-env\miktex\miktex\bin\x64"
    if(Test-Path $miktexPath) {
         $env:Path += ";$miktexPath"
    } else {
        # Try the 32-bit path
        $miktexPath = Join-Path (Get-Location) "latex-env\miktex\miktex\bin"
        if(Test-Path $miktexPath) {
            $env:Path += ";$miktexPath"
        } else {
            Write-Warning "Could not find the expected MiKTeX bin directory. You might need to restart your PowerShell session or find the path manually."
        }
    }


    if (-not (Test-LatexTools)) {
        Write-Error "Installation appears to have completed, but 'pdflatex' or 'latexmk' are still not found."
        Write-Error "Please restart your PowerShell session or add the MiKTeX 'bin' directory to your PATH manually."
        exit 1
    }

    Write-Host "MiKTeX installed successfully."
    $init = Get-Command initexmf -ErrorAction SilentlyContinue
    if ($init) { & $init --set-config-value "[MiKTeX]AutoInstall=1" | Out-Null }
}
else {
    Write-Host "LaTeX tools are already installed. Skipping installation."
    $init = Get-Command initexmf -ErrorAction SilentlyContinue
    if ($init) { & $init --set-config-value "[MiKTeX]AutoInstall=1" | Out-Null }
}


# --- Ensure required MiKTeX packages (latexmk + perl) ---
$mpmCmd = Get-Command mpm -ErrorAction SilentlyContinue
if (-not $mpmCmd) {
    $mpmCandidates = @(
        (Join-Path (Get-Location) 'latex-env\miktex\miktex\bin\x64\mpm.exe'),
        (Join-Path (Get-Location) 'latex-env\miktex\miktex\bin\mpm.exe'),
        'C:\Program Files\MiKTeX\miktex\bin\x64\mpm.exe',
        'C:\Program Files (x86)\MiKTeX\miktex\bin\mpm.exe'
    )
    $mpmCmd = $mpmCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if ($mpmCmd) {
    try {
        & $mpmCmd --update-db | Out-Null
        & $mpmCmd --install=latexmk | Out-Null
        & $mpmCmd --install=miktex-perl-bin | Out-Null
    } catch {
        Write-Warning "Could not ensure MiKTeX packages (latexmk/perl): $_"
    }
} else {
    Write-Host "MiKTeX package manager 'mpm' not found; continuing."
}
# --- Build Function Definition ---
function Invoke-LatexBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [string]$Path = ".\latex-env\src\main.tex"
    )

    if (-not (Test-Path -Path $Path)) {
        Write-Error "The specified source file does not exist: $Path"
        return # Exit the function, but not the script
    }

    $sourceFile = Get-Item -Path $Path
    $sourceDir = $sourceFile.DirectoryName
    $sourceFileName = $sourceFile.Name

    Write-Host "Starting LaTeX build for: $Path"

    $outRel = "..\build"  # relative to $sourceDir
    # Resolve absolute output directory based on global $buildDir
    $buildOut = (Resolve-Path $buildDir).Path

    # Prefer latexmk if usable; otherwise fallback to pdflatex (2 passes)
    $useLatexmk = $false
    $lm = Get-Command latexmk -ErrorAction SilentlyContinue
    if ($lm) {
        try {
            $ver = & latexmk -v 2>&1
            if ($LASTEXITCODE -eq 0 -and ($ver -notmatch "script engine 'perl'")) {
                $useLatexmk = $true
            }
        } catch {
            $useLatexmk = $false
        }
    }

    try {
        if ($useLatexmk) {
            $latexmkArgs = @(
                "-pdf",
                "-interaction=nonstopmode",
                "-output-directory=$buildOut",
                "-aux-directory=$buildOut",
                " `"$sourceFileName`" "
            )
            $process = Start-Process "latexmk" -ArgumentList $latexmkArgs -WorkingDirectory $sourceDir -Wait -PassThru -NoNewWindow
        }
        else {
            Write-Warning "latexmk no disponible o sin Perl; usando fallback con pdflatex (2 pasadas)."
            $args = @(
                "-interaction=nonstopmode",
                "-output-directory=$buildOut",
                " `"$sourceFileName`" "
            )
            $p1 = Start-Process "pdflatex" -ArgumentList $args -WorkingDirectory $sourceDir -Wait -PassThru -NoNewWindow
            $p2 = Start-Process "pdflatex" -ArgumentList $args -WorkingDirectory $sourceDir -Wait -PassThru -NoNewWindow
            $process = $p2
        }
        
        # Move log files to the logs directory
        Get-ChildItem -Path $buildOut -Filter "*.log" | Move-Item -Destination $logsDir -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $buildOut -Filter "*.aux" | Remove-Item -Force -ErrorAction SilentlyContinue

        if ($process.ExitCode -eq 0) {
            $pdfOutput = Join-Path $buildDir ($sourceFile.BaseName + ".pdf")
            Write-Host "Build successful! PDF is located at: $pdfOutput" -ForegroundColor Green
        }
        else {
            Write-Error "LaTeX compilation failed with exit code: $($process.ExitCode)."
            $logFile = Join-Path $logsDir ($sourceFile.BaseName + ".log")
            if (Test-Path $logFile) {
                Write-Host "Displaying last 20 lines of the log file: $logFile"
                Get-Content $logFile | Select-Object -Last 20
            }
        }
    } catch {
        Write-Error "An error occurred while trying to run the LaTeX build. Error: $_ "
    }
}

# Export the function so it's available in the current session
if ($MyInvocation.MyCommand.Module) { Export-ModuleMember -Function Invoke-LatexBuild }

Write-Host "`nSetup complete. You can now use the 'Invoke-LatexBuild' function." -ForegroundColor Cyan
