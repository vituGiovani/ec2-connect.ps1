# Automação de Conexão SSH para AWS EC2 (PowerShell)

Este documento explica passo a passo como **criar** e **executar** o script `ec2-connect.ps1` que automatiza o processo de conectar em uma instância EC2 da AWS usando o PuTTY e WinSCP.

---

## 1. Objetivo do script

O script automatiza a seguinte sequência de ações que você faria manualmente **pelo PowerShell**:

1.  Salvar o conteúdo da chave PEM copiada em um arquivo (ex: `$HOME\Downloads\labsuser.pem`).
2.  Executar o comando `WinSCP.com /keygen` para converter manualmente o `.pem` em `.ppk`.
3.  Executar o comando `putty.exe -ssh -i labsuser.ppk ec2-user@<public-ip>` para iniciar a conexão.
4.  Opcionalmente apagar os arquivos `.pem` e `.ppk` após a desconexão.

---

## 2. Preparando o ambiente (diretórios e arquivos)

1. Abra o PowerShell (no Windows):

```powershell
# Cria uma pasta 'scripts' (se ainda não existir)
mkdir ~/scripts -F
```

2. Crie o arquivo do script e cole o conteúdo (exemplo: usando `notepad`):

```bash
notepad ~/scripts/ec2-connect.ps1
# cole o conteúdo do script e salve: Ctrl+S, fechar o Notepad
```

Se preferir usar o nano no Windows, instale-o com o comando: winget install GNU.Nano

```bash
nano ~/scripts/ec2-connect.ps1
# cole o conteúdo do script e salve: Ctrl+O, Enter; sair: Ctrl+X
```

> Dica: você pode usar outro editor (`vim`, `code`, `gedit`) se preferir.

---

## 3. Ajustar a Política de Execução do PowerShell

Execute o comando abaixo em um terminal PowerShell (como Administrador) para permitir a execução de scripts locais.

```powershell
Set-ExecutionPolicy RemoteSigned
```

## 4. Conteúdo sugerido para `ec2-connect.ps1` (interativo)

> **Observação:** este é o script interativo que pede para você colar a chave PEM e o IP.

```bash
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
```

---

Isso permite executar o script diretamente com `./ec2-connect.ps1`.

---

## 5. Executando o script

Existem duas formas principais:

* Entrando na pasta e executando:

```bash
cd ~/scripts
./ec2-connect.ps1
```

* Executando pelo caminho completo:

```bash
~/scripts/ec2-connect.ps1
```

### O que o script pedirá

1.  **Public IP** — digite o IP público ou hostname da instância e pressione **Enter**.
2.  **Confirmação da Chave** — pressione **Enter** para que o script leia a chave que você já copiou para a Área de Transferência.
3.  O script irá converter a chave (`.pem` para `.ppk`) e iniciar o PuTTY automaticamente.
4.  Ao sair do PuTTY, ele perguntará se você quer manter os arquivos de chave no disco. O padrão recomendado é apagar (responda `N` ou tecle Enter).

---

## 6. Dicas de segurança

* **Nunca** compartilhe sua chave privada.
* Prefira apagar a chave (respondendo `N` na etapa de limpeza) após o uso, especialmente em máquinas compartilhadas.
* Considere usar o `Pageant` (agente do PuTTY) para carregar chaves na memória em vez de deixá-las no disco (equivalente ao `ssh-agent` do Linux).
* Considere proteger a chave com passphrase ao gerar, se possível.

