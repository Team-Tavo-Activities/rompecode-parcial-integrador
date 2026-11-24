param(
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$Vmss,
    [string]$NetworkSecurityGroup = 'nsg-app',
    [string]$LoadBalancer = 'lb-app',
    [string]$Probe = 'probe-health',
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_-]+$')][string]$Etiqueta
)

$ErrorActionPreference = 'Stop'
$folder = Join-Path 'evidencias/jesus' $Etiqueta
if (Test-Path -LiteralPath $folder) {
    throw "Ya existe $folder. Use otra etiqueta para conservar las evidencias."
}
New-Item -ItemType Directory -Path $folder -Force | Out-Null

function Save-AzureJson {
    param([string]$FileName, [string[]]$Arguments)
    $result = & az @Arguments --only-show-errors --output json
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
Save-AzureJson 'reparacion.json' @('vmss','show','-g',$ResourceGroup,'-n',$Vmss,
    '--query','automaticRepairsPolicy')
Save-AzureJson 'reparacion-estado.json' @('vmss','get-instance-view','-g',$ResourceGroup,'-n',$Vmss)
Save-AzureJson 'actividad.json' @('monitor','activity-log','list','--resource-group',$ResourceGroup,
    '--offset','2h')

Write-Output "Evidencias guardadas en $folder"
