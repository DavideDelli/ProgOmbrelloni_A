# avvia.ps1 – LIDO CODICI SBALLATI
param([string]$ScriptDir = $PSScriptRoot)

$ErrorActionPreference = "SilentlyContinue"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-ELEVAZIONE PRIVILEGI (Richiede Amministratore)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "  [WARN] Riavvio dello script con privilegi di Amministratore necessari per configurare MySQL..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`" -ScriptDir `"$ScriptDir`"" -Verb RunAs
    exit
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FUNZIONI DI UTILITA'
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Write-Ok($msg)   { Write-Host "  [OK]    $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "  [INFO]  $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "  [WARN]  $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "`n  [ERRORE] $msg`n" -ForegroundColor Red; Read-Host "Premere INVIO per uscire"; exit 1 }
function Test-Cmd($cmd)   { $null = Get-Command $cmd -ErrorAction SilentlyContinue; return $? }

Clear-Host
Write-Host ""
Write-Host "  =====================================================" -ForegroundColor White
Write-Host "   LIDO CODICI SBALLATI - Avvio automatico (Admin)"    -ForegroundColor Cyan
Write-Host "  =====================================================" -ForegroundColor White
Write-Host ""

$ProjectDir = Join-Path $ScriptDir "ProgOmbrelloni_A"
$SqlFile    = Join-Path $ScriptDir "setup_database.sql"
$DbConfig   = Join-Path $ProjectDir "src\main\java\it\unibg\ombrelloni\config\DatabaseManager.java"
$MavenDir   = Join-Path $env:TEMP "mvn_lido\apache-maven-3.9.9"
$MavenCmd   = Join-Path $MavenDir "bin\mvn.cmd"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FASE 1 – Controlla tutto silenziosamente
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Host "[1/4] Verifica prerequisiti" -ForegroundColor White
Write-Host "  ---------------------------------------------------"
Write-Host ""
Write-Info "Controllo cosa e' gia' installato..."
Write-Host ""

$JavaCmd  = $null
$MvnCmd   = $null
$MysqlCmd = $null
$MysqldCmd = $null

if (Test-Cmd "java") { $JavaCmd = "java" }
else {
    $found = Get-ChildItem "C:\Program Files\Eclipse Adoptium","C:\Program Files\Java","C:\Program Files\Microsoft" `
        -Filter "java.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $JavaCmd = $found.FullName }
}

if (Test-Cmd "mvn") { $MvnCmd = "mvn" }
elseif (Test-Path $MavenCmd) { $MvnCmd = $MavenCmd }

if (Test-Cmd "mysql") { $MysqlCmd = "mysql" }
else {
    $candidates  = @(
        "C:\Program Files\MySQL\MySQL Server 9.0\bin\mysql.exe",
        "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe",
        "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe",
        "C:\Program Files\MySQL\MySQL Server 5.7\bin\mysql.exe",
        "C:\xampp\mysql\bin\mysql.exe",
        "C:\wamp64\bin\mysql\mysql8.0.31\bin\mysql.exe",
        "C:\laragon\bin\mysql\mysql-8.0.30-winx64\bin\mysql.exe"
    )
    $candidates += (Get-ChildItem "C:\Program Files\MySQL" -Filter "mysql.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { $MysqlCmd = $c; break } }
}

$hasProject = Test-Path (Join-Path $ProjectDir "pom.xml")
$hasSql     = Test-Path $SqlFile

$statusJ = if ($JavaCmd)    { "[OK]  Trovato" } else { "[--] Non trovato -> verra' installato" }
$statusM = if ($MvnCmd)     { "[OK]  Trovato" } else { "[--] Non trovato -> verra' scaricato" }
$statusD = if ($MysqlCmd)   { "[OK]  Trovato" } else { "[--] Non trovato -> verra' installato" }
$statusP = if ($hasProject) { "[OK]  Trovato" } else { "[!!] Mancante" }
$statusS = if ($hasSql)     { "[OK]  Trovato" } else { "[!!] Mancante" }

$colJ = if ($JavaCmd)    { "Green" } else { "Yellow" }
$colM = if ($MvnCmd)     { "Green" } else { "Yellow" }
$colD = if ($MysqlCmd)   { "Green" } else { "Yellow" }
$colP = if ($hasProject) { "Green" } else { "Red"    }
$colS = if ($hasSql)     { "Green" } else { "Red"    }

Write-Host "   Java             " -NoNewline; Write-Host $statusJ -ForegroundColor $colJ
Write-Host "   Maven            " -NoNewline; Write-Host $statusM -ForegroundColor $colM
Write-Host "   MySQL            " -NoNewline; Write-Host $statusD -ForegroundColor $colD
Write-Host "   Progetto (src)   " -NoNewline; Write-Host $statusP -ForegroundColor $colP
Write-Host "   Database (sql)   " -NoNewline; Write-Host $statusS -ForegroundColor $colS
Write-Host ""

if (-not $hasProject) { Write-Fail "Cartella ProgOmbrelloni_A non trovata in: $ScriptDir" }
if (-not $hasSql)     { Write-Fail "setup_database.sql non trovato in: $ScriptDir" }

$needInstall = (-not $JavaCmd) -or (-not $MvnCmd) -or (-not $MysqlCmd)
if ($needInstall) {
    Write-Host "  I tool mancanti verranno scaricati automaticamente." -ForegroundColor Cyan
    $ans = Read-Host "  Continuare? [S/n]"
    if ($ans -match "^[Nn]") { exit 0 }
    Write-Host ""
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FASE 2 – Installa/scarica quello che manca
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if (-not $JavaCmd) {
    Write-Info "Installazione Java (Temurin 21)..."
    if (Test-Cmd "winget") {
        winget install --id EclipseAdoptium.Temurin.21.JDK --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        $found = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Filter "java.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $JavaCmd = $found.FullName }
    }
    if (-not $JavaCmd) { Write-Fail "Installazione Java fallita.`nInstalla manualmente da adoptium.net" }
    Write-Ok "Java pronto"
}

if (-not $MvnCmd) {
    Write-Info "Download Maven 3.9.9..."
    $mvnBase = Join-Path $env:TEMP "mvn_lido"
    New-Item -ItemType Directory -Path $mvnBase -Force | Out-Null
    $zipPath = Join-Path $mvnBase "maven.zip"
    $urls = @(
        "https://dlcdn.apache.org/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip",
        "https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip"
    )
    $downloaded = $false
    foreach ($url in $urls) {
        try { Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop; $downloaded = $true; break }
        catch { Write-Warn "  Mirror fallito, riprovo..." }
    }
    if (-not $downloaded) { Write-Fail "Download Maven fallito." }
    Expand-Archive -Path $zipPath -DestinationPath $mvnBase -Force
    Remove-Item $zipPath -Force
    $MvnCmd = $MavenCmd
    Write-Ok "Maven pronto"
}

if (-not $MysqlCmd) {
    Write-Info "Installazione MySQL Server..."
    if (Test-Cmd "winget") {
        winget install --id Oracle.MySQL --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        $mysqlPaths = Get-ChildItem "C:\Program Files\MySQL" -Filter "mysql.exe" -Recurse -ErrorAction SilentlyContinue
        if ($mysqlPaths) {
            $MysqlCmd = $mysqlPaths[0].FullName
            $mysqlBinDir = $mysqlPaths[0].DirectoryName
            $MysqldCmd = Join-Path $mysqlBinDir "mysqld.exe"
            
            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($userPath -notmatch [regex]::Escape($mysqlBinDir)) {
                $newPath = $userPath + ";" + $mysqlBinDir
                [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
                $env:PATH = $env:PATH + ";" + $mysqlBinDir
                Write-Info "Cartella MySQL aggiunta al PATH."
            }
        }
    }
    if (-not $MysqlCmd) { Write-Fail "Installazione MySQL fallita." } else { Write-Ok "Pacchetto MySQL installato" }
} else {
    $MysqldCmd = $MysqlCmd -replace "mysql\.exe$", "mysqld.exe"
}

$svcName = "MySQL"
$svc = Get-Service -Name "*mysql*" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($svc) {
    $svcName = $svc.Name
} elseif ($MysqldCmd -and (Test-Path $MysqldCmd)) {
    Write-Info "Inizializzazione demone MySQL in corso..."
    & $MysqldCmd --initialize-insecure --console 2>&1 | Out-Null
    & $MysqldCmd --install $svcName 2>&1 | Out-Null
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
}

if ($svc -and $svc.Status -ne "Running") {
    Start-Service -Name $svcName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3 
}

Write-Host ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Host "[3/4] Configurazione database" -ForegroundColor White
Write-Host "  ---------------------------------------------------"
Write-Host ""

Write-Info "Rilevamento automatico credenziali MySQL..."
$DbPort = "3306"; $DbUser = $null; $DbPass = $null

$combos = @(
    @("root",""), @("root","root"), @("root","mysql"), @("root","password"),
    @([System.Environment]::UserName,""), @([System.Environment]::UserName,[System.Environment]::UserName),
    @("mysql","")
)

foreach ($c in $combos) {
    $u = $c[0]; $p = $c[1]
    
    # Costruiamo l'array di argomenti dinamicamente per evitare il bug del -p vuoto
    $argsCheck = @("-u$u", "-P$DbPort", "-e", "SELECT 1;")
    if ($p) { $argsCheck += "-p$p" }
    
    & $MysqlCmd @argsCheck 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        $DbUser = $u; $DbPass = $p
        $masked = if ($p) { "****" } else { "(vuota)" }
        Write-Ok "Connessione riuscita  ->  utente: $u  password: $masked"
        break
    }
}

if (-not $DbUser) {
    Write-Warn "Rilevamento automatico fallito. Inserire le credenziali."
    Write-Host ""
    $DbUser  = Read-Host "  Utente MySQL"
    $DbPass  = Read-Host "  Password MySQL (invio = vuota)"
    $portIn  = Read-Host "  Porta MySQL [3306]"
    if ($portIn) { $DbPort = $portIn }
    Write-Host ""
    
    $argsCheck = @("-u$DbUser", "-P$DbPort", "-e", "SELECT 1;")
    if ($DbPass) { $argsCheck += "-p$DbPass" }
    
    & $MysqlCmd @argsCheck 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Fail "Connessione MySQL fallita. Verifica le credenziali." }
    Write-Ok "Connessione MySQL riuscita"
}

Write-Info "Importazione database..."
$argsImport = @("-u$DbUser", "-P$DbPort")
if ($DbPass) { $argsImport += "-p$DbPass" }

Get-Content $SqlFile -Raw | & $MysqlCmd @argsImport 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Warn "Database gia' esistente. Reimportazione..."
    
    $argsDrop = @("-u$DbUser", "-P$DbPort", "-e", "DROP DATABASE IF EXISTS my_ombrelloni;")
    if ($DbPass) { $argsDrop += "-p$DbPass" }
    
    & $MysqlCmd @argsDrop 2>&1 | Out-Null
    Get-Content $SqlFile -Raw | & $MysqlCmd @argsImport 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) { Write-Fail "Importazione database fallita. Controlla setup_database.sql" }
}
Write-Ok "Database pronto"
Write-Host ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Host "[4/4] Compilazione e avvio" -ForegroundColor White
Write-Host "  ---------------------------------------------------"
Write-Host ""

Write-Info "Aggiornamento file DatabaseManager.java..."
if (Test-Path $DbConfig) {
    $cfg = Get-Content $DbConfig -Raw
    $cfg = $cfg -replace 'jdbc:mysql://localhost:[0-9]+/my_ombrelloni', "jdbc:mysql://localhost:${DbPort}/my_ombrelloni"
    $cfg = $cfg -replace 'private static final String USER = "[^"]*";',     "private static final String USER = `"$DbUser`";"
    $cfg = $cfg -replace 'private static final String PASSWORD = "[^"]*";', "private static final String PASSWORD = `"$DbPass`";"
    [System.IO.File]::WriteAllText($DbConfig, $cfg)
    Write-Ok "Configurazione Java aggiornata"
} else {
    Write-Warn "File DatabaseManager.java non trovato al percorso previsto."
}
Write-Host ""

Write-Info "Compilazione in corso..."
Write-Info "(Al primo avvio Maven scarica le dipendenze: 1-2 minuti)"
Write-Host ""

Set-Location $ProjectDir
# Forza Java a usare il portachiavi di sicurezza di Windows invece del suo
$env:MAVEN_OPTS = "-Djavax.net.ssl.trustStoreType=WINDOWS-ROOT -Djavax.net.ssl.trustStore=NONE"
& $MvnCmd clean compile -q

if ($LASTEXITCODE -ne 0) { Write-Fail "Compilazione fallita. Controlla il codice sorgente." }

Write-Ok "Compilazione completata"
Write-Host ""
Write-Host "  =====================================================" -ForegroundColor Green
Write-Host "   Applicazione avviata!`n"                              -ForegroundColor Green
Write-Host "   Aprire il browser su:  http://localhost:8080/`n"      -ForegroundColor White
Write-Host "   Credenziali di test:"
Write-Host "     Cliente:        CLIENTE0001  (Mario Rossi)"
Write-Host "     Amministratore: admin123`n"
Write-Host "   Per fermare il server: premi Ctrl+C"
Write-Host "  =====================================================" -ForegroundColor Green
Write-Host ""

& $MvnCmd tomcat7:run @SslFix

Read-Host "Premere INVIO per chiudere..."
