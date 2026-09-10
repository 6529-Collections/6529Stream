#requires -Version 7.0
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$runner=Join-Path $PSScriptRoot 'run-current-stack-scenarios.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($runner,[ref]$tokens,[ref]$errors)
if ($errors.Count) {throw ($errors.Message -join '; ')}
foreach ($function in $ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$false)) {
    . ([scriptblock]::Create($function.Extent.Text))
}
$script:assertions=0
function Require([bool]$Condition,[string]$Message) {
    if (-not $Condition) {throw $Message}
    $script:assertions++
}
function Require-Failure([scriptblock]$Action,[string]$Message) {
    $failed=$false
    try {& $Action | Out-Null} catch {$failed=$_.Exception.Message -like "*$Message*"}
    Require $failed "Expected failure: $Message"
}

Require ((Scenario-UInt '0xff') -eq 255) 'Hex quantities remain unsigned.'
Require ((Scenario-Hex ([bigint]16777216)) -eq '0x1000000') 'Gas cap quantity encoding.'
$parameter=@{type='tuple[]';components=@(@{type='uint256'},@{type='tuple[]';components=@(@{type='address'},@{type='bytes32'})})}
Require ((Scenario-CanonicalType $parameter) -eq '(uint256,(address,bytes32)[])[]') 'Nested ABI tuple arrays.'

# A --skip test deployment has no mock artifact. Preparation must supply both
# creation bytecode and the shared ABI cache used by mint/approve/balance reads.
$fixtureParent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixture=Join-Path $fixtureParent ('stream-scenario-token-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path (Join-Path $fixture 'production')
try {
    $deployment=@{artifactDirectory=(Join-Path $fixture 'production')}
    $contracts=@{paymentToken='MockStreamPaymentToken'};$artifactCache=@{}
    Require-Failure {Get-ScenarioArtifact paymentToken} 'does not exist'
    $tokenArtifact=@{bytecode=@{object='0x6000'};deployedBytecode=@{object='0x6001'};abi=@(
        @{type='function';name='mint';inputs=@(@{type='address'},@{type='uint256'});outputs=@()},
        @{type='function';name='approve';inputs=@(@{type='address'},@{type='uint256'});outputs=@(@{type='bool'})},
        @{type='function';name='balanceOf';inputs=@(@{type='address'});outputs=@(@{type='uint256'})}
    )}
    $tokenPath=Join-Path $fixture 'isolated-token.json'
    [IO.File]::WriteAllText($tokenPath,($tokenArtifact|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
    $script:preparedToken=@{artifact_path=$tokenPath;artifact_sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $tokenPath).Hash.ToLowerInvariant()}
    function Invoke-ScenarioTestTokenPreparation {return $script:preparedToken}
    $null=Initialize-ScenarioPaymentToken
    Require ((Get-ScenarioArtifact paymentToken).bytecode.object -eq '0x6000') 'Isolated artifact supplies token creation bytecode.'
    foreach ($method in @('mint','approve','balanceOf')) {Require ((Scenario-Method paymentToken $method).name -eq $method) "Isolated artifact supplies $method ABI."}
    Require (@(Get-ChildItem -LiteralPath $deployment.artifactDirectory).Count -eq 0) 'Production output remains empty and untouched.'
    $script:preparedToken.artifact_sha256='0'*64
    Require-Failure {Initialize-ScenarioPaymentToken} 'artifact hash differs'
} finally {
    $resolvedFixture=[IO.Path]::GetFullPath($fixture)
    if ([IO.Path]::GetDirectoryName($resolvedFixture) -ne $fixtureParent.TrimEnd([IO.Path]::DirectorySeparatorChar)) {throw 'Temporary fixture escaped its parent.'}
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}

function Scenario-Method {return @{inputs=@();outputs=@(@{type='uint256'},@{type='tuple';components=@(@{type='address'},@{type='uint256'})})}}
function Invoke-ScenarioCast {return '["7",["0x0000000000000000000000000000000000000001","9"]]'}
$addresses=@{sample='0x0000000000000000000000000000000000000001'};$RpcUrl='http://127.0.0.1:8547'
$read=Read-Scenario sample example
Require ($read.Count -eq 2 -and $read[0] -eq '7' -and $read[1].Count -eq 2) 'Read returns preserve root fields and nested tuples.'

$sender='0x0000000000000000000000000000000000000001';$target='0x0000000000000000000000000000000000000002'
$expected=@{from=$sender;to=$target;data='0x1234';value='0x0';nonce='0x9';gas='0x10000';chainId='0x7a69'}
$actual=[pscustomobject]@{from=$sender;to=$target;input='0x1234';value='0x0';nonce='0x9';hash='0xabc';blockHash='0xblock';blockNumber='0x5';transactionIndex='0x0';gas='0x10000';chainId='0x7a69'}
Assert-ScenarioTransaction $actual $expected
$actual.input='0x5678'
Require-Failure {Assert-ScenarioTransaction $actual $expected} 'input differs'
$actual.input='0x1234';$actual.nonce='0xa'
Require-Failure {Assert-ScenarioTransaction $actual $expected} 'nonce differs'
$actual.nonce='0x9'
$actual.gas='0x10001'
Require-Failure {Assert-ScenarioTransaction $actual $expected} 'gas differs'
$actual.gas='0x10000';$actual.chainId='0x1'
Require-Failure {Assert-ScenarioTransaction $actual $expected} 'chainId differs'
$actual.chainId='0x7a69'

$Execute=$true;$zeroAddress='0x'+('0'*40)
function Hash-ScenarioAbi {return 'fixed-operation-identity'}
function Save-ScenarioState {}
$script:rpcMethods=@()
$script:recoveryMode='confirmed'
function Invoke-ScenarioRpc([string]$Method,[object[]]$Parameters=@()) {
    $script:rpcMethods+=$Method
    switch ($Method) {
        'eth_blockNumber' {return '0x5'}
        'eth_getBlockByNumber' {return [pscustomobject]@{hash='0xblock';number='0x5';transactions=$(if ($script:recoveryMode -eq 'missing') {@()} elseif ($Parameters[1]) {@($actual)} else {@('0xabc')})}}
        'eth_getTransactionReceipt' {return [pscustomobject]@{status='0x1';transactionHash='0xabc';blockNumber='0x5';blockHash='0xblock';from=$sender;to=$target;transactionIndex='0x0';logs=@()}}
        'eth_getTransactionByHash' {return $actual}
        default {throw "Unexpected RPC $Method"}
    }
}
$script:state=[ordered]@{operations=[ordered]@{}}
$script:state.operations.done=[ordered]@{identity='fixed-operation-identity';transaction=$expected;startBlock='5';transactionHash='0xabc'}
$receipt=Send-Scenario done $sender $target '0x1234'
Require ($receipt.transactionHash -eq '0xabc' -and 'eth_sendTransaction' -notin $script:rpcMethods) 'Confirmed operations reuse and revalidate the mined transaction without sending again.'

$actual.blockHash='0xorphaned'
Require-Failure {Send-Scenario done $sender $target '0x1234'} 'canonical block'
$actual.blockHash='0xblock'
Require ($script:state.operations.done.Contains('rpcTransaction') -and $script:state.operations.done.Contains('blockHeader')) 'Confirmed journal preserves transaction and canonical header evidence.'

$canonical=[pscustomobject]@{hash='0xblock';number='0x5';transactions=@('0xabc')}
Assert-ScenarioReceipt $receipt $actual $canonical '0xabc'
Require-Failure {Assert-ScenarioReceipt $receipt $actual $canonical '0xwrong'} 'recorded operation'
$canonical.number='0x6'
Require-Failure {Assert-ScenarioReceipt $receipt $actual $canonical '0xabc'} 'canonical block'
$canonical.number='0x5';$canonical.transactions=@('0xwrong')
Require-Failure {Assert-ScenarioReceipt $receipt $actual $canonical '0xabc'} 'membership'
$canonical.transactions=@('0xabc');$receipt.from=$target
Require-Failure {Assert-ScenarioReceipt $receipt $actual $canonical '0xabc'} 'sender or target'
$receipt.from=$sender;$receipt.transactionIndex='0x1'
Require-Failure {Assert-ScenarioReceipt $receipt $actual $canonical '0xabc'} 'index'
$receipt.transactionIndex='-1';$actual.transactionIndex='-1'
Require-Failure {Assert-ScenarioReceipt $receipt $actual $canonical '0xabc'} 'index'
$receipt.transactionIndex='0x0';$actual.transactionIndex='0x0'

$script:rpcMethods=@();$script:recoveryMode='recover'
$script:state.operations.recover=[ordered]@{identity='fixed-operation-identity';transaction=$expected;startBlock='5'}
$receipt=Send-Scenario recover $sender $target '0x1234'
Require ($script:state.operations.recover.transactionHash -eq '0xabc' -and 'eth_sendTransaction' -notin $script:rpcMethods) 'Interrupted send recovers by sender, nonce and exact payload without spending another nonce.'

$script:rpcMethods=@();$script:recoveryMode='missing'
$script:state.operations.unknown=[ordered]@{identity='fixed-operation-identity';transaction=$expected;startBlock='5'}
Require-Failure {Send-Scenario unknown $sender $target '0x1234'} 'Unresolved send'
Require ('eth_sendTransaction' -notin $script:rpcMethods) 'Unknown send state fails closed.'
$script:state.operations.changed=[ordered]@{identity='different-operation';transaction=$expected;startBlock='5';transactionHash='0xabc'}
Require-Failure {Send-Scenario changed $sender $target '0x1234'} 'changed'

Require-Failure {& $runner -DeploymentState 'unused' -OutputDirectory 'unused' -RpcUrl 'https://ethereum-sepolia-rpc.publicnode.com' -Stage Status} 'local unlocked Anvil'
$addresses=[ordered]@{}
foreach ($name in @('core','manager','nativeSale','erc20Sale','auction','artistRegistry','entropy','splitFactory','primaryRevenue','assetPolicy','executor','governanceRoot','roleRegistry','provider')) {$addresses[$name]=$sender}
$config=New-ScenarioClientConfig
Require ($config.addresses.Count -eq 11 -and -not $config.addresses.Contains('governanceRoot')) 'Client configuration exports only supported aliases.'
$tempPath=Join-Path ([IO.Path]::GetTempPath()) ('stream-scenario-config-'+[guid]::NewGuid().ToString('N')+'.json')
try {
    [IO.File]::WriteAllText($tempPath,($config|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
    $clientPath=([Uri](Join-Path (Split-Path -Parent $PSScriptRoot) 'packages/stream-client/dist/index.js')).AbsoluteUri
    $probe='import {readFileSync} from "node:fs"; const {stackConfigFromJSON}=await import(process.argv[1]); const config=stackConfigFromJSON(JSON.parse(readFileSync(process.argv[2],"utf8"))); if(Object.keys(config.addresses).length!==11)throw Error("Unexpected aliases");'
    & node --input-type=module -e $probe $clientPath $tempPath
    Require ($LASTEXITCODE -eq 0) 'Generated configuration passes the real client parser.'
} finally {Remove-Item -LiteralPath $tempPath -ErrorAction SilentlyContinue}
function Read-Scenario([string]$Module,[string]$Name,[string[]]$Values=@()) {
    if ($Name -eq 'minimumDelay') {return ,@($(if($Values[0] -eq '2'){259200}else{172800}))}
    return ,@('0xmanifest')
}
function Invoke-ScenarioRpc([string]$Method,[object[]]$Parameters=@()) {
    if ($Method -eq 'eth_getBlockByNumber') {return @{timestamp=$(if($Parameters[0] -eq 'pending'){'1000'}else{'260500'})}}
    throw "Unexpected governance RPC $Method"
}
function Scenario-CallData([string]$Module,[string]$Name,[string[]]$Values=@()) {$script:scheduleClass=$Values[0];return '0x1234'}
function Send-ScenarioMethod {return @{logs=@()}}
function Find-ScenarioEvent {return @{topics=@('0xtopic','0xaction')}}
$zero='0x'+('0'*64);$callTuple='(address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32)'
$addresses.executor=$target;$controller=$sender;$AdvanceLocalTime=$false
$script:state=[ordered]@{operations=[ordered]@{};governance=[ordered]@{}}
Invoke-ScenarioGovernance terminal @(@{tuple='()';data='0x';scope=$zero;old=$zero;new=$zero}) 2
Require ($script:state.governance.terminal.notBefore -eq '260500' -and $script:scheduleClass -eq '2') 'Terminal proposals use actual 72-hour delay and class2.'
Require (([bigint]$script:state.governance.terminal.expiresAfter-[bigint]$script:state.governance.terminal.notBefore) -eq 604800) 'Delayed proposals retain a full seven-day execution window.'
Require-Failure {Invoke-ScenarioGovernance terminal @() 1} 'action class changed'

Write-Output "PASS: $script:assertions product-scenario assertions; no RPC, signing, daemon or broadcast."
