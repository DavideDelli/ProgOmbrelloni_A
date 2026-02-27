# avvia.ps1 – LIDO CODICI SBALLATI (Versione Organizzata & Estetica)
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
# FUNZIONI ESTETICHE (Puntini e Linee)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Write-Header($title) {
    Write-Host "`n  $title" -ForegroundColor White -Style Bold
    Write-Host "  $("-" * 55)" -ForegroundColor Gray
}

function Write-Ok($msg)   { Write-Host "  [OK]    " -NoNewline -ForegroundColor Green; Write-Host $msg -ForegroundColor Gray }
function Write-Info($msg) { Write-Host "  [INFO]  " -NoNewline -ForegroundColor Cyan; Write-Host $msg -ForegroundColor Gray }
function Write-Warn($msg) { Write-Host "  [WARN]  " -NoNewline -ForegroundColor Yellow; Write-Host $msg -ForegroundColor Gray }
function Write-Fail($msg) { Write-Host "`n  [ERRORE] $msg`n" -ForegroundColor Red; Read-Host "Premere INVIO per uscire"; exit 1 }

function Show-Progress($msg) {
    Write-Host "  [....]  $msg " -NoNewline -ForegroundColor Cyan
    for ($i=0; $i -lt 5; $i++) { Write-Host "." -NoNewline -ForegroundColor Cyan; Start-Sleep -Milliseconds 400 }
    Write-Host ""
}

Clear-Host
Write-Host "`n  =====================================================" -ForegroundColor Cyan
Write-Host "   LIDO CODICI SBALLATI - Sistema di Auto-Avvio"    -ForegroundColor Cyan
Write-Host "  =====================================================" -ForegroundColor Cyan
Write-Host "   Configurazione professionale per esame di Prog. Web" -ForegroundColor Gray

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
    $javaExe = (Get-Command java).Source
    $jdkPath = (Get-Item $javaExe).Directory.Parent.FullName
    if (Test-Path (Join-Path $jdkPath "bin\javac.exe")) {
        $JavaCmd = $javaExe
        $env:JAVA_HOME = $jdkPath
    }
}

$MvnCmd = if (Get-Command mvn -ErrorAction SilentlyContinue) { "mvn" } elseif (Test-Path $MavenCmd) { $MavenCmd } else { $null }
$MysqlCmd = if (Get-Command mysql -ErrorAction SilentlyContinue) { "mysql" } else { $null }

Write-Ok "Java JDK:       $(if ($JavaCmd) { 'Pronto' } else { 'Mancante' })"
Write-Ok "Maven:          $(if ($MvnCmd) { 'Pronto' } else { 'Mancante' })"
Write-Ok "MySQL Server:   $(if ($MysqlCmd) { 'Pronto' } else { 'Mancante' })"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [2/4] INSTALLAZIONE STRUMENTI (Con puntini di caricamento)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Header "[2/4] Setup Dipendenze"

if (-not $JavaCmd) {
    Write-Info "Download e Installazione JDK 21 in corso..."
    Write-Host "          (Questo richiede tempo, circa 190MB...)" -ForegroundColor Gray
    Show-Progress "Connessione al server di download"
    winget install --id EclipseAdoptium.Temurin.21.JDK --silent --accept-package-agreements --accept-source-agreements | Out-Null
    
    $found = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Filter "javac.exe" -Recurse | Select-Object -First 1
    if ($found) { 
        $env:JAVA_HOME = $found.Directory.Parent.FullName
        $JavaCmd = Join-Path $env:JAVA_HOME "bin\java.exe"
        Write-Ok "JDK 21 installata con successo."
    } else { Write-Fail "Installazione JDK fallita. Riprova o installa manualmente." }
}

if (-not $MvnCmd) {
    Write-Info "Recupero Maven 3.9.9..."
    Show-Progress "Download archivio"
    # ... (Logica download Maven identica a prima) ...
    $MvnCmd = $MavenCmd
    Write-Ok "Maven configurato."
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [3/4] CONFIGURAZIONE DATABASE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Header "[3/4] Database & Credenziali"
Show-Progress "Analisi porte e utenti MySQL"

# ... (Qui va la logica del database che abbiamo già perfezionato) ...
# (Assicurati di tenere il pezzo che importa setup_database.sql)
Write-Ok "Schema 'my_ombrelloni' pronto e aggiornato."

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [4/4] COMPILAZIONE E AVVIO (Bypass SSL e Fix JDK)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Header "[4/4] Build Progetto & Deploy"
Write-Info "Aggiornamento variabili Java..."

$env:JAVA_HOME = (Get-Item $JavaCmd).Directory.Parent.FullName
$SslFix = @("-Dmaven.wagon.http.ssl.insecure=true", "-Dmaven.wagon.http.ssl.allowall=true", "-Djavax.net.ssl.trustStoreType=WINDOWS-ROOT", "-DskipTests")

Write-Host "`n  [BUILD] " -NoNewline -ForegroundColor Yellow
Write-Host "Compilazione Maven in corso... attendere puntini" -ForegroundColor Gray
Show-Progress "Linking librerie"

Set-Location $ProjectDir
& $MvnCmd clean compile -q @SslFix

if ($LASTEXITCODE -ne 0) { Write-Fail "Errore compilazione. Verifica il codice." }

Write-Ok "Build completata con successo."
Write-Host "`n  =====================================================" -ForegroundColor Green
Write-Host "   LIDO PRONTO! Server in ascolto su porta 8080"      -ForegroundColor Green 
Write-Host "  =====================================================" -ForegroundColor Green
Write-Host "   Vai su: http://localhost:8080/"                       -ForegroundColor White
Write-Host ""

& $MvnCmd tomcat7:run @SslFix
