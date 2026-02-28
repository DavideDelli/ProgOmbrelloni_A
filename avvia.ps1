# avvia.ps1 – LIDO CODICI SBALLATI (versione definitiva)
param([string]$ScriptDir = $PSScriptRoot)

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference    = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-ELEVAZIONE PRIVILEGI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`" -ScriptDir `"$ScriptDir`"" -Verb RunAs
    exit
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FUNZIONI UI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Write-Ok($msg)   { Write-Host "  " -NoNewline; Write-Host " OK " -BackgroundColor DarkGreen -ForegroundColor White -NoNewline; Write-Host "  $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "  " -NoNewline; Write-Host "INFO" -BackgroundColor DarkCyan -ForegroundColor White -NoNewline; Write-Host "  $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "  " -NoNewline; Write-Host "WARN" -BackgroundColor DarkYellow -ForegroundColor White -NoNewline; Write-Host "  $msg" -ForegroundColor Yellow }
function Write-Fail($msg) {
    Write-Host ""
    Write-Host "  " -NoNewline; Write-Host " ERR" -BackgroundColor DarkRed -ForegroundColor White -NoNewline
    Write-Host "  $msg" -ForegroundColor Red
    Write-Host ""
    Read-Host "  Premere INVIO per uscire"
    exit 1
}
function Test-Cmd($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# Spinner animato — gira mentre un blocco di codice esegue in background
function Invoke-WithSpinner {
    param([string]$Message, [scriptblock]$Action)
    $frames  = @("|", "/", "-", "\")
    $job     = Start-Job -ScriptBlock $Action
    $i       = 0
    while ($job.State -eq "Running") {
        $f = $frames[$i % $frames.Length]
        $c = "Cyan"
        Write-Host "`r  " -NoNewline
        Write-Host $f -ForegroundColor $c -NoNewline
        Write-Host "  $Message" -NoNewline -ForegroundColor Gray
        Start-Sleep -Milliseconds 80
        $i++
    }
    # Pulisci la riga dello spinner
    Write-Host ("`r" + (" " * ($Message.Length + 10)) + "`r") -NoNewline
    $result = Receive-Job $job
    Remove-Job $job -Force
    return $result
}

# Spinner semplice per operazioni che non possono girare in background
function Start-Spinner($msg) {
    $script:spinMsg    = $msg
    $script:spinFrames = @("|", "/", "-", "\")
    $script:spinIdx    = 0
    $script:spinTimer  = [System.Diagnostics.Stopwatch]::StartNew()
}
function Update-Spinner {
    if ($script:spinTimer.ElapsedMilliseconds -gt 80) {
        $f = $script:spinFrames[$script:spinIdx % $script:spinFrames.Length]
        Write-Host "`r  $f  $script:spinMsg   " -NoNewline -ForegroundColor Cyan
        $script:spinIdx++
        $script:spinTimer.Restart()
    }
}
function Stop-Spinner($doneMsg) {
    Write-Host ("`r" + (" " * ($script:spinMsg.Length + 10)) + "`r") -NoNewline
    if ($doneMsg) { Write-Ok $doneMsg }
}

# Barra di progresso testuale
function Show-ProgressBar {
    param([string]$Label, [int]$Percent)
    $width   = 35
    $filled  = [int]($width * $Percent / 100)
    $empty   = $width - $filled
    $bar     = ("#" * $filled) + ("." * $empty)
    $pct     = "$Percent%".PadLeft(4)
    Write-Host "`r  " -NoNewline
    Write-Host $bar -ForegroundColor Cyan -NoNewline
    Write-Host " $pct  $Label    " -NoNewline -ForegroundColor Gray
}

# Download con barra di progresso reale
function Download-WithProgress {
    param([string]$Url, [string]$Dest, [string]$Label)

    Write-Host "  Scaricando $Label..." -ForegroundColor Gray

    # curl.exe con --progress-bar stampa direttamente nel terminale (no pipeline, no Out-Null)
    if (Test-Cmd "curl.exe") {
        Write-Host "  " -NoNewline
        curl.exe -L --progress-bar -o "$Dest" "$Url"
        if ($LASTEXITCODE -eq 0 -and (Test-Path $Dest) -and (Get-Item $Dest -ErrorAction SilentlyContinue).Length -gt 100KB) {
            return $true
        }
        Remove-Item $Dest -Force -ErrorAction SilentlyContinue
    }

    # Fallback: WebClient sincrono con aggiornamento manuale ogni secondo
    Write-Host "  [" -NoNewline -ForegroundColor DarkCyan
    try {
        $wc  = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent","Mozilla/5.0")
        $tmpDest = $Dest + ".tmp"
        $task = $wc.DownloadFileTaskAsync($Url, $tmpDest)
        $dots = 0
        while (-not $task.IsCompleted) {
            Start-Sleep -Milliseconds 500
            Write-Host "#" -NoNewline -ForegroundColor Cyan
            $dots++
            if ($dots % 40 -eq 0) {
                $sizeMB = if (Test-Path $tmpDest) { [math]::Round((Get-Item $tmpDest).Length/1MB,1) } else { 0 }
                Write-Host "] $sizeMB MB scaricati" -ForegroundColor Gray
                Write-Host "  [" -NoNewline -ForegroundColor DarkCyan
            }
        }
        $wc.Dispose()
        Write-Host "] fatto!" -ForegroundColor Green
        if (-not $task.IsFaulted -and (Test-Path $tmpDest)) {
            Move-Item $tmpDest $Dest -Force
            return $true
        }
    } catch {
        Write-Host "] errore" -ForegroundColor Red
    }

    # Ultimo fallback silenzioso
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing -ErrorAction Stop
        return $true
    } catch { return $false }
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
}

function Install-WithWinget($id) {
    if (-not (Test-Cmd "winget")) { return $false }
    $job      = Start-Job -ScriptBlock { param($p); winget install --id $p --silent --accept-package-agreements --accept-source-agreements 2>&1 } -ArgumentList $id
    $finished = Wait-Job $job -Timeout 180
    if (-not $finished) { Stop-Job $job; Remove-Job $job -Force; return $false }
    $state    = $job.ChildJobs[0].JobStateInfo.State
    Remove-Job $job -Force
    return ($state -eq "Completed")
}

function Get-MysqlPassArgs($pass) {
    if ($pass -eq "" -or $null -eq $pass) { return @() }
    return @("--password=$pass")
}

function Test-MySqlConnection($cmd, $user, $pass, $port) {
    $passStr = if ($pass -ne "" -and $null -ne $pass) { " --password=$pass" } else { "" }
    $cmdLine = "`"$cmd`" -u$user$passStr -P$port --connect-timeout=5 --batch -e `"SELECT 1;`" >NUL 2>NUL"
    cmd /c $cmdLine
    return ($LASTEXITCODE -eq 0)
}

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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HEADER
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Clear-Host
Write-Host ""
Write-Host "  +===================================================+" -ForegroundColor Cyan
Write-Host "  |                                                   |" -ForegroundColor Cyan
Write-Host "  |   " -ForegroundColor Cyan -NoNewline
Write-Host " LIDO CODICI SBALLATI" -ForegroundColor White -NoNewline
Write-Host "                      |" -ForegroundColor Cyan
Write-Host "  |   " -ForegroundColor Cyan -NoNewline
Write-Host "    Deploy automatico  " -ForegroundColor Gray -NoNewline
Write-Host "                      |" -ForegroundColor Cyan
Write-Host "  |                                                   |" -ForegroundColor Cyan
Write-Host "  +===================================================+" -ForegroundColor Cyan
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
Write-Host "  +- " -NoNewline -ForegroundColor DarkCyan
Write-Host "[1/4] Verifica prerequisiti" -ForegroundColor White
Write-Host "  +--------------------------------------------------" -ForegroundColor DarkCyan
Write-Host ""

$JavaCmd  = $null
$MvnCmd   = $null
$MysqlCmd = $null

Start-Spinner "Scansione sistema in corso..."
Start-Sleep -Milliseconds 300

# Java
if (Test-Cmd "java") {
    $j = (Get-Command java).Source
    if (Test-Path (Join-Path (Split-Path $j) "javac.exe")) { $JavaCmd = $j }
}
if (-not $JavaCmd) {
    $found = Get-ChildItem "C:\Program Files\Eclipse Adoptium","C:\Program Files\Java",
                           "C:\Program Files\Microsoft","C:\Program Files\OpenJDK" `
                -Filter "javac.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $JavaCmd = Join-Path $found.Directory "java.exe" }
}
Update-Spinner

# Maven
if (Test-Cmd "mvn")          { $MvnCmd = "mvn" }
elseif (Test-Path $MavenCmd) { $MvnCmd = $MavenCmd }
Update-Spinner

# MySQL
if (Test-Cmd "mysql") { $MysqlCmd = (Get-Command mysql).Source }
else {
    foreach ($root in @("C:\Program Files\MySQL","C:\Program Files (x86)\MySQL","C:\xampp","C:\wamp","C:\wamp64","C:\wamp32","C:\laragon","C:\AppServ","C:\UniServer","$env:LOCALAPPDATA\Programs","$env:ProgramData\MySQL","C:\tools","D:\MySQL","D:\xampp","C:\mysql_lido")) {
        if (Test-Path $root) {
            $found = Get-ChildItem $root -Filter "mysql.exe" -Recurse -ErrorAction SilentlyContinue |
                     Where-Object { $_.FullName -notmatch "\\test\\" } | Select-Object -First 1
            if ($found) { $MysqlCmd = $found.FullName; break }
        }
    }
}
Update-Spinner

$hasProject = Test-Path (Join-Path $ProjectDir "pom.xml")
$hasSql     = Test-Path $SqlFile
Stop-Spinner $null

# Riepilogo con icone
function Show-StatusLine($val, $label, $okNote, $koNote) {
    Write-Host "  " -NoNewline
    if ($val) {
        Write-Host "  [OK]  " -ForegroundColor Green -NoNewline
        Write-Host $label.PadRight(18) -ForegroundColor White -NoNewline
        Write-Host $okNote -ForegroundColor DarkGreen
    } else {
        Write-Host "  [--]  " -ForegroundColor Yellow -NoNewline
        Write-Host $label.PadRight(18) -ForegroundColor White -NoNewline
        Write-Host $koNote -ForegroundColor Yellow
    }
}

Show-StatusLine $JavaCmd    "Java JDK"         "trovato" "non trovato  ->  installazione automatica"
Show-StatusLine $MvnCmd     "Maven"            "trovato" "non trovato  ->  download automatico"
Show-StatusLine $MysqlCmd   "MySQL"            "trovato" "non trovato  ->  installazione automatica"
Show-StatusLine $hasProject "Progetto (src)"   "trovato" "MANCANTE ← ERRORE CRITICO"
Show-StatusLine $hasSql     "Database SQL"     "trovato" "MANCANTE ← ERRORE CRITICO"
Write-Host ""

if (-not $hasProject) { Write-Fail "Cartella ProgOmbrelloni_A non trovata in:`n  $ScriptDir" }
if (-not $hasSql)     { Write-Fail "setup_database.sql non trovato in:`n  $ScriptDir" }

$needInstall = (-not $JavaCmd) -or (-not $MvnCmd) -or (-not $MysqlCmd)
if ($needInstall) {
    Write-Host "  I tool mancanti verranno scaricati e installati automaticamente." -ForegroundColor Cyan
    Write-Host "  Assicurati di avere una connessione internet attiva." -ForegroundColor DarkCyan
    Write-Host ""
    $ans = Read-Host "  Continuare? [S/n]"
    if ($ans -match "^[Nn]") { exit 0 }
    Write-Host ""
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [2/4] INSTALLAZIONE DIPENDENZE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Host "  +- " -NoNewline -ForegroundColor DarkCyan
Write-Host "[2/4] Installazione dipendenze" -ForegroundColor White
Write-Host "  +--------------------------------------------------" -ForegroundColor DarkCyan
Write-Host ""

# -- Java JDK ----------------------------------------------
if (-not $JavaCmd) {
    Write-Info "Java JDK 21 non trovato. Download in corso..."
    $msiPath = Join-Path $env:TEMP "temurin21.msi"
    $msiUrl  = "https://api.adoptium.net/v3/installer/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse"
    $ok = Download-WithProgress -Url $msiUrl -Dest $msiPath -Label "JDK 21 Adoptium"
    if ($ok) {
        Write-Host ""
        Start-Spinner "Installazione JDK 21 (1-2 minuti)..."
        $proc = Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /quiet /norestart ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome" -Wait -PassThru
        Stop-Spinner $null
        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        if ($proc.ExitCode -in @(0,3010)) {
            Refresh-Path
            $found = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Filter "javac.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $JavaCmd = Join-Path $found.Directory "java.exe" }
        }
    }
    if (-not $JavaCmd) {
        Write-Warn "Download diretto fallito, tentativo winget..."
        Start-Spinner "winget install JDK (max 3 min)..."
        $ok = Install-WithWinget "EclipseAdoptium.Temurin.21.JDK"
        Stop-Spinner $null
        if ($ok) {
            Refresh-Path
            $found = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Filter "javac.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $JavaCmd = Join-Path $found.Directory "java.exe" }
        }
    }
    if (-not $JavaCmd) { Write-Fail "Installazione Java fallita.`nInstallare manualmente da https://adoptium.net/ e rieseguire." }
    Write-Ok "Java JDK installato"
}

$env:JAVA_HOME = (Get-Item $JavaCmd).Directory.Parent.FullName
$env:Path      = "$env:JAVA_HOME\bin;" + $env:Path
Write-Ok "JAVA_HOME -> $env:JAVA_HOME"
Write-Host ""

# -- Maven -------------------------------------------------
if (-not $MvnCmd) {
    Write-Info "Maven non trovato. Download in corso..."
    $mvnBase = Join-Path $env:TEMP "mvn_lido"
    New-Item -ItemType Directory -Path $mvnBase -Force | Out-Null
    $zipPath = Join-Path $mvnBase "maven.zip"
    $downloaded = $false
    foreach ($url in @("https://dlcdn.apache.org/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip","https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip")) {
        if (Download-WithProgress -Url $url -Dest $zipPath -Label "Apache Maven 3.9.9") { $downloaded = $true; break }
        Write-Warn "Mirror non raggiungibile, provo il successivo..."
    }
    if (-not $downloaded) { Write-Fail "Download Maven fallito. Verificare la connessione." }
    Write-Host ""
    Start-Spinner "Estrazione Maven..."
    Expand-Archive -Path $zipPath -DestinationPath $mvnBase -Force
    Stop-Spinner $null
    Remove-Item $zipPath -Force
    $MvnCmd = $MavenCmd
    if (-not (Test-Path $MvnCmd)) { Write-Fail "Estrazione Maven fallita." }
    Write-Ok "Maven pronto"
    Write-Host ""
}

# -- MySQL -------------------------------------------------
if (-not $MysqlCmd) {
    Write-Info "MySQL non trovato. Download ZIP portable in corso..."
    $mysqlBase = "C:\mysql_lido"
    $mysqlZip  = Join-Path $env:TEMP "mysql.zip"
    $mysqlUrl  = "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.40-winx64.zip"
    $ok = Download-WithProgress -Url $mysqlUrl -Dest $mysqlZip -Label "MySQL 8.0 portable"
    if ($ok) {
        Write-Host ""
        Start-Spinner "Estrazione MySQL (~230 MB, pazienza)..."
        Expand-Archive -Path $mysqlZip -DestinationPath "C:\" -Force
        Stop-Spinner $null
        Remove-Item $mysqlZip -Force -ErrorAction SilentlyContinue
        $extracted = Get-ChildItem "C:\" -Filter "mysql-8.0*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($extracted -and $extracted.FullName -ne $mysqlBase) {
            if (Test-Path $mysqlBase) { Remove-Item $mysqlBase -Recurse -Force -ErrorAction SilentlyContinue }
            Rename-Item $extracted.FullName $mysqlBase -ErrorAction SilentlyContinue
            if (-not (Test-Path $mysqlBase)) { $mysqlBase = $extracted.FullName }
        }
        $MysqlCmd  = Join-Path $mysqlBase "bin\mysql.exe"
        $mysqldCmd = Join-Path $mysqlBase "bin\mysqld.exe"
        if (Test-Path $mysqldCmd) {
            $dataDir = Join-Path $mysqlBase "data"
            if (-not (Test-Path $dataDir)) {
                Start-Spinner "Inizializzazione database MySQL..."
                & $mysqldCmd --initialize-insecure --user=root --datadir="$dataDir" 2>&1 | Out-Null
                Stop-Spinner $null
            }
            Start-Spinner "Avvio MySQL..."
            Start-Process $mysqldCmd -ArgumentList "--datadir=`"$dataDir`" --port=3306 --console" -WindowStyle Hidden
            for ($i=0; $i -lt 8; $i++) { Start-Sleep -Seconds 2; Update-Spinner }
            Stop-Spinner $null
        }
    }
    if (-not $MysqlCmd -or -not (Test-Path $MysqlCmd)) {
        Write-Warn "Download ZIP fallito, tentativo winget..."
        Start-Spinner "winget install MySQL (max 3 min)..."
        $ok2 = Install-WithWinget "Oracle.MySQL"
        if (-not $ok2) { $ok2 = Install-WithWinget "MySQL.MySQL" }
        Stop-Spinner $null
        if ($ok2) {
            Refresh-Path; Start-Sleep -Seconds 5
            if (Test-Cmd "mysql") { $MysqlCmd = (Get-Command mysql).Source }
            else {
                $found = Get-ChildItem "C:\Program Files\MySQL" -Filter "mysql.exe" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "\\test\\" } | Select-Object -First 1
                if ($found) { $MysqlCmd = $found.FullName }
            }
        }
    }
    if (-not $MysqlCmd -or -not (Test-Path $MysqlCmd)) {
        Write-Host ""
        Write-Warn "Installazione automatica non riuscita."
        Write-Host "  Inserire il percorso di mysql.exe oppure installare da https://dev.mysql.com" -ForegroundColor Gray
        $manualPath = Read-Host "  Percorso mysql.exe (invio per uscire)"
        if ($manualPath -and (Test-Path $manualPath)) { $MysqlCmd = $manualPath }
        else { Write-Fail "MySQL non disponibile. Installare da https://dev.mysql.com e rieseguire." }
    }
    Write-Ok "MySQL pronto"
    Write-Host ""
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [3/4] CONFIGURAZIONE DATABASE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Host "  +- " -NoNewline -ForegroundColor DarkCyan
Write-Host "[3/4] Configurazione database" -ForegroundColor White
Write-Host "  +--------------------------------------------------" -ForegroundColor DarkCyan
Write-Host ""

# Assicura MySQL in ascolto
$portOpen = (Test-NetConnection -ComputerName 127.0.0.1 -Port 3306 -InformationLevel Quiet -WarningAction SilentlyContinue 2>$null)
if (-not $portOpen) {
    Start-Spinner "Avvio servizio MySQL..."
    foreach ($svcName in @("MySQL","MySQL80","MySQL84","MySQL57","MariaDB")) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne "Running") { Start-Service $svcName -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3 }
    }
    foreach ($n in @("MySQL80","MySQL","MySQL84")) { net start $n 2>&1 | Out-Null; if ($LASTEXITCODE -eq 0) { break } }
    $mysqldPortable = "C:\mysql_lido\bin\mysqld.exe"
    if (Test-Path $mysqldPortable) {
        $dataDir = "C:\mysql_lido\data"
        Start-Process $mysqldPortable -ArgumentList "--datadir=`"$dataDir`" --port=3306 --console" -WindowStyle Hidden
    }
    for ($i=0; $i -lt 5; $i++) {
        Start-Sleep -Seconds 4
        $portOpen = (Test-NetConnection -ComputerName 127.0.0.1 -Port 3306 -InformationLevel Quiet -WarningAction SilentlyContinue 2>$null)
        if ($portOpen) { break }
    }
    Stop-Spinner $null
}

# Rileva credenziali
$DbPort = "3306"; $DbUser = $null; $DbPass = $null
Start-Spinner "Rilevamento credenziali MySQL..."
$combos = @(
    @("root",""),@("root","root"),@("root","mysql"),@("root","password"),
    @("root","1234"),@("root","admin"),
    @([System.Environment]::UserName,""),
    @([System.Environment]::UserName,[System.Environment]::UserName),
    @("mysql",""),@("mysql","mysql"),@("admin","admin")
)
foreach ($c in $combos) {
    $u = $c[0]; $p = $c[1]
    if (Test-MySqlConnection $MysqlCmd $u $p $DbPort) { $DbUser=$u; $DbPass=$p; break }
}
Stop-Spinner $null

if ($DbUser) {
    $masked = if ($DbPass -eq "") { "(vuota)" } else { "****" }
    Write-Ok "Connessione MySQL  ->  utente: $DbUser  password: $masked"
} else {
    Write-Warn "Credenziali non rilevate automaticamente."
    Write-Host ""
    $DbUser = Read-Host "  Utente MySQL [root]"
    if (-not $DbUser) { $DbUser = "root" }
    $DbPass = Read-Host "  Password MySQL (invio = vuota)"
    $portIn = Read-Host "  Porta MySQL [3306]"
    if ($portIn) { $DbPort = $portIn }
    Write-Host ""
    if (-not (Test-MySqlConnection $MysqlCmd $DbUser $DbPass $DbPort)) {
        $passArgs = Get-MysqlPassArgs $DbPass
        $dbgOut   = & $MysqlCmd -u"$DbUser" @passArgs -P$DbPort --connect-timeout=5 -e "SELECT 1;" 2>&1
        Write-Warn "Output MySQL: $($dbgOut -join ' | ')"
        Write-Fail "Connessione MySQL fallita."
    }
    Write-Ok "Connessione MySQL riuscita"
}

# Importazione
Start-Spinner "Importazione database 'my_ombrelloni'..."
$exitCode = Invoke-MySqlFile $MysqlCmd $DbUser $DbPass $DbPort $SqlFile
if ($exitCode -ne 0) {
    Stop-Spinner $null
    Write-Warn "Database già esistente, reimportazione pulita..."
    Start-Spinner "Drop e reimportazione..."
    Invoke-MySqlCmd $MysqlCmd $DbUser $DbPass $DbPort "DROP DATABASE IF EXISTS my_ombrelloni;" | Out-Null
    $exitCode = Invoke-MySqlFile $MysqlCmd $DbUser $DbPass $DbPort $SqlFile
    Stop-Spinner $null
    if ($exitCode -ne 0) {
        $passStr = if ($DbPass -ne "" -and $null -ne $DbPass) { " --password=$DbPass" } else { "" }
        $errOut  = cmd /c "`"$MysqlCmd`" -u$DbUser$passStr -P$DbPort < `"$SqlFile`" 2>&1"
        Write-Warn "Errore MySQL: $($errOut -join ' | ')"
        Write-Fail "Importazione database fallita."
    }
} else {
    Stop-Spinner $null
}
Write-Ok "Database importato"

# Aggiorna DatabaseManager.java
if (Test-Path $DbConfig) {
    $cfg = Get-Content $DbConfig -Raw
    $cfg = $cfg -replace 'jdbc:mysql://[^/]*/my_ombrelloni[^"]*', "jdbc:mysql://localhost:${DbPort}/my_ombrelloni?useSSL=false&serverTimezone=UTC"
    $cfg = $cfg -replace 'private static final String USER\s*=\s*"[^"]*";',     "private static final String USER = `"$DbUser`";"
    $cfg = $cfg -replace 'private static final String PASSWORD\s*=\s*"[^"]*";', "private static final String PASSWORD = `"$DbPass`";"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($DbConfig, $cfg, $utf8NoBom)
    Write-Ok "DatabaseManager.java aggiornato"
} else {
    Write-Warn "DatabaseManager.java non trovato in: $DbConfig"
}
Write-Host ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [4/4] COMPILAZIONE E AVVIO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write-Host "  +- " -NoNewline -ForegroundColor DarkCyan
Write-Host "[4/4] Compilazione e avvio" -ForegroundColor White
Write-Host "  +--------------------------------------------------" -ForegroundColor DarkCyan
Write-Host ""

$sslFlags = @("-Dmaven.wagon.http.ssl.insecure=true","-Dmaven.wagon.http.ssl.allowall=true","-Djavax.net.ssl.trustStoreType=WINDOWS-ROOT","-DskipTests")

Write-Info "Compilazione Maven in corso (1-3 min al primo avvio)..."
Write-Host ""

Set-Location $ProjectDir
# Mostra spinner mentre Maven compila
$compileJob = Start-Job -ScriptBlock {
    param($dir, $mvn, $flags)
    Set-Location $dir
    & $mvn clean compile -q @flags
    return $LASTEXITCODE
} -ArgumentList $ProjectDir, $MvnCmd, $sslFlags

$i = 0
$msgs = @("Compilazione sorgenti...","Download dipendenze Maven...","Elaborazione Thymeleaf...","Generazione classi...","Ottimizzazione build...")
while ($compileJob.State -eq "Running") {
    $label = $msgs[$i % $msgs.Length]
    Show-ProgressBar $label ([math]::Min(95, ($i * 3)))
    Start-Sleep -Milliseconds 200
    $i++
}
Show-ProgressBar "Compilazione completata!" 100
Write-Host ""
$compileExit = Receive-Job $compileJob
Remove-Job $compileJob -Force

if ($compileExit -ne 0) {
    Write-Warn "Compilazione fallita, riprovo con log completo..."
    Write-Host ""
    & $MvnCmd clean compile @sslFlags
    if ($LASTEXITCODE -ne 0) { Write-Fail "Compilazione fallita. Verificare il codice sorgente." }
}
Write-Ok "Build completata"
Write-Host ""

# Banner finale
Write-Host "  +===================================================+" -ForegroundColor Green
Write-Host "  |                                                   |" -ForegroundColor Green
Write-Host "  |   " -ForegroundColor Green -NoNewline
Write-Host " APPLICAZIONE AVVIATA!" -ForegroundColor White -NoNewline
Write-Host "                     |" -ForegroundColor Green
Write-Host "  |                                                   |" -ForegroundColor Green
Write-Host "  |   " -ForegroundColor Green -NoNewline
Write-Host "->   http://localhost:8080/" -ForegroundColor Cyan -NoNewline
Write-Host "                   |" -ForegroundColor Green
Write-Host "  |                                                   |" -ForegroundColor Green
Write-Host "  |   " -ForegroundColor Green -NoNewline
Write-Host "Credenziali:" -ForegroundColor Gray -NoNewline
Write-Host "                              |" -ForegroundColor Green
Write-Host "  |   " -ForegroundColor Green -NoNewline
Write-Host "  Cliente:  CLIENTE0001  (Mario Rossi)" -ForegroundColor White -NoNewline
Write-Host "     |" -ForegroundColor Green
Write-Host "  |   " -ForegroundColor Green -NoNewline
Write-Host "  Admin:    admin123" -ForegroundColor White -NoNewline
Write-Host "                         |" -ForegroundColor Green
Write-Host "  |                                                   |" -ForegroundColor Green
Write-Host "  |   " -ForegroundColor Green -NoNewline
Write-Host "Ctrl+C per fermare" -ForegroundColor DarkGray -NoNewline
Write-Host "                          |" -ForegroundColor Green
Write-Host "  +===================================================+" -ForegroundColor Green
Write-Host ""

& $MvnCmd tomcat7:run @sslFlags
