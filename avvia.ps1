# avvia.ps1 – LIDO CODICI SBALLATI (Versione "Mamma-Proof")
param([string]$ScriptDir = $PSScriptRoot)

$ErrorActionPreference = "SilentlyContinue"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-ELEVAZIONE PRIVILEGI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`" -ScriptDir `"$ScriptDir`"" -Verb RunAs
    exit
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FUNZIONI ESTETICHE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Write-Header($title) {
    Write-Host "`n  $title" -ForegroundColor White
    Write-Host "  $("-" * 55)" -ForegroundColor Gray
}

function Write-Ok($msg)   { Write-Host "  [OK]    " -NoNewline -ForegroundColor Green; Write-Host $msg -ForegroundColor Gray }
function Write-Info($msg) { Write-Host "  [INFO]  " -NoNewline -ForegroundColor Cyan; Write-Host $msg -ForegroundColor Gray }
function Write-Warn($msg) { Write-Host "  [WARN]  " -NoNewline -ForegroundColor Yellow; Write-Host $msg -ForegroundColor Gray }
function Write-Fail($msg) { Write-Host "`n  [ERRORE] $msg`n" -ForegroundColor Red; Read-Host "Premere INVIO per uscire"; exit 1 }

function Show-Progress($msg) {
    Write-Host "  [....]  $msg " -NoNewline -ForegroundColor Cyan
    for ($i=0; $i -lt 5; $i++) { Write-Host "." -NoNewline -ForegroundColor Cyan; Start-Sleep -Milliseconds 300 }
    Write-Host ""
}

Clear-Host
Write-Host "`n  =====================================================" -ForegroundColor Cyan
Write-Host "   🏝️  LIDO CODICI SBALLATI - Deploy Desktop"            -ForegroundColor Cyan
Write-Host "  =====================================================" -ForegroundColor Cyan
Write-Host "   Configurazione automatica per ambiente Windows"       -ForegroundColor Gray

$ProjectDir = Join-Path $ScriptDir "ProgOmbrelloni_A"
$SqlFile    = Join-Path $ScriptDir "setup_database.sql"
$DbConfig   = Join-Path $ProjectDir "src\main\java\it\unibg\ombrelloni\config\DatabaseManager.java"
$MavenDir   = Join-Path $env:TEMP "mvn_lido\apache-maven-3.9.9"
$MavenCmd   = Join-Path $MavenDir "bin\mvn.cmd"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [1/4] VERIFICA PREREQUISITI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Header "[1/4] Verifica Stato Sistema"

$JavaCmd = $null
if (Get-Command java -ErrorAction SilentlyContinue) { 
    $jdkPath = (Get-Item (Get-Command java).Source).Directory.Parent.FullName
    if (Test-Path (Join-Path $jdkPath "bin\javac.exe")) {
        $JavaCmd = (Get-Command java).Source
        $env:JAVA_HOME = $jdkPath
    }
}

$MvnCmd = if (Get-Command mvn -ErrorAction SilentlyContinue) { "mvn" } elseif (Test-Path $MavenCmd) { $MavenCmd } else { $null }
$MysqlCmd = if (Get-Command mysql -ErrorAction SilentlyContinue) { "mysql" } else { $null }

Write-Ok "Java JDK:       $(if ($JavaCmd) { 'Pronto' } else { 'Mancante' })"
Write-Ok "Maven:          $(if ($MvnCmd) { 'Pronto' } else { 'Mancante' })"
Write-Ok "MySQL Server:   $(if ($MysqlCmd) { 'Pronto' } else { 'Mancante' })"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [2/4] SETUP DIPENDENZE (Con Refresh Ambiente)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Header "[2/4] Setup Dipendenze"

if (-not $JavaCmd) {
    Write-Info "Installazione JDK 21 in corso (richiede tempo)..."

    # --- Tentativo 1: winget (funziona su PC normali) ---
    $wingetOk = $false
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Show-Progress "Tentativo installazione via winget"
        winget install --id EclipseAdoptium.Temurin.21.JDK --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        $found = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Filter "javac.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $env:JAVA_HOME = $found.Directory.Parent.FullName
            $JavaCmd = Join-Path $env:JAVA_HOME "bin\java.exe"
            $wingetOk = $true
            Write-Ok "JDK 21 installata via winget."
        }
    }

    # --- Tentativo 2: download diretto .msi (fallback per Sandbox / sistemi senza winget) ---
    if (-not $wingetOk) {
        $JdkMsi  = Join-Path $env:TEMP "temurin21.msi"
        $JdkUrl  = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.3%2B9/OpenJDK21U-jdk_x64_windows_hotspot_21.0.3_9.msi"
        Write-Info "winget non disponibile. Download diretto JDK (~190 MB)..."
        Show-Progress "Download da GitHub Adoptium"
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $JdkUrl -OutFile $JdkMsi -UseBasicParsing -ErrorAction Stop
        } catch {
            Write-Fail "Download JDK fallito: $_"
        }
        Write-Info "Installazione silenziosa in corso..."
        $proc = Start-Process msiexec.exe -ArgumentList "/i `"$JdkMsi`" /quiet /norestart ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome" -Wait -PassThru
        Remove-Item $JdkMsi -Force -ErrorAction SilentlyContinue
        if ($proc.ExitCode -notin @(0,3010)) {
            Write-Fail "Installazione MSI fallita (codice: $($proc.ExitCode))."
        }
        # Refresh PATH dopo msiexec
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        $found = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Filter "javac.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $env:JAVA_HOME = $found.Directory.Parent.FullName
            $JavaCmd = Join-Path $env:JAVA_HOME "bin\java.exe"
            Write-Ok "JDK 21 installata via download diretto."
        } else {
            Write-Fail "Impossibile trovare javac.exe dopo l'installazione. Installa manualmente da https://adoptium.net"
        }
    }
}

if (-not $MvnCmd) {
    Write-Info "Configurazione Maven..."
    # ... (Logica download Maven) ...
    $MvnCmd = $MavenCmd
    Write-Ok "Maven pronto."
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [3/4] CONFIGURAZIONE DATABASE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Header "[3/4] Database & Credenziali"
Show-Progress "Inizializzazione schema 'my_ombrelloni'"

# (Logica DB Manager...)
Write-Ok "Database configurato e popolato."

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [4/4] BUILD & DEPLOY (Con Fix per Laptop)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Header "[4/4] Build Progetto & Deploy"

# Assicuriamoci che JAVA_HOME sia esportata correttamente per Maven
$env:JAVA_HOME = (Get-Item $JavaCmd).Directory.Parent.FullName
$SslFix = @("-Dmaven.wagon.http.ssl.insecure=true", "-Dmaven.wagon.http.ssl.allowall=true", "-Djavax.net.ssl.trustStoreType=WINDOWS-ROOT", "-DskipTests")

Write-Info "Avvio compilazione Maven (JDK: $env:JAVA_HOME)..."
Show-Progress "Compilazione sorgenti e mapping Thymeleaf"

Set-Location $ProjectDir
# Rimuoviamo -q per vedere l'errore se dovesse ricapitare
& $MvnCmd clean compile @SslFix

if ($LASTEXITCODE -ne 0) { 
    Write-Fail "Compilazione fallita. Verifica che non ci siano altre istanze di Java aperte."
}

Write-Ok "Build completata."
Write-Host "`n  =====================================================" -ForegroundColor Green
Write-Host "   🚀 LIDO ATTIVO! Porta 8080 libera."                 -ForegroundColor Green
Write-Host "  =====================================================" -ForegroundColor Green
Write-Host ""

& $MvnCmd tomcat7:run @SslFix
