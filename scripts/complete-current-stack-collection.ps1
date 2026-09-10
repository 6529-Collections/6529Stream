#requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$DeploymentState,
    [Parameter(Mandatory)][string]$ScenarioState,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateSet('Status','Complete','Freeze','Package','All')][string]$Stage='Status',
    [string]$RpcUrl='http://127.0.0.1:8547',
    [string]$CollectorDirectory='',
    [ValidatePattern('^[1-9][0-9]*$')][string]$BlockNumber,
    [switch]$Execute,
    [switch]$AdvanceLocalTime
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repoRoot=Split-Path -Parent $PSScriptRoot
$completionScriptRoot=$PSScriptRoot
$zero='0x'+('0'*64);$zeroAddress='0x'+('0'*40)
$callTuple='(address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32)'
$artifactCache=@{}
$shared=Join-Path $completionScriptRoot 'run-current-stack-scenarios.ps1'
$parseTokens=$null;$parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($shared,[ref]$parseTokens,[ref]$parseErrors)
if ($parseErrors.Count) {throw 'Shared scenario functions did not parse.'}
foreach ($function in $ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$false)) {. ([scriptblock]::Create($function.Extent.Text))}

function Require-CompletionReady {
    $id=$script:state.collectionId
    if ((Read-Scenario core collectionMintedEver @($id))[0] -ne '3' -or (Read-Scenario core totalSupplyOfCollection @($id))[0] -ne '3') {throw 'Completion requires exactly the three settled scenario artworks.'}
    foreach ($name in @('native','erc20','auction')) {
        $token=[string]$source[$name].tokenId;$identity=Read-Scenario core tokenCollectionIdentity @($token)
        if (-not $identity[0] -or [string]$identity[1] -ne $id -or $identity[3]) {throw 'Scenario token identity changed or was burned.'}
        $seed=Read-Scenario entropy tokenSeed @($token)
        if (-not $seed[1] -or $seed[0] -ne $source[$name].seed -or (Read-Scenario entropy metadataNotificationPending @($token))[0]) {throw 'All selected artworks must have final entropy and completed notifications.'}
        $owner=if($name -eq 'auction'){$source.secondBidder}else{$source.buyer}
        if ((Read-Scenario core ownerOf @($token))[0] -ine $owner) {throw 'Finish collection custody before freezing.'}
    }
    $auction=(Read-Scenario auction auction @([string]$source.auction.tokenId))[0]
    if (-not $auction[11] -or $auction[12]) {throw 'Auction must already be settled.'}
    if ((Read-Scenario core collectionFreezeStatus @('1'))[0]) {throw 'This workflow does not freeze the original collection.'}
}
function Invoke-ArtworkCompletion {
    Require-CompletionReady
    $id=$script:state.collectionId
    if (-not $script:state.governance.Contains('artwork.render')) {
        if ((Read-Scenario core collectionFreezeStatus @($id))[0]) {throw 'Artwork must be completed before collection freeze.'}
        $calls=@(New-ScenarioCall metadata setCollectionMetadata @($id,'Stream Field Studies','Three deterministic geometric studies. Each renders entirely from retained token identity and finalized seed.','',''))
        $calls+=New-ScenarioCall metadata setCollectionScript @($id,$artwork)
        Invoke-ScenarioGovernance 'artwork.render' $calls 1
    } else {Invoke-ScenarioGovernance 'artwork.render' @() 1}
    $record=(Read-Scenario metadata collectionMetadata @($id))[0]
    if ($record[4] -cne $artwork) {throw 'Artwork completion readback differs.'}
    $script:state.completed=$true;Save-ScenarioState
}
function New-CompletionFreezeCalls {
    $id=$script:state.collectionId
    $scope=Hash-ScenarioAbi 'bytes32,uint256,address,uint256' @('0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16','31337',$addresses.core,$id)
    $domain='0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5'
    $mode=[string](Read-Scenario core collectionSupplyMode @($id))[0]
    $status=[string](Read-Scenario core collectionStatus @($id))[0]
    $cap=[string](Read-Scenario core collectionMaxSupply @($id))[0]
    $hasCap=([string](Read-Scenario core collectionHasMaxSupply @($id))[0]).ToLowerInvariant()
    if ($status -ne '0' -or (Read-Scenario core collectionBurnsBlocked @($id))[0] -or (Read-Scenario core collectionFreezeStatus @($id))[0]) {throw 'Expected an active, unfrozen collection before scheduling terminal completion.'}
    $old=Hash-ScenarioAbi 'bytes32,bytes32,bool,uint8,uint8,bool,uint256' @($domain,$scope,'true',$mode,$status,$hasCap,$cap)
    $new=Hash-ScenarioAbi 'bytes32,bytes32,bool,uint8,uint8,bool,uint256' @($domain,$scope,'true',$mode,'2',$hasCap,$cap)
    $calls=@(New-ScenarioCall core setCollectionStatus @($id,'2') $scope $old $new)
    foreach ($entry in @(@('blockCollectionBurns','0x0a834b49bdbe94b7d08a85a25431e3405b397e5f84bf90a90107edb2a58013ec'),@('freezeCollection','0xa54d2564d797e7eec4b1cd68d067d7c297bfae640f401ff3b8fde47441079692'))) {
        $old=Hash-ScenarioAbi 'bytes32,bytes32,bool' @($entry[1],$scope,'false')
        $new=Hash-ScenarioAbi 'bytes32,bytes32,bool' @($entry[1],$scope,'true')
        $calls+=New-ScenarioCall core $entry[0] @($id) $scope $old $new
    }
    $calls+=New-ScenarioCall royalty freezeCollectionRoyalty @($id)
    return ,$calls
}
function Require-CompletionFrozen {
    $id=$script:state.collectionId
    if ((Read-Scenario core collectionStatus @($id))[0] -ne '2' -or -not (Read-Scenario core collectionBurnsBlocked @($id))[0] -or -not (Read-Scenario core collectionFreezeStatus @($id))[0]) {throw 'Collection closure, burn block and freeze must all be complete.'}
    if (-not (Read-Scenario royalty collectionRoyalty @($id))[0][3]) {throw 'Collection royalty is not frozen.'}
}
function Assert-ProhibitedCompletionCall([string]$Label,[string]$Sender,[string]$Module,[string]$Method,[string[]]$Values,[string]$ErrorSignature) {
    $data=Scenario-CallData $Module $Method $Values
    $transaction=@{from=$Sender;to=$addresses[$Module];data=$data;gas='0xf42400'}
    $request=@{jsonrpc='2.0';id=1;method='eth_call';params=@($transaction,'latest')}
    $response=Invoke-RestMethod -Uri $RpcUrl -Method Post -ContentType 'application/json' -Body ($request|ConvertTo-Json -Depth 10 -Compress)
    $expected=Invoke-ScenarioCast @('calldata',$ErrorSignature,$script:state.collectionId)
    if ('error' -notin $response.PSObject.Properties.Name -or $response.error.data -ine $expected) {throw "Expected exact post-freeze error $ErrorSignature for $Label."}
    return @{label=$Label;request=$request;response=$response;expectedRevertData=$expected;semantics='Read-only eth_call from the normal authorized actor; no transaction or state change.'}
}
function Invoke-CollectionFreeze {
    if (-not $script:state.Contains('completed') -or -not $script:state.completed) {throw 'Complete the artwork and royalty configuration first.'}
    Require-CompletionReady
    if (-not $script:state.governance.Contains('collection.freeze')) {Invoke-ScenarioGovernance 'collection.freeze' (New-CompletionFreezeCalls) 2} else {Invoke-ScenarioGovernance 'collection.freeze' @() 2}
    Require-CompletionFrozen
    $before=(Read-Scenario metadata collectionMetadata @($script:state.collectionId))[0]|ConvertTo-Json -Compress
    $checks=@(Assert-ProhibitedCompletionCall 'metadata edit' $addresses.executor metadata setCollectionMetadata @($script:state.collectionId,'Changed','Changed','','') 'CollectionFrozen(uint256)')
    $checks+=Assert-ProhibitedCompletionCall 'script edit' $addresses.executor metadata setCollectionScript @($script:state.collectionId,'document.body.textContent="changed";') 'CollectionFrozen(uint256)'
    $checks+=Assert-ProhibitedCompletionCall 'royalty edit' $addresses.executor royalty configureCollectionRoyalty @($script:state.collectionId,$source.profileId,'500') 'RoyaltyConfigurationFrozen(uint256)'
    $checks+=Assert-ProhibitedCompletionCall 'collector burn' $source.buyer core burn @([string]$source.native.tokenId) 'CollectionBurnsAreBlocked(uint256)'
    $after=(Read-Scenario metadata collectionMetadata @($script:state.collectionId))[0]|ConvertTo-Json -Compress
    if ($before -cne $after) {throw 'Read-only prohibited-edit probes changed metadata.'}
    $script:state.prohibitedCalls=$checks;$script:state.frozen=$true;Save-ScenarioState
}
function Read-CompletionAt([string]$Module,[string]$Name,[string[]]$Values=@()) {
    $method=Scenario-Method $Module $Name;$data=Scenario-CallData $Module $Name $Values
    $raw=Invoke-ScenarioRpc 'eth_call' @(@{to=$addresses[$Module];data=$data;gas='0xf42400'},$captureBlock)
    $signature='f()('+(($method.outputs|ForEach-Object {Scenario-CanonicalType $_})-join ',')+')'
    $text=Invoke-ScenarioCast @('abi-decode',$signature,$raw,'--json');$decoded=$text|ConvertFrom-Json -NoEnumerate
    $script:observations+=@{module=$Module;method=$Name;arguments=$Values;target=$addresses[$Module];callData=$data;returnData=$raw;decoded=$decoded}
    return ,@($decoded)
}
function Export-CollectorPackage {
    Require-CompletionReady;Require-CompletionFrozen
    $package=if($CollectorDirectory){[IO.Path]::GetFullPath($CollectorDirectory)}else{Join-Path $OutputDirectory 'collector-package'}
    if (Test-Path -LiteralPath (Join-Path $package 'manifest.json')) {
        & node (Join-Path $completionScriptRoot 'verify_current_stack_collector.mjs') $package
        if ($LASTEXITCODE -ne 0) {throw 'Retained collector package verification failed.'}
        return
    }
    New-Item -ItemType Directory -Path $package -Force|Out-Null
    $captureBlock=if($BlockNumber){Scenario-Hex (Scenario-UInt $BlockNumber)}else{Invoke-ScenarioRpc 'eth_blockNumber'};$header=Invoke-ScenarioRpc 'eth_getBlockByNumber' @($captureBlock,$false)
    $script:observations=@()
    $record=(Read-CompletionAt metadata collectionMetadata @($script:state.collectionId))[0]
    if ($record[4] -cne $artwork) {throw 'Collector workflow only reconstructs its reviewed Field Studies renderer.'}
    $attribution=(Read-CompletionAt artistRegistry attribution @($script:state.collectionId))[0]
    $royalty=(Read-CompletionAt royalty collectionRoyalty @($script:state.collectionId))[0]
    $pointers=[ordered]@{}
    foreach ($name in @('METADATA_ROUTER','ENTROPY_COORDINATOR','ARTIST_REGISTRY','ROYALTY_RESOLVER')) {$pointers[$name]=Read-CompletionAt core getSatellitePointer @((Hash-ScenarioText $name))}
    $collection=[ordered]@{schema='6529stream.collector-field-studies.v1';chainId='31337';core=$addresses.core;collectionId=$script:state.collectionId;blockNumber=(Scenario-UInt $captureBlock).ToString();blockHash=$header.hash;artist=$source.artist;profileId=$source.profileId;wallet=$source.wallet;metadata=$record;attribution=$attribution;royalty=$royalty;pointers=$pointers;tokens=@();limitations=@('Local controller-supplied entropy, not secure randomness.','Collection freeze blocks current collection configuration and burns; token identity/data were immutable at mint.','Global pointers remain governed and can change future Core reads; no global pointer is frozen by this workflow.','No current per-token freeze or complete rendering-input finality registry is installed.','This package verifies retained public observations and portable renderer output, not chain consensus.')}
    foreach ($method in @('collectionStatus','collectionMintedEver','totalSupplyOfCollection','collectionMaxSupply','collectionBurnsBlocked','collectionFreezeStatus')) {
        $value=(Read-CompletionAt core $method @($script:state.collectionId))[0]
        $collection[$method]=if($value -is [bool]){$value}else{[string]$value}
    }
    foreach ($label in @('native','erc20','auction')) {
        $tokenId=[string]$source[$label].tokenId
        $identity=Read-CompletionAt core tokenCollectionIdentity @($tokenId);$seed=Read-CompletionAt entropy tokenSeed @($tokenId)
        $data=(Read-CompletionAt core tokenData @($tokenId))[0];$owner=(Read-CompletionAt core ownerOf @($tokenId))[0]
        $uri=(Read-CompletionAt core tokenURI @($tokenId))[0]
        $metadata=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($uri.Split(',')[1]));$json=$metadata|ConvertFrom-Json
        if ([string]$json.token_id -ne $tokenId -or $json.hash -ne $seed[0]) {throw 'Collector metadata identity mismatch.'}
        $html=[Convert]::FromBase64String($json.animation_url.Split(',')[1])
        $input=[ordered]@{tokenId=$tokenId;collectionId=$script:state.collectionId;serial=[string]$identity[2];seed=$seed[0];tokenData=$data;owner=$owner;label=$label}
        $collection.tokens+=@($input)
        [IO.File]::WriteAllText((Join-Path $package "token-$tokenId.metadata.json"),$metadata,[Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $package "token-$tokenId.html"),$html)
    }
    $code=[ordered]@{}
    foreach ($module in @('core','metadata','entropy','artistRegistry','royalty')) {
        $runtime=Invoke-ScenarioRpc 'eth_getCode' @($addresses[$module],$captureBlock)
        $code[$module]=@{address=$addresses[$module];codeHash=(Hash-ScenarioHex $runtime);runtime=$runtime}
    }
    $collection.contracts=$code
    if ((Invoke-ScenarioRpc 'eth_getBlockByNumber' @($captureBlock,$false)).hash -ine $header.hash) {throw 'Capture block changed.'}
    $collection.observations=$script:observations
    [IO.File]::WriteAllText((Join-Path $package 'collection.json'),($collection|ConvertTo-Json -Depth 100)+"`n",[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $package 'field-studies.js'),$artwork,[Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath (Join-Path $completionScriptRoot 'verify_current_stack_collector.mjs') -Destination (Join-Path $package 'verify.mjs')
    & node (Join-Path $completionScriptRoot 'verify_current_stack_collector.mjs') $package --materialize
    if ($LASTEXITCODE -ne 0) {throw 'Portable collector reconstruction failed.'}
    if ($script:state.Contains('collectorPackage')) {
        if (-not $script:state.Contains('collectorPackageHistory')) {$script:state.collectorPackageHistory=@()}
        $script:state.collectorPackageHistory+=@($script:state.collectorPackage)
    }
    $script:state.collectorPackage=@{path=$package;blockNumber=$collection.blockNumber;blockHash=$header.hash;manifestSha256=(Get-FileHash -LiteralPath (Join-Path $package 'manifest.json') -Algorithm SHA256).Hash.ToLowerInvariant()};Save-ScenarioState
}

$uri=[Uri]$RpcUrl
if ($uri.Host -notin @('127.0.0.1','localhost','::1')) {throw 'Completion only uses local unlocked Anvil.'}
if ((Scenario-UInt (Invoke-ScenarioRpc 'eth_chainId')) -ne 31337) {throw 'Completion requires local chain31337.'}
$deployment=Get-Content -Raw -Encoding UTF8 -LiteralPath $DeploymentState|ConvertFrom-Json -AsHashtable
$source=Get-Content -Raw -Encoding UTF8 -LiteralPath $ScenarioState|ConvertFrom-Json -AsHashtable
if (-not $deployment.developmentEntropy -or $source.core -ine $deployment.addresses.core -or -not $source.export.published) {throw 'Use a fully demonstrated local collection before completion.'}
$controller=$deployment.deployer;$protocol=$deployment.protocol;$Artist=$source.artist;$Buyer=$source.buyer;$SecondBidder=$source.secondBidder
$addresses=$source.addresses
$contracts=@{core='StreamCore';metadata='StreamMetadataRouter';entropy='StreamEntropyCoordinator';artistRegistry='StreamCollectionArtistRegistry';royalty='StreamRoyaltyResolver';executor='StreamGovernanceExecutor';governanceRoot='StreamGovernanceActor';manifest='StreamSystemManifest';auction='StreamEnglishAuctionHouse'}
$artwork=[IO.File]::ReadAllText((Join-Path $completionScriptRoot 'collector/field-studies.js'),[Text.Encoding]::UTF8).TrimEnd([char[]]"`r`n")
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory);$statePath=Join-Path $OutputDirectory 'completion-state.json'
New-Item -ItemType Directory -Path $OutputDirectory -Force|Out-Null
$lock=[IO.File]::Open((Join-Path $OutputDirectory '.completion.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
    $binding=(Get-FileHash -LiteralPath $ScenarioState -Algorithm SHA256).Hash.ToLowerInvariant()
    $script:state=if(Test-Path -LiteralPath $statePath){Get-Content -Raw -Encoding UTF8 -LiteralPath $statePath|ConvertFrom-Json -AsHashtable}else{[ordered]@{schema='6529stream.collection-completion.v1';scenarioStateSha256=$binding;deploymentStateSha256=(Get-FileHash -LiteralPath $DeploymentState -Algorithm SHA256).Hash.ToLowerInvariant();collectionId=[string]$source.collectionId;operations=[ordered]@{};governance=[ordered]@{}}}
    if ($script:state.scenarioStateSha256 -ne $binding -or $script:state.deploymentStateSha256 -ne (Get-FileHash -LiteralPath $DeploymentState -Algorithm SHA256).Hash.ToLowerInvariant()) {throw 'Retained completion inputs changed.'}
    if ($Stage -in @('Complete','All')) {Invoke-ArtworkCompletion}
    if ($Stage -in @('Freeze','All')) {Invoke-CollectionFreeze}
    if ($Stage -in @('Package','All')) {Export-CollectorPackage}
    Save-ScenarioState;Write-Output $statePath
} finally {$lock.Dispose()}
