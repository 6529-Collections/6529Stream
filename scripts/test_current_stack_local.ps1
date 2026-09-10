$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$parseErrors=$null;$tokens=$null
$path=Join-Path $PSScriptRoot 'current-stack-local-functions.ps1'
$ast=[System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count -ne 0) {throw ($parseErrors | Out-String)}
# Exercise receipt identity and recovery guards without RPC, accounts or transactions.
$names=@('Invoke-Cast','Convert-UInt','Find-ReceiptEvent','Get-MintedTokenId','Get-EntropyRequest','Require-FreshLocalRun','Assert-ArtifactRuntime','Get-DeploymentAddress')
foreach ($definition in $ast.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst]},$true)) {
    if ($definition.Name -in $names) {Invoke-Expression $definition.Extent.Text}
}
function Check([bool]$Condition,[string]$Label) {if (-not $Condition) {throw $Label}}
function Reject([scriptblock]$Action,[string]$Label) {
    $rejected=$false;try {& $Action | Out-Null} catch {$rejected=$true};Check $rejected $Label
}
foreach ($scriptName in @('run-current-stack.ps1','rehearse-current-stack-vrf.ps1')) {
    $null=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $scriptName),[ref]$tokens,[ref]$parseErrors)
    Check ($parseErrors.Count -eq 0) "$scriptName must parse without errors."
}
$artifact=@{deployedBytecode=@{object='0x60006000'}}
Assert-ArtifactRuntime $artifact '0x60006000'
Reject {Assert-ArtifactRuntime $artifact '0x60016000'} 'Changed executable bytes must fail without immutable ranges.'
Reject {Assert-ArtifactRuntime $artifact '0x6000'} 'Truncated runtime must fail.'
$artifact.deployedBytecode.immutableReferences=@{'12'=@(@{start=1;length=1})}
Assert-ArtifactRuntime $artifact '0x60ff6000'
Reject {Assert-ArtifactRuntime $artifact '0x60ff6001'} 'Only compiler-declared immutable bytes may differ.'
$sale='0x0000000000000000000000000000000000000001'
$other='0x0000000000000000000000000000000000000002'
$deployment=@{transactions=@(@{contractName='CurrentSale';transactionType='CREATE';contractAddress=$sale})}
Check ((Get-DeploymentAddress $deployment 'CurrentSale') -eq $sale) 'Deployment address must use its named CREATE receipt.'
Check ($null -eq (Get-DeploymentAddress $deployment 'LaterModule' -Optional)) 'Retained older deployments may omit a later module.'
Reject {Get-DeploymentAddress $deployment 'LaterModule'} 'Required module cannot be absent.'
$deployment.transactions+=@{contractName='CurrentSale';transactionType='CREATE';contractAddress=$other}
Reject {Get-DeploymentAddress $deployment 'CurrentSale' -Optional} 'Optional module still rejects duplicate deployments.'
$topic=Invoke-Cast @('keccak','NativeSaleSettled(bytes32,bytes32,uint256,bytes32,bytes32,address,uint256)')
$event=@{address=$sale;topics=@($topic,'0x00','0x00','0x2a');data='0x'}
Check ((Get-MintedTokenId @{logs=@($event)} $sale) -eq '42') 'Mint must bind its receipt token.'
Reject {Get-MintedTokenId @{logs=@($event)} $other} 'Another sale cannot supply a token.'
Reject {Get-MintedTokenId @{logs=@($event,$event)} $sale} 'Ambiguous mint receipt must fail.'
$requestTopic=Invoke-Cast @('keccak','EntropyRequested(bytes32,uint256,bytes32,address,uint256)')
$data=Invoke-Cast @('abi-encode','request(address,uint256)',$other,'7')
$receipt=@{logs=@(@{address=$sale;topics=@($requestTopic,'0x01','0x2a','0x03');data=$data})}
Check ((Get-EntropyRequest $receipt $sale '42' $other).providerRequestId -eq '7') 'Request identity must decode receipt data.'
Reject {Get-EntropyRequest $receipt $sale '43' $other} 'Another token request must fail.'
Reject {Get-EntropyRequest $receipt $sale '42' $sale} 'Another provider request must fail.'
Check ((Invoke-Cast @('keccak','artist')) -eq '0xf8c87671fe259c56f53406842c278dbf0d49073ecc39fc38bfc052a1b1a125cb') 'Plain UTF8 must hash without newline.'
Check ((Invoke-Cast @('keccak',('0x'+('00'*40000)))) -eq '0xc625f79680f7083b0bdaef0ba2e4e67b9132ea5edfcecefb31b2b5f3a5a9282e') 'Large hex payload must avoid Windows argv truncation.'
$statePath=Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString()+'.json')
$broadcastPath=$statePath+'.broadcast'
Require-FreshLocalRun $statePath $broadcastPath
try {
    '{}' | Set-Content -LiteralPath $statePath -Encoding utf8
    Reject {Require-FreshLocalRun $statePath $broadcastPath} 'Partial local state must block a new deployment.'
    Remove-Item -LiteralPath $statePath
    '{}' | Set-Content -LiteralPath $broadcastPath -Encoding utf8
    Reject {Require-FreshLocalRun $statePath $broadcastPath} 'Existing broadcast receipts must block a new deployment.'
} finally {
    Remove-Item -LiteralPath $statePath,$broadcastPath -ErrorAction SilentlyContinue
}
Write-Output 'Local runner receipt, hash and recovery checks passed.'
