# --- CONFIG ---
$PublicIP = "" 
$Username = "ec2-user"
$WorkDir = "$HOME\Downloads" 
$WinSCPPath = "C:\Program Files (x86)\WinSCP\WinSCP.com"
$PuTTYPath  = "C:\Program Files\PuTTY\putty.exe"
$PemFile = "labsuser.pem"
$PpkFile = "labsuser.ppk"
$PemPath = Join-Path $WorkDir $PemFile
$PpkPath = Join-Path $WorkDir $PpkFile
# --- FIM ---

cls

# --- ETAPA 0: PREPARACAO ---
Write-Host "Iniciando conexao..." -f Yellow
try {
    cd $WorkDir
    Write-Host "DIR: $WorkDir"
} catch {
    Write-Error "ERRO: Diretorio $WorkDir nao encontrado."
    pause
    return
}

Remove-Item $PemPath -ErrorAction SilentlyContinue
Remove-Item $PpkPath -ErrorAction SilentlyContinue

if ([string]::IsNullOrWhiteSpace($PublicIP)) {
    $PublicIP = Read-Host "Digite o PublicIP da VM"
    if ([string]::IsNullOrWhiteSpace($PublicIP)) {
        Write-Error "IP vazio. Abortando."
        pause
        return
    }
}

# --- ETAPA 1: CHAVE ---
Write-Host ""
Write-Host "--- ETAPA 1: Chave ---" -f Cyan
Write-Host "COLE sua chave PEM (comecando com -----BEGIN...):"
Write-Host "(Quando terminar, digite 'FIM' em uma linha nova e pressione Enter)" -f Gray

$pemLines = @()
while ($line = Read-Host) {
    if ($line.ToUpper() -eq 'FIM') { break }
    $pemLines += $line
}
$pemContent = $pemLines -join "`n"


if ([string]::IsNullOrWhiteSpace($pemContent)) {
    Write-Error "ERRO: Nenhuma chave inserida."
    pause
    return
}

Set-Content -Path $PemPath -Value $pemContent
Write-Host "$PemFile salvo."

# --- ETAPA 2: CONVERSAO ---
Write-Host ""
Write-Host "--- ETAPA 2: Conversao (WinSCP) ---" -f Cyan
if (-not (Test-Path $WinSCPPath)) {
    Write-Error "ERRO: WinSCP.com nao encontrado em $WinSCPPath."
    pause
    return
}

try {
    & $WinSCPPath /keygen $PemPath /output=$PpkPath
} catch {
    Write-Error "ERRO AO EXECUTAR O WinSCP! $($_.Exception.Message)"
    pause
    return
}

if (-not (Test-Path $PpkPath)) {
    Write-Error "ERRO: Falha ao converter .ppk."
    pause
    return
}
Write-Host "$PpkFile criado com sucesso." -f Green

# --- ETAPA 3: CONEXAO ---
Write-Host ""
Write-Host "--- ETAPA 3: Conexao (PuTTY) ---" -f Cyan
Write-Host "Iniciando: $Username@$PublicIP..."
if (-not (Test-Path $PuTTYPath)) {
    Write-Error "ERRO: putty.exe nao encontrado em $PuTTYPath."
    pause
    return
}

& $PuTTYPath -ssh -i $PpkPath "$Username@$PublicIP"

# --- ETAPA 4: LIMPEZA ---
Write-Host ""
Write-Host "--- ETAPA 4: Limpeza ---" -f Cyan
Write-Host "Sessao PuTTY finalizada."
$Keep = Read-Host "Deseja MANTER os arquivos .pem/.ppk? (s/N)"

if ($Keep.ToLower() -ne 's') {
    Write-Host "Removendo arquivos..."
    Remove-Item $PemPath -ErrorAction SilentlyContinue
    Remove-Item $PpkPath -ErrorAction SilentlyContinue
    Write-Host "Arquivos removidos."
} else {
    Write-Host "Arquivos mantidos."
}

Write-Host "Processo finalizado."
