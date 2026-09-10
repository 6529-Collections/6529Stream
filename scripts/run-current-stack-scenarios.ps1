#requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$DeploymentState,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateSet('Status','Onboard')][string]$Stage = 'Status',
    [string]$RpcUrl = 'http://127.0.0.1:8547',
    [string]$Artist = '',
    [string]$Buyer = '',
    [string]$SecondBidder = '',
    [switch]$Execute,
    [switch]$AdvanceLocalTime
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$zero = '0x' + ('0' * 64)
$zeroAddress = '0x' + ('0' * 40)
$callTuple = '(address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32)'
$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactCache = @{}

function Invoke-ScenarioRpc([string]$Method,[object[]]$Parameters=@()) {
    $body=@{jsonrpc='2.0';id=1;method=$Method;params=@($Parameters)} | ConvertTo-Json -Depth 80 -Compress
    $answer=Invoke-RestMethod -Uri $RpcUrl -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 60
    if ($answer.PSObject.Properties.Name -contains 'error') {throw "RPC $Method failed: $($answer.error | ConvertTo-Json -Depth 12 -Compress)"}
    return $answer.result
}
function Invoke-ScenarioCast([string[]]$Arguments,[string]$InputText='') {
    $output=if ($InputText) {$InputText | & cast @Arguments 2>&1} else {& cast @Arguments 2>&1}
    if ($LASTEXITCODE -ne 0) {throw "cast $($Arguments[0]) failed: $($output -join ' ')"}
    return ($output -join "`n").Trim()
}
function Scenario-UInt([object]$Value) {
    $text=[string]$Value
    if ($text.StartsWith('0x')) {return [bigint]::Parse('0'+$text.Substring(2),[Globalization.NumberStyles]::AllowHexSpecifier)}
    return [bigint]::Parse(($text -split '\s')[0])
}
function Scenario-Hex([bigint]$Value) {return '0x'+$Value.ToString('x').TrimStart('0').PadLeft(1,'0')}
function Hash-ScenarioText([string]$Text) {return Invoke-ScenarioCast @('keccak',$Text)}
function Hash-ScenarioHex([string]$Hex) {return Invoke-ScenarioCast @('keccak') $Hex}
function Encode-Scenario([string]$Types,[string[]]$Values) {return Invoke-ScenarioCast (@('abi-encode',"f($Types)")+$Values)}
function Hash-ScenarioAbi([string]$Types,[string[]]$Values) {return Hash-ScenarioHex (Encode-Scenario $Types $Values)}
function Save-ScenarioState {
    $script:state.updatedAtUtc=[DateTime]::UtcNow.ToString('o')
    $text=$script:state | ConvertTo-Json -Depth 100
    [IO.File]::WriteAllText("$statePath.next",$text+"`n",[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath "$statePath.next" -Destination $statePath -Force
}
function Scenario-CanonicalType([object]$Parameter) {
    if ($Parameter.type.StartsWith('tuple')) {
        return '('+(($Parameter.components | ForEach-Object {Scenario-CanonicalType $_}) -join ',')+')'+$Parameter.type.Substring(5)
    }
    return $Parameter.type
}
function Scenario-Method([string]$Module,[string]$Name) {
    $contract=$contracts[$Module]
    if (-not $artifactCache.ContainsKey($contract)) {
        $path=Join-Path $deployment.artifactDirectory "$contract.sol/$contract.json"
        $artifactCache[$contract]=Get-Content -Raw -Encoding UTF8 -LiteralPath $path | ConvertFrom-Json -AsHashtable
    }
    $matches=@($artifactCache[$contract].abi | Where-Object {$_.type -eq 'function' -and $_.name -eq $Name})
    if ($matches.Count -ne 1) {throw "Expected one ABI method $contract.$Name"}
    return $matches[0]
}
function Scenario-CallData([string]$Module,[string]$Name,[string[]]$Values=@()) {
    $method=Scenario-Method $Module $Name
    $signature=$Name+'('+(($method.inputs | ForEach-Object {Scenario-CanonicalType $_}) -join ',')+')'
    return Invoke-ScenarioCast (@('calldata',$signature)+$Values)
}
function Read-Scenario([string]$Module,[string]$Name,[string[]]$Values=@()) {
    $method=Scenario-Method $Module $Name
    $signature=$Name+'('+(($method.inputs | ForEach-Object {Scenario-CanonicalType $_}) -join ',')+')('+(($method.outputs | ForEach-Object {Scenario-CanonicalType $_}) -join ',')+')'
    $text=Invoke-ScenarioCast (@('call',$addresses[$Module],$signature)+$Values+@('--rpc-url',$RpcUrl,'--json','--gas-limit','16000000'))
    $decoded=$text | ConvertFrom-Json -NoEnumerate
    return ,@($decoded)
}
function Find-ScenarioEvent([object]$Receipt,[string]$Address,[string]$Topic) {
    $items=@($Receipt.logs | Where-Object {$_.address -ieq $Address -and $_.topics[0] -eq $Topic})
    if ($items.Count -ne 1) {throw "Expected one event $Topic from $Address"}
    return $items[0]
}
function Assert-ScenarioTransaction([object]$Actual,[object]$Expected) {
    foreach ($key in @('from','to','input','value','nonce')) {
        $actualValue=if ($key -eq 'input') {$Actual.input} else {$Actual.$key}
        $expectedValue=if ($key -eq 'input') {$Expected.data} else {$Expected[$key]}
        if ($key -in @('value','nonce')) {
            if ((Scenario-UInt $actualValue) -ne (Scenario-UInt $expectedValue)) {throw "Recovered transaction $key differs"}
        } elseif ($actualValue -ine $expectedValue) {throw "Recovered transaction $key differs"}
    }
}
function Send-Scenario([string]$Label,[string]$Sender,[string]$Target,[string]$Data,[string]$Value='0') {
    if (-not $Execute) {throw 'Use -Execute for local transactions.'}
    $identity=Hash-ScenarioAbi 'address,address,uint256,bytes' @($Sender,$Target,$Value,$Data)
    if ($script:state.operations.Contains($Label)) {
        $operation=$script:state.operations[$Label]
        if ($operation.identity -ne $identity) {throw "Operation $Label changed; use its recorded payload or a new scenario directory."}
        if (-not $operation.Contains('transactionHash')) {
            $last=Scenario-UInt (Invoke-ScenarioRpc 'eth_blockNumber')
            if ($last - $operation.startBlock -gt 2048) {throw "Receipt recovery range for $Label exceeds 2048 blocks; retain state for manual recovery."}
            for ($height=[bigint]$operation.startBlock; $height -le $last; $height+=[bigint]1) {
                $block=Invoke-ScenarioRpc 'eth_getBlockByNumber' @((Scenario-Hex $height),$true)
                foreach ($transaction in $block.transactions) {
                    if ($transaction.from -ieq $Sender -and (Scenario-UInt $transaction.nonce) -eq (Scenario-UInt $operation.transaction.nonce)) {
                        Assert-ScenarioTransaction $transaction $operation.transaction
                        $operation.transactionHash=$transaction.hash
                        Save-ScenarioState
                    }
                }
            }
            if (-not $operation.Contains('transactionHash')) {throw "Unresolved send ${Label}: do not replace it or spend a fresh nonce; recover the pending transaction first."}
        }
    } else {
        $latest=Scenario-UInt (Invoke-ScenarioRpc 'eth_getTransactionCount' @($Sender,'latest'))
        $pending=Scenario-UInt (Invoke-ScenarioRpc 'eth_getTransactionCount' @($Sender,'pending'))
        if ($latest -ne $pending) {throw "Sender has a pending transaction before $Label."}
        $transaction=[ordered]@{from=$Sender;data=$Data;value=(Scenario-Hex (Scenario-UInt $Value));nonce=(Scenario-Hex $latest);chainId=(Scenario-Hex 31337)}
        if ($Target -ne $zeroAddress) {$transaction.to=$Target} else {$transaction.to=$null}
        $estimate=Scenario-UInt (Invoke-ScenarioRpc 'eth_estimateGas' @($transaction))
        $limit=[bigint]::Divide(($estimate*130+99),100)
        if ($limit -gt 16777216) {throw "Operation $Label planned gas $limit exceeds the transaction cap; nothing sent."}
        $transaction.gas=Scenario-Hex $limit
        $null=Invoke-ScenarioRpc 'eth_call' @($transaction,'latest')
        $operation=[ordered]@{identity=$identity;transaction=$transaction;startBlock=(Scenario-UInt (Invoke-ScenarioRpc 'eth_blockNumber')).ToString();status='prepared'}
        $script:state.operations[$Label]=$operation
        Save-ScenarioState
        $operation.transactionHash=Invoke-ScenarioRpc 'eth_sendTransaction' @($transaction)
        Save-ScenarioState
    }
    $receipt=$null
    for ($attempt=0; $attempt -lt 40 -and $null -eq $receipt; $attempt++) {
        $receipt=Invoke-ScenarioRpc 'eth_getTransactionReceipt' @($operation.transactionHash)
        if ($null -eq $receipt) {Start-Sleep -Milliseconds 250}
    }
    if ($null -eq $receipt) {throw "Operation $Label is still pending; rerun the same stage."}
    if ((Scenario-UInt $receipt.status) -ne 1) {throw "Operation $Label reverted; retained transaction $($operation.transactionHash)."}
    $actual=Invoke-ScenarioRpc 'eth_getTransactionByHash' @($operation.transactionHash)
    Assert-ScenarioTransaction $actual $operation.transaction
    $operation.receipt=$receipt;$operation.status='confirmed';Save-ScenarioState
    return $receipt
}
function Send-ScenarioMethod([string]$Label,[string]$Sender,[string]$Module,[string]$Name,[string[]]$Values=@(),[string]$Value='0') {
    return Send-Scenario $Label $Sender $addresses[$Module] (Scenario-CallData $Module $Name $Values) $Value
}
function New-ScenarioCall([string]$Module,[string]$Name,[string[]]$Values,[string]$Scope='',[string]$Old='',[string]$New='') {
    $data=Scenario-CallData $Module $Name $Values;$target=$addresses[$Module];$hash=Hash-ScenarioHex $data
    if (-not $Scope) {$Scope=Hash-ScenarioAbi 'address,bytes' @($target,$data);$Old=$zero;$New=$hash}
    return @{target=$target;data=$data;scope=$Scope;old=$Old;new=$New;tuple="($target,0,$($data.Substring(0,10)),$hash,$Scope,$Old,$New)"}
}
function Invoke-ScenarioGovernance([string]$Label,[object[]]$Calls) {
    if ($script:state.governance.Contains($Label) -and -not $script:state.operations.Contains("$Label.schedule")) {
        $pendingTime=Scenario-UInt (Invoke-ScenarioRpc 'eth_getBlockByNumber' @('pending',$false)).timestamp
        $previous=$script:state.governance[$Label]
        if ((Scenario-UInt $previous.notBefore) -lt $pendingTime+172800) {
            if (-not $script:state.Contains('unscheduledGovernanceHistory')) {$script:state.unscheduledGovernanceHistory=@()}
            $script:state.unscheduledGovernanceHistory+=@{label=$Label;reason='Unsubmitted schedule fell below the live 48-hour delay floor.';plan=$previous}
            $Calls=@($previous.calls)
            $script:state.governance.Remove($Label)
            Save-ScenarioState
        }
    }
    if (-not $script:state.governance.Contains($Label)) {
        $tuples='['+(($Calls | ForEach-Object {$_.tuple}) -join ',')+']'
        $data='['+(($Calls | ForEach-Object {$_.data}) -join ',')+']'
        $hash=Hash-ScenarioAbi "bytes32,$callTuple[]" @('0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70',$tuples)
        $transitions=@()
        foreach ($entry in @(@('scope','0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c'),@('old','0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7'),@('new','0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b'))) {
            $values='['+(($Calls | ForEach-Object {$_[''+$entry[0]]}) -join ',')+']'
            $transitions+=Hash-ScenarioAbi 'bytes32,bytes32,bytes32[]' @($entry[1],$hash,$values)
        }
        $now=Scenario-UInt (Invoke-ScenarioRpc 'eth_getBlockByNumber' @('pending',$false)).timestamp
        $ready=($now+173100).ToString();$expires=($now+173100+604800).ToString()
        $manifest=(Read-Scenario manifest streamSystemManifest)[0]
        $schedule=Scenario-CallData executor scheduleGovernanceBatch @('1',$tuples,$transitions[0],$transitions[1],$transitions[2],$ready,$expires,(Hash-ScenarioText "Product demo $Label"),"urn:6529stream:product-demo:$Label",$manifest)
        $script:state.governance[$Label]=[ordered]@{calls=$Calls;tuples=$tuples;data=$data;notBefore=$ready;expiresAfter=$expires;schedule=$schedule;status='planned'}
        Save-ScenarioState
    }
    $action=$script:state.governance[$Label]
    $null=Send-ScenarioMethod "$Label.publish" $controller executor publishGovernanceCallData @($action.data)
    $receipt=Send-ScenarioMethod "$Label.schedule" $controller governanceRoot execute @($addresses.executor,'0',$action.schedule)
    if (-not $action.Contains('actionId')) {
        $topic=Hash-ScenarioText 'GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)'
        $event=Find-ScenarioEvent $receipt $addresses.executor $topic
        $action.actionId=$event.topics[1];$action.status='scheduled';Save-ScenarioState
    }
    $now=Scenario-UInt (Invoke-ScenarioRpc 'eth_getBlockByNumber' @('latest',$false)).timestamp
    if ($now -lt (Scenario-UInt $action.notBefore)) {
        if (-not $AdvanceLocalTime) {throw "Governance $Label is scheduled. Rerun after timestamp $($action.notBefore), or explicitly use -AdvanceLocalTime on this local chain."}
        $null=Invoke-ScenarioRpc 'evm_increaseTime' @([long]((Scenario-UInt $action.notBefore)-$now))
        $null=Invoke-ScenarioRpc 'evm_mine'
    }
    $null=Send-ScenarioMethod "$Label.execute" $controller executor executeGovernanceBatch @($action.actionId,$action.tuples,$action.data)
    $action.status='executed';Save-ScenarioState
}
function New-ScenarioPublisherRoleCall {
    $role=Hash-ScenarioText 'ROLE_EXPORT_PUBLISHER';$registry=$addresses.roleRegistry
    $roleState=Read-Scenario roleRegistry roleMutationState @($role)
    $globalState=Read-Scenario roleRegistry globalRoleMutationState
    $scope=Hash-ScenarioAbi 'bytes32,uint256,address,bytes32,address' @((Hash-ScenarioText '6529STREAM_ROLE_MUTATION_SCOPE_V1'),'31337',$registry,$role,$controller)
    $domain=Hash-ScenarioText '6529STREAM_ROLE_MUTATION_STATE_V1'
    $old=Hash-ScenarioAbi 'bytes32,uint256,address,bytes32,bool,bytes32,uint64,bytes32,uint64' @($domain,'31337',$registry,$scope,'false',$roleState[0],$roleState[1],$globalState[0],$globalState[1])
    $nextRole=((Scenario-UInt $roleState[1])+1).ToString();$nextGlobal=((Scenario-UInt $globalState[1])+1).ToString()
    $roleChain=Hash-ScenarioAbi 'bytes32,bytes32,uint256,address,bytes32,address,bool,uint64' @((Hash-ScenarioText '6529STREAM_ROLE_MUTATION_V1'),$roleState[0],'31337',$registry,$role,$controller,'true',$nextRole)
    $globalChain=Hash-ScenarioAbi 'bytes32,bytes32,uint256,address,bytes32,address,bool,uint64' @((Hash-ScenarioText '6529STREAM_GLOBAL_ROLE_MUTATION_V1'),$globalState[0],'31337',$registry,$role,$controller,'true',$nextGlobal)
    $new=Hash-ScenarioAbi 'bytes32,uint256,address,bytes32,bool,bytes32,uint64,bytes32,uint64' @($domain,'31337',$registry,$scope,'true',$roleChain,$nextRole,$globalChain,$nextGlobal)
    return New-ScenarioCall roleRegistry grantRole @($role,$controller) $scope $old $new
}
function Invoke-ScenarioOnboarding {
    if (-not $script:state.Contains('collectionId')) {
        $script:state.collectionId=((Scenario-UInt (Read-Scenario core lastAllocatedCollectionId)[0])+1).ToString()
        $script:state.phases=@{native=(Hash-ScenarioText 'product-demo native');erc20=(Hash-ScenarioText 'product-demo ERC20');auction=(Hash-ScenarioText 'product-demo auction')}
        $script:state.revenueClass=Hash-ScenarioText 'product-demo primary revenue'
        Save-ScenarioState
    }
    $id=$script:state.collectionId
    $entries="[($Artist,900000,$(Hash-ScenarioText 'artist')),($protocol,100000,$(Hash-ScenarioText 'protocol'))]"
    $metadataHash=Hash-ScenarioText "Product demo profile $id"
    $null=Send-ScenarioMethod 'profile.create' $controller splitFactory createProfile @($entries,$metadataHash)
    $script:state.profileId=(Read-Scenario splitFactory profileIdFor @($entries,$metadataHash))[0]
    $script:state.wallet=(Read-Scenario splitFactory walletFor @($script:state.profileId))[0]
    if ($script:state.profileId -eq $deployment.profile) {throw 'The second artist must have a distinct split profile.'}
    Save-ScenarioState
    if (-not $script:state.governance.Contains('collection.onboard')) {
        if ((Read-Scenario core collectionExists @($id))[0]) {throw 'The proposed collection ID was consumed before this scenario scheduled creation.'}
        $scope=Hash-ScenarioAbi 'bytes32,uint256,address,uint256' @('0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16','31337',$addresses.core,$id)
        $domain='0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5'
        $old=Hash-ScenarioAbi 'bytes32,bytes32,bool,uint8,uint8,bool,uint256' @($domain,$scope,'false','0','0','false','0')
        $new=Hash-ScenarioAbi 'bytes32,bytes32,bool,uint8,uint8,bool,uint256' @($domain,$scope,'true','0','0','true','10')
        $calls=@(New-ScenarioCall core createCollection @('0','true','10','0') $scope $old $new)
        $calls+=New-ScenarioCall entropy configureCollection @($id,$addresses.provider,(Hash-ScenarioText "Product demo collection salt $id"),'true','100')
        $calls+=New-ScenarioCall metadata setCollectionMetadata @($id,'Stream second artist','A second collection operated through real governance.','','')
        $calls+=New-ScenarioCall metadata setCollectionScript @($id,"document.body.textContent='STREAM '+tokenId+' '+tokenHash;")
        $calls+=New-ScenarioCall artistRegistry nominateArtist @($id,$Artist,(Hash-ScenarioText "Product demo artist $Artist"))
        $calls+=New-ScenarioCall royalty configureCollectionRoyalty @($id,$script:state.profileId,'690')
        foreach ($phaseName in @('native','erc20','auction')) {
            $phase=$script:state.phases[$phaseName]
            $config="(false,0,0,1,$(Hash-ScenarioText "Product demo $phaseName"),$(Hash-ScenarioText 'Product demo metadata'))"
            $gate="($zeroAddress,$zero,$zero,$zero,0,0)"
            $counter="[(true,1,1,0,10,1,$(Hash-ScenarioText 'Product demo counter'))]"
            $calls+=New-ScenarioCall manager configurePhase @($id,$phase,$config,$gate,"[$(Hash-ScenarioText 'supply')]",$counter)
            $adapter=@{native='nativeSale';erc20='erc20Sale';auction='auction'}[$phaseName]
            $calls+=New-ScenarioCall manager setPhaseExecutor @($id,$phase,$addresses[$adapter],'true')
        }
        $calls+=New-ScenarioCall primaryRevenue setPrimaryProfileAssignment @($script:state.revenueClass,'1',$id,$script:state.profileId,(Hash-ScenarioText "Product demo assignment $id"))
        if (-not (Read-Scenario roleRegistry hasRole @((Hash-ScenarioText 'ROLE_EXPORT_PUBLISHER'),$controller))[0]) {$calls+=New-ScenarioPublisherRoleCall}
        Invoke-ScenarioGovernance 'collection.onboard' $calls
    } else {Invoke-ScenarioGovernance 'collection.onboard' @()}
    if ((Read-Scenario artistRegistry acceptedArtist @($id))[0] -eq $zeroAddress) {
        if (-not $script:state.Contains('acceptance')) {
            $attribution=(Read-Scenario artistRegistry attribution @($id))[0]
            $now=Scenario-UInt (Invoke-ScenarioRpc 'eth_getBlockByNumber' @('latest',$false)).timestamp
            $script:state.acceptance=@{nominationHash=$attribution[3];nonce=(Read-Scenario artistRegistry acceptanceNonces @($Artist))[0];deadline=($now+3600).ToString()};Save-ScenarioState
        }
        $a=$script:state.acceptance
        $null=Send-ScenarioMethod 'artist.accept' $Artist artistRegistry acceptArtist @($id,$a.nominationHash,$a.nonce,$a.deadline,'0x')
    }
    if ((Read-Scenario artistRegistry acceptedArtist @($id))[0] -ine $Artist) {throw 'Second artist acceptance mismatch.'}
    if (-not (Read-Scenario core collectionExists @($id))[0]) {throw 'Second collection was not created.'}
    $script:state.onboarded=$true;Save-ScenarioState
}

$uri=[Uri]$RpcUrl
if ($uri.Host -notin @('127.0.0.1','localhost','::1')) {throw 'Product scenarios only use a local unlocked Anvil endpoint.'}
if ((Scenario-UInt (Invoke-ScenarioRpc 'eth_chainId')) -ne 31337) {throw 'Product scenarios require local chain 31337.'}
$deployment=Get-Content -Raw -Encoding UTF8 -LiteralPath $DeploymentState | ConvertFrom-Json -AsHashtable
if ($deployment.chainId -ne 31337 -or -not $deployment.developmentEntropy) {throw 'Use the retained local development-entropy deployment, not a live or VRF deployment.'}
$controller=$deployment.deployer;$protocol=$deployment.protocol
$accounts=@(Invoke-ScenarioRpc 'eth_accounts')
if (-not $Artist) {$Artist=$accounts[2]};if (-not $Buyer) {$Buyer=$accounts[3]};if (-not $SecondBidder) {$SecondBidder=$accounts[4]}
if ($Artist -ieq $controller -or $Artist -ieq $protocol) {throw 'Choose a distinct second artist.'}
foreach ($actor in @($controller,$Artist,$Buyer,$SecondBidder)) {if ($actor -notin $accounts) {throw 'All scenario actors must be unlocked local test accounts.'}}
$addresses=[ordered]@{core=$deployment.addresses.core;manager=$deployment.addresses.manager;nativeSale=$deployment.addresses.sale;erc20Sale=$deployment.addresses.erc20Sale;auction=$deployment.addresses.auction;artistRegistry=$deployment.addresses.artistRegistry;entropy=$deployment.addresses.entropy;splitFactory=$deployment.addresses.factory;primaryRevenue=$deployment.addresses.primaryRevenueResolver;assetPolicy=$deployment.addresses.assetPolicyRegistry;executor=$deployment.addresses.executor;governanceRoot=$deployment.addresses.governanceRoot;roleRegistry=$deployment.addresses.roleRegistry;manifest=$deployment.addresses.manifest;metadata=$deployment.addresses.metadata;royalty=$deployment.addresses.royalty;provider=$deployment.addresses.provider}
$contracts=@{core='StreamCore';manager='StreamMintManager';nativeSale='StreamFixedPriceSaleAdapter';erc20Sale='StreamERC20FixedPriceSaleAdapter';auction='StreamEnglishAuctionHouse';artistRegistry='StreamCollectionArtistRegistry';entropy='StreamEntropyCoordinator';splitFactory='StreamSplitFactory';primaryRevenue='StreamRevenueResolver';assetPolicy='StreamAssetPolicyRegistry';executor='StreamGovernanceExecutor';governanceRoot='StreamGovernanceActor';roleRegistry='StreamRoleRegistry';manifest='StreamSystemManifest';metadata='StreamMetadataRouter';royalty='StreamRoyaltyResolver';provider='DevelopmentEntropyProvider'}
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory);$statePath=Join-Path $OutputDirectory 'scenario-state.json'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$lock=[IO.File]::Open((Join-Path $OutputDirectory '.scenario.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
    $binding=(Get-FileHash -Algorithm SHA256 -LiteralPath $DeploymentState).Hash.ToLowerInvariant()
    $script:state=if (Test-Path -LiteralPath $statePath) {Get-Content -Raw -Encoding UTF8 -LiteralPath $statePath | ConvertFrom-Json -AsHashtable} else {[ordered]@{schema='6529stream.product-scenarios.v1';deploymentStateSha256=$binding;chainId='31337';core=$addresses.core;artist=$Artist;buyer=$Buyer;secondBidder=$SecondBidder;operations=[ordered]@{};governance=[ordered]@{}}}
    if ($script:state.deploymentStateSha256 -ne $binding -or $script:state.artist -ine $Artist -or $script:state.buyer -ine $Buyer -or $script:state.secondBidder -ine $SecondBidder) {throw 'Scenario deployment or actor binding changed.'}
    if ((Read-Scenario governanceRoot controller)[0] -ine $controller) {throw 'Governance root controller differs from the deployment.'}
    if ((Read-Scenario artistRegistry acceptedArtist @('1'))[0] -ine $controller) {throw 'Original collection attribution changed.'}
    $config=[ordered]@{schemaVersion=1;chainId='31337';addresses=$addresses}
    [IO.File]::WriteAllText((Join-Path $OutputDirectory 'client-config.json'),($config | ConvertTo-Json -Depth 8)+"`n",[Text.UTF8Encoding]::new($false))
    if ($Stage -eq 'Onboard') {Invoke-ScenarioOnboarding}
    Save-ScenarioState
    Write-Output $statePath
} finally {$lock.Dispose()}
