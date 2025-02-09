# Habilitar mensajes Verbose globalmente
$VerbosePreference = "Continue"
function validar_ip {
    param (
        [string]$ip
    )

    $regex = "^((25[0-4]|2[0-4][0-9]|1?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?))$"
    if ($ip -match $regex) {
        return $true
    } else {
        return $false
    }
}

function validar_dominio {
    param (
        [string]$dominio
    )

    $regex = "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"
    if ($dominio -match $regex) {
        return $true
    } else {
        return $false
    }
}


Write-Host "Bienvenido a la configuración de tu servidor DNS"

# Pedir dominio hasta que sea válido
while ($true) {
    $dominio = Read-Host "Introduce el nombre de dominio que deseas configurar"
    if (validar_dominio $dominio) {
        Write-Host "Dominio válido: $dominio"
        break
    } else {
        Write-Host "Dominio inválido. Intena de nuevo"
    }
}
# Pedir IP hasta que sea válida
while ($true) {
    $ip = Read-Host "Introduce la dirección IP de tu servidor DNS"
    if (validar_ip $ip) {
        Write-Host "IP válida: $ip"
        break
    } else {
        Write-Host "IP inválida. Intenta de nuevo"
    }
}

$partes = $ip -split "\."
Write-Verbose "Dirección IP separada por partes"
#Fijar IP
Write-Verbose "Fijando IP..."
New-NetIPAddress -IPAddress $ip -InterfaceAlias "Ethernet 2" -PrefixLength 24

#Instalar servidor DNS
Write-Verbose "Instalando servidor DNS..."
Install-WindowsFeature -Name DNS -IncludeManagementTools

#Configurar zona principal
Write-Verbose "Configurando zona principal..."
Add-DnsServerPrimaryZone -Name $dominio -ZoneFile "$dominio.dns" -DynamicUpdate None -PassThru 

#Configurar zona inversa
Write-Verbose "Configurando zona inversa..."
Add-DnsServerPrimaryZone -NetworkID $partes[0].$partes[1].$partes[2]."0/24" -ZoneFile "$partes[2].$partes[1].$partes[0].in-addr.arpa.dns" -DynamicUpdate None -PassThru

#Crear registro A para dominio principal
Write-Verbose "Creando registro A para dominio principal: $dominio"
Add-DnsServerResourceRecordA -Name "@" -ZoneName $dominio -IPv4Address $ip -CreatePtr -PassThru

#Crear registro para www
Write-Verbose "Creando registro A para www.$dominio"
Add-DnsServerResourceRecordA -Name "www" -ZoneName $dominio -IPv4Address $ip -CreatePtr -PassThru

#Configurar máquina como servidor DNS
Write-Verbose "Configurando máquina como servidor DNS..."
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses $ip
Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" -ServerAddresses $ip

#Reiniciar servicio DNS
Write-Verbose "Reiniciando servicio DNS..."
Restart-Service -Name DNS

#Habilitar pruebas ping 
New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4 -Direction Inbound -Action Allow

Write-Host "Configuración finalizada. Puedes probar tu servidor DNS :)"

