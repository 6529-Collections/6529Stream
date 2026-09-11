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
    $manifestPath=Join-Path $sandbox 'collector-package/manifest.json'
    $collectionPath=Join-Path $sandbox 'collector-package/collection.json'
    [IO.File]::WriteAllText($manifestPath,'{}')
    $manifestHash=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $collection=@{chainId='31337';core=$addresses.core;collectionId='2';blockNumber='375';blockHash=('0x'+('a'*64))}
    function Write-CollectionFixture {[IO.File]::WriteAllText($collectionPath,($collection|ConvertTo-Json))}
    Write-CollectionFixture
    $script:state=@{collectionId='2'};$BlockNumber=''
    $script:readyCalls=0;$script:frozenCalls=0;$script:allowReady=$true;$script:saveCalls=0;$script:verifyExit=0;$script:verifyCalls=0
    function Require-CompletionReady {$script:readyCalls++;if(-not $script:allowReady){throw 'live readiness required'}}
    function Require-CompletionFrozen {$script:frozenCalls++}
    function Save-ScenarioState {$script:saveCalls++}
    function node([string]$Program,[string]$Package,[string]$ExpectedFlag,[string]$ExpectedHash) {
        $script:invokedVerifier=$Program;$script:invokedExpected=@($ExpectedFlag,$ExpectedHash);$script:verifyCalls++;$global:LASTEXITCODE=$script:verifyExit
    }
    Export-CollectorPackage
    Check ($script:invokedVerifier -eq (Join-Path $PSScriptRoot 'verify_current_stack_collector.mjs')) 'Existing packages use the repository-owned verifier, never a package executable.'
    Check ($script:invokedExpected[0] -eq '--expected-manifest-sha256' -and $script:invokedExpected[1] -ceq $manifestHash) 'Verifier receives the exact expected manifest hash.'
    Check ($script:readyCalls -eq 1 -and $script:frozenCalls -eq 1 -and $script:saveCalls -eq 1) 'Checkpoint-free recovery retains live readiness and freeze checks before adoption.'
    Check ($script:state.collectorPackage.manifestSha256 -ceq $manifestHash -and $script:state.collectorPackage.blockNumber -eq '375') 'Recovered checkpoint binds verified manifest and block.'
    $script:allowReady=$false;$BlockNumber='375'
    Export-CollectorPackage
    Check ($script:readyCalls -eq 1 -and $script:frozenCalls -eq 1) 'A hash-bound historical package remains usable after current mutable state changes.'
    $script:state.collectorPackage.path='D:/prior-location/collector-package'
    Export-CollectorPackage
    Check ($script:state.collectorPackage.path -eq (Join-Path $sandbox 'collector-package') -and $script:state.collectorPackageHistory.Count -eq 1) 'Moving the exact package preserves content identity and prior location.'
    $BlockNumber='374'
    Reject {Export-CollectorPackage} 'requested block'
    $BlockNumber='375'
    foreach ($mutation in @(@{key='chainId';value='11155111'},@{key='core';value='0x0000000000000000000000000000000000009999'},@{key='collectionId';value='999'})) {
        $old=$collection[$mutation.key];$collection[$mutation.key]=$mutation.value;Write-CollectionFixture
        Reject {Export-CollectorPackage} 'another chain, Core or collection'
        $collection[$mutation.key]=$old;Write-CollectionFixture
    }
    $script:state.collectorPackage.manifestSha256='0'*64
    $callsBefore=$script:verifyCalls
    Reject {Export-CollectorPackage} 'checkpoint manifest hash'
    Check ($script:verifyCalls -eq $callsBefore) 'Swapped checkpoint digest is rejected before invoking verifier or saving.'
    $script:state.collectorPackage.manifestSha256=$manifestHash
    $script:verifyExit=1;$savesBefore=$script:saveCalls
    Reject {Export-CollectorPackage} 'verification failed'
    Check ($script:saveCalls -eq $savesBefore) 'Verifier failure cannot update the checkpoint.'
    $script:verifyExit=0;$script:state=@{collectionId='2'}
    Reject {Export-CollectorPackage} 'live readiness required'
    Check (-not $script:state.Contains('collectorPackage')) 'No-checkpoint adoption cannot bypass prior live readiness.'
} finally {
    $resolved=[IO.Path]::GetFullPath($sandbox);$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolved.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase)) {throw 'Temporary test cleanup escaped its parent.'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
Write-Output "PASS: $checks completion checks; no RPC or transactions."
