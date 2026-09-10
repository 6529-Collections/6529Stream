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

function Scenario-Method {return @{inputs=@();outputs=@(@{type='uint256'},@{type='tuple';components=@(@{type='address'},@{type='uint256'})})}}
function Invoke-ScenarioCast {return '["7",["0x0000000000000000000000000000000000000001","9"]]'}
$addresses=@{sample='0x0000000000000000000000000000000000000001'};$RpcUrl='http://127.0.0.1:8547'
$read=Read-Scenario sample example
Require ($read.Count -eq 2 -and $read[0] -eq '7' -and $read[1].Count -eq 2) 'Read returns preserve root fields and nested tuples.'

$sender='0x0000000000000000000000000000000000000001';$target='0x0000000000000000000000000000000000000002'
$expected=@{from=$sender;to=$target;data='0x1234';value='0x0';nonce='0x9'}
$actual=[pscustomobject]@{from=$sender;to=$target;input='0x1234';value='0x0';nonce='0x9';hash='0xabc'}
Assert-ScenarioTransaction $actual $expected
$actual.input='0x5678'
Require-Failure {Assert-ScenarioTransaction $actual $expected} 'input differs'
$actual.input='0x1234';$actual.nonce='0xa'
Require-Failure {Assert-ScenarioTransaction $actual $expected} 'nonce differs'
$actual.nonce='0x9'

$Execute=$true;$zeroAddress='0x'+('0'*40)
function Hash-ScenarioAbi {return 'fixed-operation-identity'}
function Save-ScenarioState {}
$script:rpcMethods=@()
$script:recoveryMode='confirmed'
function Invoke-ScenarioRpc([string]$Method,[object[]]$Parameters=@()) {
    $script:rpcMethods+=$Method
    switch ($Method) {
        'eth_blockNumber' {return '0x5'}
        'eth_getBlockByNumber' {return [pscustomobject]@{transactions=$(if ($script:recoveryMode -eq 'missing') {@()} else {@($actual)})}}
        'eth_getTransactionReceipt' {return [pscustomobject]@{status='0x1';transactionHash='0xabc';logs=@()}}
        'eth_getTransactionByHash' {return $actual}
        default {throw "Unexpected RPC $Method"}
    }
}
$script:state=[ordered]@{operations=[ordered]@{}}
$script:state.operations.done=[ordered]@{identity='fixed-operation-identity';transaction=$expected;startBlock='5';transactionHash='0xabc'}
$receipt=Send-Scenario done $sender $target '0x1234'
Require ($receipt.transactionHash -eq '0xabc' -and 'eth_sendTransaction' -notin $script:rpcMethods) 'Confirmed operations reuse and revalidate the mined transaction without sending again.'

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
Write-Output "PASS: $script:assertions product-scenario assertions; no RPC, signing, process launch or broadcast."
