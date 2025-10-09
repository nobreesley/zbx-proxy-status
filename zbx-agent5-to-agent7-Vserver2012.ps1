# Parar o serviço do Zabbix Agent
Stop-Service -Name "Zabbix Agent" -Force -ErrorAction SilentlyContinue

# Remover o serviço do Zabbix Agent
sc.exe delete "Zabbix Agent"

# Definir variáveis customizadas
$ZabbixVersion = "7.0.9"
$ZabbixAgentDir = "C:\Zabbix"
$ZabbixConfig = "$ZabbixAgentDir\conf\zabbix_agentd.conf"
$ZabbixAgentZip = "zabbix_agent-$ZabbixVersion-windows-amd64.zip"
$ZabbixDownloadURL = "https://cdn.zabbix.com/zabbix/binaries/stable/7.0/$ZabbixVersion/$ZabbixAgentZip"

# Verifica se o arquivo de configura  o existe
if (Test-Path $ZabbixConfig) {
    # L  o conte do do arquivo
    $configContent = Get-Content $ZabbixConfig

# Procura pelas linhas contendo Hostname, Server e ServerActive
    $hostnameLine = $configContent | Select-String -Pattern "^Hostname="
    }
    $currentHostname = $hostnameLine -replace "Hostname=", ""

# Variáveis adicionais
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ZabbixServerIpCloud = "" # Coloque o ip ou dominio do ZABBIX-SERVER OU ZABBIX-PROXY. variavel pode ser utilizado para o parametro SERVER= ou SERVER ACTIVE=
#$ZabbixServerIpLocal = ""
#$ZabbixServerDominioCloud = ""
#$ZabbixServerDominioLocal = "dataunique.ddns.com.br"
#$PORT1 = "10052"
#$PORT2 = "10054"
$ZabbixTIMEOUT = "30"

function Extract-ZipFile {
    param (
        [string]$ZipFile,
        [string]$Destination
    )
    
    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination | Out-Null
    }

    $shell = New-Object -ComObject Shell.Application
    $zip = $shell.NameSpace($ZipFile)
    $target = $shell.NameSpace($Destination)
    $target.CopyHere($zip.Items(), 0x10) # O parâmetro 0x10 suprime as janelas de progresso
}

# Função para baixar o Zabbix Agent
function Download-ZabbixAgent {
    if (-Not (Test-Path -Path $ZabbixAgentDir)) {
        New-Item -Path $ZabbixAgentDir -ItemType Directory
    }

    Write-Host "Baixando o Zabbix Agent $ZabbixVersion..."
    Invoke-WebRequest -Uri $ZabbixDownloadURL -OutFile "$env:TEMP\$ZabbixAgentZip"
    Write-Host "Descompactando o Zabbix Agent..."
    #Expand-Archive -Path "$env:TEMP\$ZabbixAgentZip" -DestinationPath $ZabbixAgentDir -Force
    Extract-ZipFile -ZipFile "$env:TEMP\$ZabbixAgentZip" -Destination $ZabbixAgentDir
}

# Função para configurar o Zabbix Agent
function Configure-ZabbixAgent {
    # Atualizar a configuração
    (Get-Content $ZabbixConfig) -replace "Hostname=.*", "Hostname=$currentHostname" |
    Set-Content $ZabbixConfig

    # Ajustar o IP do servidor Zabbix
    (Get-Content $ZabbixConfig) -replace 'Server=127.0.0.1', "Server=${ZabbixServerIpCloud}" |
    Set-Content $ZabbixConfig

    # Ajustar o IP do servidor Zabbix
    (Get-Content $ZabbixConfig) -replace 'ServerActive=127.0.0.1', "ServerActive=${ZabbixServerIpCloud}" |
    Set-Content $ZabbixConfig

    # Ajustar o Timeout
    (Get-Content $ZabbixConfig) -replace '#\s*Timeout=3', "Timeout=$ZabbixTIMEOUT" |
    Set-Content $ZabbixConfig

    # Remover o # de AllowKey e LogRemoteCommands
    (Get-Content $ZabbixConfig) | 
        ForEach-Object { 
            $_ -replace '#\s+1\s-\sAllowKey', 'AllowKey' `
               -replace '#\s+LogRemoteCommands=0', 'LogRemoteCommands=1'
        } | Set-Content $ZabbixConfig
}

# Função para instalar o Zabbix Agent como serviço
function Install-ZabbixAgentService {
    Write-Host "Instalando o Zabbix Agent como serviço..."
    Start-Process -FilePath "$ZabbixAgentDir\bin\zabbix_agentd.exe" -ArgumentList "-c $ZabbixConfig -i" -Wait
    Write-Host "Serviço Zabbix Agent instalado."
}

# Função para iniciar o serviço
function Start-ZabbixAgentService {
    Write-Host "Iniciando o serviço Zabbix Agent..."
    Start-Service -Name "Zabbix Agent"
    Set-Service -Name "Zabbix Agent" -StartupType Automatic
    Write-Host "Serviço Zabbix Agent iniciado e configurado para iniciar automaticamente."
}

# Liberar Port de Inbound 10050 (entrada)
New-NetFirewallRule -DisplayName "Allow Inbound 10050" -Direction Inbound -LocalPort 10050 -Protocol TCP -Action Allow -Profile Any

# Execução do script
Download-ZabbixAgent
Configure-ZabbixAgent
Install-ZabbixAgentService
Start-ZabbixAgentService

Write-Host "Instalação do Zabbix Agent versão $ZabbixVersion concluída com sucesso."