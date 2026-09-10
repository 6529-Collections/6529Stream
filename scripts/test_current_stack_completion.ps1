#requires -Version 7.0
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
foreach ($name in @('run-current-stack-scenarios.ps1','complete-current-stack-collection.ps1')) {
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $name),[ref]$tokens,[ref]$errors)
    if ($errors.Count) {throw ($errors.Message -join '; ')}
    foreach ($function in $ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$false)) {. ([scriptblock]::Create($function.Extent.Text))}
}
$checks=0
function Check([bool]$Pass,[string]$Message) {if(-not $Pass){throw $Message};$script:checks++}
function Reject([scriptblock]$Action,[string]$Message) {$failed=$false;try{& $Action|Out-Null}catch{$failed=$_.Exception.Message -like "*$Message*"};Check $failed "Expected $Message"}
$script:state=@{collectionId='2'};$addresses=@{core='0x0000000000000000000000000000000000000001'}
$script:status='0';$script:royaltyFrozen=$false
function Read-Scenario([string]$Module,[string]$Name,[string[]]$Values=@()) {
    switch ($Name) {
        collectionSupplyMode {return ,@('0')}
        collectionStatus {return ,@($script:status)}
        collectionMaxSupply {return ,@('10')}
        collectionHasMaxSupply {return ,@($true)}
        collectionBurnsBlocked {return ,@($script:status -eq '2')}
        collectionFreezeStatus {return ,@($script:status -eq '2')}
        collectionRoyalty {$record=@('wallet','690',$true,$script:royaltyFrozen);return ,(,$record)}
        default {throw "Unexpected read $Name"}
    }
}
function Hash-ScenarioAbi([string]$Types,[string[]]$Values) {return $Values -join '|'}
function New-ScenarioCall([string]$Module,[string]$Name,[string[]]$Values,[string]$Scope='',[string]$Old='',[string]$New='') {return @{module=$Module;name=$Name;values=$Values;scope=$Scope;old=$Old;new=$New}}
$calls=New-CompletionFreezeCalls
Check (($calls.name -join ',') -eq 'setCollectionStatus,blockCollectionBurns,freezeCollection,freezeCollectionRoyalty') 'Closure/burn-block/Core-freeze ordering precedes royalty freeze.'
Check ($calls[0].old.EndsWith('|true|0|0|true|10') -and $calls[0].new.EndsWith('|true|0|2|true|10')) 'Terminal closure retains fixed cap and changes only status.'
Check ($calls[1].old.EndsWith('|false') -and $calls[1].new.EndsWith('|true') -and $calls[2].scope -eq $calls[0].scope) 'One-way flags bind the same collection scope.'
Reject {Require-CompletionFrozen} 'closure, burn block and freeze'
$script:status='2'
Reject {New-CompletionFreezeCalls} 'active, unfrozen'
Reject {Require-CompletionFrozen} 'royalty is not frozen'
$script:royaltyFrozen=$true;Require-CompletionFrozen;Check $true 'Frozen readiness accepts all completed flags.'
$script:revertData='0xexact';$RpcUrl='http://127.0.0.1:8547';$addresses.metadata=$addresses.core
function Scenario-CallData {return '0xcall'}
function Invoke-ScenarioCast {return '0xexact'}
function Invoke-RestMethod {return [pscustomobject]@{error=[pscustomobject]@{data=$script:revertData}}}
$probe=Assert-ProhibitedCompletionCall edit $addresses.core metadata setCollectionScript @('2','changed') 'CollectionFrozen(uint256)'
Check ($probe.request.method -eq 'eth_call' -and $probe.expectedRevertData -eq '0xexact') 'Prohibited edit probe is read-only and requires the exact custom error.'
$script:revertData='0xunauthorized'
Reject {Assert-ProhibitedCompletionCall edit $addresses.core metadata setCollectionScript @('2','changed') 'CollectionFrozen(uint256)'} 'Expected exact post-freeze error'
$runner=Join-Path $PSScriptRoot 'complete-current-stack-collection.ps1'
Reject {& $runner -DeploymentState unused -ScenarioState unused -OutputDirectory unused -RpcUrl https://ethereum-sepolia-rpc.publicnode.com} 'local unlocked Anvil'
$sandbox=Join-Path ([IO.Path]::GetTempPath()) ('stream-completion-'+[guid]::NewGuid().ToString('N'))
$OutputDirectory=$sandbox;$CollectorDirectory='';$completionScriptRoot=$PSScriptRoot
try {
    $null=New-Item -ItemType Directory -Path (Join-Path $sandbox 'collector-package')
    [IO.File]::WriteAllText((Join-Path $sandbox 'collector-package/manifest.json'),'{}')
    function Require-CompletionReady {}
    function Require-CompletionFrozen {}
    function node([string]$Program,[string]$Package) {$script:invokedVerifier=$Program;$global:LASTEXITCODE=0}
    Export-CollectorPackage
    Check ($script:invokedVerifier -eq (Join-Path $PSScriptRoot 'verify_current_stack_collector.mjs')) 'Existing packages use the repository-owned verifier, never a package executable.'
} finally {
    $resolved=[IO.Path]::GetFullPath($sandbox);$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolved.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase)) {throw 'Temporary test cleanup escaped its parent.'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
Write-Output "PASS: $checks completion checks; no RPC or transactions."
