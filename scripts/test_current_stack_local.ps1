$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$parseErrors=$null;$tokens=$null
$path=Join-Path $PSScriptRoot 'current-stack-local-functions.ps1'
$ast=[System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count -ne 0) {throw ($parseErrors | Out-String)}
# Exercise receipt identity and recovery guards without RPC, accounts or transactions.
$names=@('Invoke-Cast','Convert-UInt','Find-ReceiptEvent','Get-MintedTokenId','Get-EntropyRequest','Require-FreshLocalRun','Assert-ArtifactRuntime','Get-DeploymentAddress','Assert-ExtendedPublisherPointer','Assert-LocalDeploymentPlan')
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
$unsigned=@{receipts=@();pending=@();transactions=@(
    @{contractName='First';function='configure()';transaction=@{from=$sale;chainId='0x7a69';nonce='0x7';gas='0x5208'}},
    @{contractName='Executor';function='initializeGenesis()';transaction=@{from=$sale;chainId='0x7a69';nonce='0x8';gas='0x1000000'}}
)}
$checked=Assert-LocalDeploymentPlan $unsigned $sale 7 115
Check ($checked.transactionCount -eq 2 -and $checked.maximumGasLimit -eq '16777216') 'An exact-cap complete plan must pass.'
$unsigned.transactions[1].transaction.nonce='0x9'
Reject {Assert-LocalDeploymentPlan $unsigned $sale 7 115} 'A late nonce gap must fail before broadcast.'
$unsigned.transactions[1].transaction.nonce='0x8'
$unsigned.transactions[1].transaction.from=$other
Reject {Assert-LocalDeploymentPlan $unsigned $sale 7 115} 'A late sender substitution must fail before broadcast.'
$unsigned.transactions[1].transaction.from=$sale
$unsigned.transactions[1].transaction.gas='0x1000001'
Reject {Assert-LocalDeploymentPlan $unsigned $sale 7 115} 'A final over-cap transaction must reject the entire plan.'
Reject {Assert-LocalDeploymentPlan @{transactions=@();receipts=@();pending=@()} $sale 7 115} 'An empty plan cannot pass.'
# Execute the actual local runner with mocked Forge/RPC boundaries. Only the final
# plan row exceeds the cap: neither the broadcast call nor its checkpoint may run.
$localProbe=Join-Path ([IO.Path]::GetTempPath()) ('stream-plan-test-'+[guid]::NewGuid().ToString())
$global:currentStackPlanProbe=@{plan=$unsigned;calls=@()}
foreach ($row in $global:currentStackPlanProbe.plan.transactions) {$row.transaction.from='0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'}
try {
    function Invoke-RestMethod([string]$Uri,[string]$Method,[string]$ContentType,[string]$Body) {
        $request=$Body | ConvertFrom-Json
        $value=switch ($request.method) {
            'eth_chainId' {'0x7a69'}
            'eth_accounts' {,@('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266')}
            'eth_getTransactionCount' {'0x7'}
            default {throw "Unexpected RPC in unsigned-plan regression: $($request.method)"}
        }
        return @{result=$value}
    }
    function forge {
        $global:currentStackPlanProbe.calls+=,@($args)
        if ('--broadcast' -in $args) {throw 'Regression reached an unauthorized broadcast boundary.'}
        $destination=Join-Path $env:FOUNDRY_BROADCAST 'DeployCurrentStack.s.sol/31337/dry-run/run-latest.json'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        $global:currentStackPlanProbe.plan | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 -LiteralPath $destination
        $global:LASTEXITCODE=0
    }
    $failure=$null
    try {& (Join-Path $PSScriptRoot 'run-current-stack.ps1') -OutputDirectory $localProbe -DeployOnly} catch {$failure=$_.Exception.Message}
    Check ($failure -like '*transaction 1*initializeGenesis()*16777217*115%*DeploymentGasEstimateMultiplier*') "A late cap error must identify the transaction and adjustable multiplier. Observed: $failure"
    Check ($global:currentStackPlanProbe.calls.Count -eq 1 -and '--broadcast' -notin $global:currentStackPlanProbe.calls[0]) 'The actual runner must stop after its unsigned Forge call.'
    Check (-not (Test-Path -LiteralPath (Join-Path $localProbe 'current-stack.json'))) 'Rejected unsigned plans must not write a deployment-started checkpoint.'
} finally {
    Remove-Item Function:forge,Function:Invoke-RestMethod -ErrorAction SilentlyContinue
    Remove-Variable -Name currentStackPlanProbe -Scope Global
    if (Test-Path -LiteralPath $localProbe) {
        $resolved=(Resolve-Path -LiteralPath $localProbe).Path
        if ($resolved -ne [IO.Path]::GetFullPath($localProbe) -or -not $resolved.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase)) {throw 'Unexpected regression cleanup path.'}
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
$hash='0x'+('11'*32)
$moduleType='0xa79066eedc862e1122885d62af037de32376da824a17eceb77f7332aef89ce4e'
$pointerAbi='address,bytes32,bool,bytes32,bytes4,address,uint8,bytes32,bytes32,uint64'
$pointerData=Invoke-Cast @('abi-encode',"pointer($pointerAbi)",$sale,$hash,'false',$moduleType,'0x77faad4f',$other,'1',$hash,$hash,'1')
$pointer=Invoke-Cast @('abi-decode',"pointer()($pointerAbi)",$pointerData,'--json') | ConvertFrom-Json -NoEnumerate
Check ($pointer.Count -eq 10) 'The deployed Core pointer read has ten ABI fields.'
Assert-ExtendedPublisherPointer $pointer $sale $other
$wrongModule=$pointer.Clone();$wrongModule[3]='0x03f5dfc0687afbbc9c86bda58667bf3bb235a2d1cbe7273bbbe4d5301fb0b6d2'
Reject {Assert-ExtendedPublisherPointer $wrongModule $sale $other} 'The pointer key cannot substitute for the Executor module type.'
$wrongInterface=$pointer.Clone();$wrongInterface[4]='0x01ffc9a7'
Reject {Assert-ExtendedPublisherPointer $wrongInterface $sale $other} 'Serving ERC165 alone is not the canonical publisher interface.'
$inactive=$pointer.Clone();$inactive[6]=2
Reject {Assert-ExtendedPublisherPointer $inactive $sale $other} 'A deprecated publisher is not active.'
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
    Reject {Require-FreshLocalRun $statePath ($broadcastPath+'.missing') $broadcastPath} 'A retained unsigned plan must not be silently overwritten.'
} finally {
    Remove-Item -LiteralPath $statePath,$broadcastPath -ErrorAction SilentlyContinue
}
Write-Output 'Local runner receipt, hash and recovery checks passed.'
