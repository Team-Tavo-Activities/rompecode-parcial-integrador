param(
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$Vmss,
    [string]$NetworkSecurityGroup = 'nsg-app',
    [string]$LoadBalancer = 'lb-app',
    [string]$Probe = 'probe-health',
    [string]$AzureCli = 'az',
    [datetimeoffset]$Inicio = ([datetimeoffset]::UtcNow.AddHours(-2)),
    [datetimeoffset]$Fin = ([datetimeoffset]::UtcNow),
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_-]+$')][string]$Etiqueta
)

$ErrorActionPreference = 'Stop'
if ($Inicio -ge $Fin) {
    throw 'La hora de inicio debe ser anterior a la hora de fin.'
}
$inicioUtc = $Inicio.UtcDateTime.ToString('o')
$finUtc = $Fin.UtcDateTime.ToString('o')
$folder = Join-Path 'evidencias/jesus' $Etiqueta
if (Test-Path -LiteralPath $folder) {
    throw "Ya existe $folder. Use otra etiqueta para conservar las evidencias."
}
New-Item -ItemType Directory -Path $folder -Force | Out-Null

function Save-AzureJson {
    param([string]$FileName, [string[]]$Arguments)
    $result = & $AzureCli @Arguments --only-show-errors --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI falló al recopilar $FileName. Revise el error anterior."
    }
    Set-Content -LiteralPath (Join-Path $folder $FileName) -Value $result -Encoding utf8
}

(Get-Date).ToUniversalTime().ToString('o') |
    Set-Content -LiteralPath (Join-Path $folder 'captura-utc.txt') -Encoding utf8

Save-AzureJson 'nsg.json' @('network','nsg','rule','list','-g',$ResourceGroup,'--nsg-name',$NetworkSecurityGroup)
Save-AzureJson 'nics.json' @('vmss','nic','list','-g',$ResourceGroup,'--vmss-name',$Vmss)
Save-AzureJson 'ips-del-rg.json' @('network','public-ip','list','-g',$ResourceGroup)
Save-AzureJson 'zonas.json' @('vmss','list-instances','-g',$ResourceGroup,'-n',$Vmss,
    '--query','[].{id:instanceId,name:name,zones:zones,provisioningState:provisioningState}')
Save-AzureJson 'sonda.json' @('network','lb','probe','show','-g',$ResourceGroup,
    '--lb-name',$LoadBalancer,'-n',$Probe)
Save-AzureJson 'balanceador.json' @('network','lb','show','-g',$ResourceGroup,'-n',$LoadBalancer)
$lb = Get-Content -Raw -LiteralPath (Join-Path $folder 'balanceador.json') | ConvertFrom-Json
if (-not $lb.id) {
    throw 'El balanceador consultado no devolvió un identificador de recurso.'
}
Save-AzureJson 'health-probe-status.json' @('monitor','metrics','list','--resource',$lb.id,
    '--metric','DipAvailability','--aggregation','Average','--interval','PT1M',
    '--start-time',$inicioUtc,'--end-time',$finUtc)
Save-AzureJson 'reparacion.json' @('vmss','show','-g',$ResourceGroup,'-n',$Vmss,
    '--query','automaticRepairsPolicy')
Save-AzureJson 'reparacion-estado.json' @('vmss','get-instance-view','-g',$ResourceGroup,'-n',$Vmss)
Save-AzureJson 'actividad.json' @('monitor','activity-log','list','--resource-group',$ResourceGroup,
    '--start-time',$inicioUtc,'--end-time',$finUtc)

Write-Output "Evidencias guardadas en $folder"
