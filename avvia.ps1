# avvia.ps1 – LIDO CODICI SBALLATI (versione definitiva)
param([string]$ScriptDir = $PSScriptRoot)

$ErrorActionPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-ELEVAZIONE PRIVILEGI (necessaria per installare software)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`" -ScriptDir `"$ScriptDir`"" -Verb RunAs
    exit
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FUNZIONI UI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Write-Ok($msg)   { Write-Host "  [OK]    $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "  [INFO]  $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "  [WARN]  $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "`n  [ERRORE] $msg`n" -ForegroundColor Red; Read-Host "Premere INVIO per uscire"; exit 1 }
function Test-Cmd($cmd)   { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
}

function Install-WithWinget($id) {
    if (-not (Test-Cmd "winget")) { return $false }
    winget install --id $id --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Download-File($url, $dest) {
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        return $true
    } catch { return $false }
}

# Password vuota -> nessun argomento (MySQL accetta connessione senza -p)
# Password piena -> --password=xxx
function Get-MysqlPassArgs($pass) {
    if ($pass -eq "" -or $null -eq $pass) { return @() }
    return @("--password=$pass")
}

Clear-Host
Write-Host ""
Write-Host "  =====================================================" -ForegroundColor Cyan
Write-Host "   LIDO CODICI SBALLATI - Avvio automatico"             -ForegroundColor Cyan
Write-Host "  =====================================================" -ForegroundColor Cyan
Write-Host ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PERCORSI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$ProjectDir = Join-Path $ScriptDir "ProgOmbrelloni_A"
$SqlFile    = Join-Path $ScriptDir "setup_database.sql"
$DbConfig   = Join-Path $ProjectDir "src\main\java\it\unibg\ombrelloni\config\DatabaseManager.java"
$MavenDir   = Join-Path $env:TEMP "mvn_lido\apache-maven-3.9.9"
$MavenCmd   = Join-Path $MavenDir "bin\mvn.cmd"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [1/4] VERIFICA PREREQUISITI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Host "  [1/4] Verifica prerequisiti" -ForegroundColor White
Write-Host "  ---------------------------------------------------"
Write-Host ""

$JavaCmd  = $null
$MvnCmd   = $null
$MysqlCmd = $null

# — Java (cerca JDK, non solo JRE) —
if (Test-Cmd "java") {
    $j = (Get-Command java).Source
    $javac = Join-Path (Split-Path $j) "javac.exe"
    if (Test-Path $javac) { $JavaCmd = $j }
}
if (-not $JavaCmd) {
    $found = Get-ChildItem "C:\Program Files\Eclipse Adoptium","C:\Program Files\Java",
                           "C:\Program Files\Microsoft","C:\Program Files\OpenJDK" `
                -Filter "javac.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $JavaCmd = Join-Path $found.Directory "java.exe" }
}

# — Maven —
if (Test-Cmd "mvn")          { $MvnCmd = "mvn" }
elseif (Test-Path $MavenCmd) { $MvnCmd = $MavenCmd }

# — MySQL —
if (Test-Cmd "mysql") { $MysqlCmd = (Get-Command mysql).Source }
else {
    $searchRoots = @(
        "C:\Program Files\MySQL", "C:\Program Files (x86)\MySQL",
        "C:\xampp", "C:\wamp", "C:\wamp64", "C:\wamp32",
        "C:\laragon", "C:\AppServ", "C:\UniServer",
        "$env:LOCALAPPDATA\Programs", "$env:ProgramData\MySQL",
        "C:\tools", "D:\MySQL", "D:\xampp"
    )
    foreach ($root in $searchRoots) {
        if (Test-Path $root) {
            $found = Get-ChildItem $root -Filter "mysql.exe" -Recurse -ErrorAction SilentlyContinue |
                     Where-Object { $_.FullName -notmatch "\\test\\" } | Select-Object -First 1
            if ($found) { $MysqlCmd = $found.FullName; break }
        }
    }
}

# — File progetto —
$hasProject = Test-Path (Join-Path $ProjectDir "pom.xml")
$hasSql     = Test-Path $SqlFile

# Riepilogo
function Show-Status($val, $okMsg, $koMsg, $okColor, $koColor) {
    if ($val) { Write-Host "   [OK]  $okMsg" -ForegroundColor $okColor }
    else       { Write-Host "   [--]  $koMsg" -ForegroundColor $koColor }
}
Show-Status $JavaCmd    "Java JDK trovato"           "Java JDK non trovato  -> installazione automatica"  Green Yellow
Show-Status $MvnCmd     "Maven trovato"              "Maven non trovato     -> download automatico"        Green Yellow
Show-Status $MysqlCmd   "MySQL trovato"              "MySQL non trovato     -> installazione automatica"   Green Yellow
Show-Status $hasProject "Progetto trovato"           "CARTELLA PROGETTO MANCANTE"                          Green Red
Show-Status $hasSql     "setup_database.sql trovato" "SETUP_DATABASE.SQL MANCANTE"                         Green Red
Write-Host ""

if (-not $hasProject) { Write-Fail "Cartella ProgOmbrelloni_A non trovata in:`n  $ScriptDir" }
if (-not $hasSql)     { Write-Fail "setup_database.sql non trovato in:`n  $ScriptDir" }

$needInstall = (-not $JavaCmd) -or (-not $MvnCmd) -or (-not $MysqlCmd)
if ($needInstall) {
    Write-Host "  I tool mancanti verranno installati automaticamente." -ForegroundColor Cyan
    Write-Host "  Questo richiede connessione internet e qualche minuto." -ForegroundColor Cyan
    $ans = Read-Host "  Continuare? [S/n]"
    if ($ans -match "^[Nn]") { exit 0 }
    Write-Host ""
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [2/4] INSTALLAZIONE DIPENDENZE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Host "  [2/4] Installazione dipendenze" -ForegroundColor White
Write-Host "  ---------------------------------------------------"
Write-Host ""

# ── Java JDK ──────────────────────────────────────────────
if (-not $JavaCmd) {
    Write-Info "Installazione Java JDK 21..."

    # Tentativo 1: winget
    $ok = Install-WithWinget "EclipseAdoptium.Temurin.21.JDK"
    if ($ok) {
        Refresh-Path
        $found = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Filter "javac.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $JavaCmd = Join-Path $found.Directory "java.exe" }
    }

    # Tentativo 2: download diretto MSI (~190MB)
    if (-not $JavaCmd) {
        Write-Info "winget non disponibile. Download diretto JDK (~190 MB)..."
        $msiPath = Join-Path $env:TEMP "temurin21.msi"
        $msiUrl  = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.3%2B9/OpenJDK21U-jdk_x64_windows_hotspot_21.0.3_9.msi"
        if (-not (Download-File $msiUrl $msiPath)) {
            Write-Fail "Download JDK fallito. Verificare la connessione e rieseguire,`noppure installare manualmente da https://adoptium.net/"
        }
        Write-Info "Installazione JDK in corso (1-2 minuti)..."
        $proc = Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /quiet /norestart ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome" -Wait -PassThru
        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        if ($proc.ExitCode -notin @(0, 3010)) {
            Write-Fail "Installazione JDK fallita (codice: $($proc.ExitCode)).`nInstallare manualmente da https://adoptium.net/"
        }
        Refresh-Path
        $found = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Filter "javac.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $JavaCmd = Join-Path $found.Directory "java.exe" }
    }

    if (-not $JavaCmd) { Write-Fail "Installazione Java fallita.`nInstallare manualmente da https://adoptium.net/ e rieseguire." }
    Write-Ok "Java JDK installato"
}

# Imposta JAVA_HOME
$env:JAVA_HOME = (Get-Item $JavaCmd).Directory.Parent.FullName
$env:Path = "$env:JAVA_HOME\bin;" + $env:Path
Write-Ok "JAVA_HOME = $env:JAVA_HOME"

# ── Maven ─────────────────────────────────────────────────
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
        Write-Info "  Download da: $url"
        if (Download-File $url $zipPath) { $downloaded = $true; break }
        else { Write-Warn "  Mirror non raggiungibile, provo il successivo..." }
    }
    if (-not $downloaded) { Write-Fail "Download Maven fallito. Verificare la connessione internet." }
    Write-Info "Estrazione Maven..."
    Expand-Archive -Path $zipPath -DestinationPath $mvnBase -Force
    Remove-Item $zipPath -Force
    $MvnCmd = $MavenCmd
    if (-not (Test-Path $MvnCmd)) { Write-Fail "Estrazione Maven fallita." }
    Write-Ok "Maven pronto"
}

# ── MySQL ─────────────────────────────────────────────────
if (-not $MysqlCmd) {
    Write-Info "MySQL non trovato. Installazione automatica..."

    # Tentativo 1: winget
    $ok = Install-WithWinget "Oracle.MySQL"
    if (-not $ok) { $ok = Install-WithWinget "MySQL.MySQL" }
    if ($ok) {
        Refresh-Path
        Start-Sleep -Seconds 5
        if (Test-Cmd "mysql") { $MysqlCmd = (Get-Command mysql).Source }
        else {
            $found = Get-ChildItem "C:\Program Files\MySQL" -Filter "mysql.exe" -Recurse -ErrorAction SilentlyContinue |
                     Where-Object { $_.FullName -notmatch "\\test\\" } | Select-Object -First 1
            if ($found) { $MysqlCmd = $found.FullName }
        }
    }

    # Tentativo 2: download MSI MySQL
    if (-not $MysqlCmd) {
        Write-Info "winget non disponibile. Download MySQL Installer (~50 MB)..."
        $msiPath = Join-Path $env:TEMP "mysql-installer.msi"
        $msiUrl  = "https://dev.mysql.com/get/Downloads/MySQLInstaller/mysql-installer-community-8.0.40.0.msi"
        if (Download-File $msiUrl $msiPath) {
            Write-Info "Installazione MySQL in corso (qualche minuto)..."
            $proc = Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /quiet /norestart" -Wait -PassThru
            Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
            Refresh-Path
            Start-Sleep -Seconds 8
            $found = Get-ChildItem "C:\Program Files\MySQL" -Filter "mysql.exe" -Recurse -ErrorAction SilentlyContinue |
                     Where-Object { $_.FullName -notmatch "\\test\\" } | Select-Object -First 1
            if ($found) { $MysqlCmd = $found.FullName }
        }
    }

    # Tentativo 3: percorso manuale
    if (-not $MysqlCmd) {
        Write-Warn "Installazione automatica MySQL non riuscita."
        Write-Host ""
        Write-Host "  Opzioni:" -ForegroundColor White
        Write-Host "  1) Inserire il percorso completo di mysql.exe se gia' installato"
        Write-Host "     es: C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
        Write-Host "  2) Installare MySQL da https://dev.mysql.com/downloads/installer/ e rieseguire"
        Write-Host ""
        $manualPath = Read-Host "  Percorso mysql.exe (invio per uscire)"
        if ($manualPath -and (Test-Path $manualPath)) {
            $MysqlCmd = $manualPath
            Write-Ok "MySQL trovato: $MysqlCmd"
        } else {
            Write-Fail "MySQL non disponibile.`nInstallare da https://dev.mysql.com/downloads/installer/ e rieseguire."
        }
    } else {
        Write-Ok "MySQL installato: $MysqlCmd"
    }
}

# Avvia servizio MySQL se fermo
$svc = Get-Service -Name "MySQL*" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($svc -and $svc.Status -ne "Running") {
    Write-Info "Avvio servizio MySQL..."
    Start-Service $svc.Name -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
}

Write-Host ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [3/4] CONFIGURAZIONE DATABASE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Host "  [3/4] Configurazione database" -ForegroundColor White
Write-Host "  ---------------------------------------------------"
Write-Host ""

Write-Info "Rilevamento automatico credenziali MySQL..."
$DbPort = "3306"; $DbUser = $null; $DbPass = $null

# ── Diagnostica pre-connessione ───────────────────────────
Write-Info "mysql.exe usato: $MysqlCmd"
$svcAll = Get-Service -Name "MySQL*","MariaDB*" -ErrorAction SilentlyContinue
if ($svcAll) {
    foreach ($s in $svcAll) {
        Write-Info "Servizio: $($s.Name) -> $($s.Status)"
        if ($s.Status -ne "Running") {
            Write-Info "  Avvio $($s.Name)..."
            Start-Service $s.Name -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 4
            $s.Refresh()
            Write-Info "  Stato dopo avvio: $($s.Status)"
        }
    }
} else {
    Write-Warn "Nessun servizio MySQL trovato - potrebbe essere XAMPP/WAMP standalone"
}
$portOpen = (Test-NetConnection -ComputerName 127.0.0.1 -Port 3306 -InformationLevel Quiet -WarningAction SilentlyContinue 2>$null)
Write-Info "Porta 3306 raggiungibile: $portOpen"
# ─────────────────────────────────────────────────────────

$combos = @(
    @("root",""), @("root","root"), @("root","mysql"),
    @("root","password"), @("root","1234"), @("root","admin"),
    @([System.Environment]::UserName,""),
    @([System.Environment]::UserName,[System.Environment]::UserName),
    @("mysql",""), @("mysql","mysql"), @("admin","admin")
)

# Funzione di test connessione: cmd /c evita blocchi stdin e da LASTEXITCODE affidabile
function Test-MySqlConnection($cmd, $user, $pass, $port) {
    $passStr = if ($pass -ne "" -and $null -ne $pass) { " --password=$pass" } else { "" }
    $cmdLine = "`"$cmd`" -u$user$passStr -P$port --connect-timeout=5 --batch -e `"SELECT 1;`" >NUL 2>NUL"
    cmd /c $cmdLine
    return ($LASTEXITCODE -eq 0)
}

foreach ($c in $combos) {
    $u = $c[0]; $p = $c[1]
    $masked = if ($p -eq "") { "(vuota)" } else { "****" }
    if (Test-MySqlConnection $MysqlCmd $u $p $DbPort) {
        $DbUser = $u; $DbPass = $p
        Write-Ok "Connessione riuscita  ->  utente: $u  password: $masked"
        break
    }
}

if (-not $DbUser) {
    Write-Warn "Credenziali non rilevate automaticamente."
    Write-Host ""
    $DbUser = Read-Host "  Utente MySQL [root]"
    if (-not $DbUser) { $DbUser = "root" }
    # Leggi password come testo normale per evitare problemi con SecureString vuota
    $DbPass = Read-Host "  Password MySQL (invio = vuota)"
    $portIn = Read-Host "  Porta MySQL [3306]"
    if ($portIn) { $DbPort = $portIn }
    Write-Host ""
    if (-not (Test-MySqlConnection $MysqlCmd $DbUser $DbPass $DbPort)) {
        # Seconda chance: mostra l'output reale per debug
        $passArgs = Get-MysqlPassArgs $DbPass
        $dbgOut = & $MysqlCmd -u"$DbUser" @passArgs -P$DbPort --connect-timeout=5 -e "SELECT 1;" 2>&1
        Write-Warn "Output MySQL: $($dbgOut -join ' | ')"
        Write-Fail "Connessione MySQL fallita.`nVerificare che MySQL sia avviato e le credenziali siano corrette."
    }
    Write-Ok "Connessione MySQL riuscita"
}

Write-Info "Importazione database 'my_ombrelloni'..."

# Usa cmd /c con redirect file per evitare problemi con pipeline PowerShell su file grandi
function Invoke-MySqlFile($cmd, $user, $pass, $port, $sqlFile) {
    $passStr = if ($pass -ne "" -and $null -ne $pass) { " --password=$pass" } else { "" }
    $cmdLine = "`"$cmd`" -u$user$passStr -P$port < `"$sqlFile`" >NUL 2>NUL"
    cmd /c $cmdLine
    return $LASTEXITCODE
}

function Invoke-MySqlCmd($cmd, $user, $pass, $port, $query) {
    $passStr = if ($pass -ne "" -and $null -ne $pass) { " --password=$pass" } else { "" }
    $cmdLine = "`"$cmd`" -u$user$passStr -P$port -e `"$query`" >NUL 2>NUL"
    cmd /c $cmdLine
    return $LASTEXITCODE
}

$exitCode = Invoke-MySqlFile $MysqlCmd $DbUser $DbPass $DbPort $SqlFile
if ($exitCode -ne 0) {
    Write-Warn "Database gia' esistente, eseguo reimportazione pulita..."
    Invoke-MySqlCmd $MysqlCmd $DbUser $DbPass $DbPort "DROP DATABASE IF EXISTS my_ombrelloni;" | Out-Null
    $exitCode = Invoke-MySqlFile $MysqlCmd $DbUser $DbPass $DbPort $SqlFile
    if ($exitCode -ne 0) {
        # Mostra l'errore reale
        $passStr = if ($DbPass -ne "" -and $null -ne $DbPass) { " --password=$DbPass" } else { "" }
        $errOut = cmd /c "`"$MysqlCmd`" -u$DbUser$passStr -P$DbPort < `"$SqlFile`" 2>&1"
        Write-Warn "Errore MySQL: $($errOut -join ' | ')"
        Write-Fail "Importazione database fallita.`nVerificare il file setup_database.sql."
    }
}
Write-Ok "Database pronto"
Write-Host ""

# Aggiorna DatabaseManager.java
if (Test-Path $DbConfig) {
    $cfg = Get-Content $DbConfig -Raw
    $cfg = $cfg -replace 'jdbc:mysql://[^/]*/my_ombrelloni[^"]*', "jdbc:mysql://localhost:${DbPort}/my_ombrelloni?useSSL=false&serverTimezone=UTC"
    $cfg = $cfg -replace 'private static final String USER\s*=\s*"[^"]*";',     "private static final String USER = `"$DbUser`";"
    $cfg = $cfg -replace 'private static final String PASSWORD\s*=\s*"[^"]*";', "private static final String PASSWORD = `"$DbPass`";"
    # UTF-8 senza BOM: Java non accetta il BOM (\ufeff) all'inizio del file
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($DbConfig, $cfg, $utf8NoBom)
    Write-Ok "DatabaseManager.java aggiornato"
} else {
    Write-Warn "DatabaseManager.java non trovato in: $DbConfig"
    Write-Warn "Aggiornare manualmente le credenziali prima di usare l'applicazione."
}
Write-Host ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [4/4] COMPILAZIONE E AVVIO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Host "  [4/4] Compilazione e avvio" -ForegroundColor White
Write-Host "  ---------------------------------------------------"
Write-Host ""
Write-Info "Compilazione Maven in corso..."
Write-Info "(Al primo avvio scarica le dipendenze: 1-3 minuti)"
Write-Host ""

$sslFlags = @(
    "-Dmaven.wagon.http.ssl.insecure=true",
    "-Dmaven.wagon.http.ssl.allowall=true",
    "-Djavax.net.ssl.trustStoreType=WINDOWS-ROOT",
    "-DskipTests"
)

Set-Location $ProjectDir
& $MvnCmd clean compile -q @sslFlags
if ($LASTEXITCODE -ne 0) {
    Write-Warn "Compilazione fallita con output ridotto, riprovo mostrando gli errori..."
    Write-Host ""
    & $MvnCmd clean compile @sslFlags
    if ($LASTEXITCODE -ne 0) { Write-Fail "Compilazione fallita.`nVerificare che il codice sorgente non abbia errori." }
}
Write-Ok "Compilazione completata"
Write-Host ""

Write-Host "  =====================================================" -ForegroundColor Green
Write-Host "   Applicazione avviata!" -ForegroundColor Green
Write-Host ""
Write-Host "   Aprire il browser su:  http://localhost:8080/" -ForegroundColor White
Write-Host ""
Write-Host "   Credenziali di test:"
Write-Host "     Cliente:        CLIENTE0001  (Mario Rossi)"
Write-Host "     Amministratore: admin123"
Write-Host ""
Write-Host "   Per fermare: Ctrl+C"
Write-Host "  =====================================================" -ForegroundColor Green
Write-Host ""

& $MvnCmd tomcat7:run @sslFlags
