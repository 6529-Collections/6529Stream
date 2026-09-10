#requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$DeploymentState,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateSet('Status','Onboard','Native','ERC20','Auction','Export','All')][string]$Stage = 'Status',
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
function Invoke-ScenarioTestTokenPreparation {
    Push-Location $repoRoot
    try {
        $result=& python -m tools.deployment.prepare_current_stack_test_token --output-dir (Join-Path $OutputDirectory 'test-token-compilation') --deployment-artifacts $deployment.artifactDirectory
        if ($LASTEXITCODE -ne 0) {throw 'Local test-token preparation failed; retained compiler log identifies the failure.'}
        return ($result -join "`n") | ConvertFrom-Json -AsHashtable
    } finally {Pop-Location}
}
function Initialize-ScenarioPaymentToken {
    $prepared=Invoke-ScenarioTestTokenPreparation
    $artifactBytes=[IO.File]::ReadAllBytes($prepared.artifact_path)
    $actualHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($artifactBytes)).ToLowerInvariant()
    if ($actualHash -cne $prepared.artifact_sha256) {throw 'Prepared local test-token artifact hash differs.'}
    $artifactCache['MockStreamPaymentToken']=[Text.Encoding]::UTF8.GetString($artifactBytes) | ConvertFrom-Json -AsHashtable
    $contracts.paymentToken='MockStreamPaymentToken'
    return $prepared
}
function Get-ScenarioArtifact([string]$Module) {
    $contract=$contracts[$Module]
    if (-not $artifactCache.ContainsKey($contract)) {
        $path=Join-Path $deployment.artifactDirectory "$contract.sol/$contract.json"
        $artifactCache[$contract]=Get-Content -Raw -Encoding UTF8 -LiteralPath $path | ConvertFrom-Json -AsHashtable
    }
    return $artifactCache[$contract]
}
function Scenario-Method([string]$Module,[string]$Name) {
    $artifact=Get-ScenarioArtifact $Module
    $matches=@($artifact.abi | Where-Object {$_.type -eq 'function' -and $_.name -eq $Name})
    if ($matches.Count -ne 1) {throw "Expected one ABI method $Module.$Name"}
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
    foreach ($key in @('from','to','input','value','nonce','gas','chainId')) {
        $actualValue=if ($key -eq 'input') {$Actual.input} else {$Actual.$key}
        $expectedValue=if ($key -eq 'input') {$Expected.data} else {$Expected[$key]}
        if ($key -in @('value','nonce','gas','chainId')) {
            if ((Scenario-UInt $actualValue) -ne (Scenario-UInt $expectedValue)) {throw "Recovered transaction $key differs"}
        } elseif ($actualValue -ine $expectedValue) {throw "Recovered transaction $key differs"}
    }
}
function Assert-ScenarioReceipt([object]$Receipt,[object]$Actual,[object]$Header,[string]$ExpectedHash) {
    if ($Actual.hash -ine $ExpectedHash -or $Receipt.transactionHash -ine $ExpectedHash) {throw 'Receipt transaction hash differs from the recorded operation.'}
    if ($Header.hash -ine $Receipt.blockHash -or $Actual.blockHash -ine $Receipt.blockHash -or (Scenario-UInt $Header.number) -ne (Scenario-UInt $Receipt.blockNumber) -or (Scenario-UInt $Actual.blockNumber) -ne (Scenario-UInt $Receipt.blockNumber)) {throw 'Receipt is not in its recorded canonical block.'}
    if ($Receipt.from -ine $Actual.from -or $Receipt.to -ine $Actual.to) {throw 'Receipt sender or target differs from the transaction.'}
    $index=Scenario-UInt $Receipt.transactionIndex
    $members=@($Header.transactions)
    if ($index -lt 0 -or $index -ne (Scenario-UInt $Actual.transactionIndex) -or $index -ge $members.Count -or $members[[int]$index] -ine $ExpectedHash) {throw 'Receipt transaction index or canonical membership differs.'}
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
    $header=Invoke-ScenarioRpc 'eth_getBlockByNumber' @($receipt.blockNumber,$false)
    Assert-ScenarioReceipt $receipt $actual $header $operation.transactionHash
    $operation.receipt=$receipt;$operation.rpcTransaction=$actual;$operation.blockHeader=$header;$operation.status='confirmed';Save-ScenarioState
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
function Invoke-ScenarioGovernance([string]$Label,[object[]]$Calls,[byte]$ActionClass=1) {
    $delay=Scenario-UInt (Read-Scenario executor minimumDelay @([string]$ActionClass))[0]
    if ($script:state.governance.Contains($Label)) {
        $saved=$script:state.governance[$Label]
        $savedClass=if ($saved.Contains('actionClass')) {[byte]$saved.actionClass} else {[byte]1}
        if ($savedClass -ne $ActionClass) {throw 'Governance action class changed for a retained plan.'}
    }
    if ($script:state.governance.Contains($Label) -and -not $script:state.operations.Contains("$Label.schedule")) {
        $pendingTime=Scenario-UInt (Invoke-ScenarioRpc 'eth_getBlockByNumber' @('pending',$false)).timestamp
        $previous=$script:state.governance[$Label]
        if ((Scenario-UInt $previous.notBefore) -lt $pendingTime+$delay) {
            if (-not $script:state.Contains('unscheduledGovernanceHistory')) {$script:state.unscheduledGovernanceHistory=@()}
            $script:state.unscheduledGovernanceHistory+=@{label=$Label;reason='Unsubmitted schedule fell below the live governance delay floor.';plan=$previous}
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
        $ready=($now+$delay+300).ToString();$expires=($now+$delay+300+604800).ToString()
        $manifest=(Read-Scenario manifest streamSystemManifest)[0]
        $schedule=Scenario-CallData executor scheduleGovernanceBatch @([string]$ActionClass,$tuples,$transitions[0],$transitions[1],$transitions[2],$ready,$expires,(Hash-ScenarioText "Product demo $Label"),"urn:6529stream:product-demo:$Label",$manifest)
        $script:state.governance[$Label]=[ordered]@{actionClass=[string]$ActionClass;calls=$Calls;tuples=$tuples;data=$data;notBefore=$ready;expiresAfter=$expires;schedule=$schedule;status='planned'}
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
    }
    if ($script:state.Contains('acceptance')) {
        $a=$script:state.acceptance
        $null=Send-ScenarioMethod 'artist.accept' $Artist artistRegistry acceptArtist @($id,$a.nominationHash,$a.nonce,$a.deadline,'0x')
    }
    if ((Read-Scenario artistRegistry acceptedArtist @($id))[0] -ine $Artist) {throw 'Second artist acceptance mismatch.'}
    if (-not (Read-Scenario core collectionExists @($id))[0]) {throw 'Second collection was not created.'}
    $script:state.onboarded=$true;Save-ScenarioState
}

function Require-ScenarioOnboarded {
    if (-not $script:state.Contains('onboarded') -or -not $script:state.onboarded) {throw 'Complete Onboard before the product scenarios.'}
    $addresses.wallet=$script:state.wallet;$contracts.wallet='StreamSplitWallet'
}
function Scenario-Event([object]$Receipt,[string]$Module,[string]$Name) {
    $artifact=Get-ScenarioArtifact $Module
    $events=@($artifact.abi | Where-Object {$_.type -eq 'event' -and $_.name -eq $Name})
    if ($events.Count -ne 1) {throw "Expected one ABI event $Module.$Name"}
    $event=$events[0];$signature=$Name+'('+(($event.inputs|ForEach-Object {Scenario-CanonicalType $_}) -join ',')+')'
    $log=Find-ScenarioEvent $Receipt $addresses[$Module] (Hash-ScenarioText $signature)
    $plain=@($event.inputs|Where-Object {-not $_.indexed})
    $decoded=@()
    if ($plain.Count) {
        $signature='f()('+(($plain|ForEach-Object {Scenario-CanonicalType $_}) -join ',')+')'
        $raw=Invoke-ScenarioCast @('abi-decode',$signature,$log.data,'--json')
        $decoded=$raw|ConvertFrom-Json -NoEnumerate
    }
    $values=[ordered]@{};$topicIndex=1;$dataIndex=0
    foreach ($input in $event.inputs) {
        if ($input.indexed) {
            $word=$log.topics[$topicIndex];$topicIndex++
            $values[$input.name]=if ($input.type.StartsWith('uint')) {(Scenario-UInt $word).ToString()} elseif ($input.type -eq 'address') {'0x'+$word.Substring(26)} else {$word}
        } else {$values[$input.name]=$decoded[$dataIndex];$dataIndex++}
    }
    return $values
}
function New-ScenarioAuthorization([string]$Label,[string]$Kind,[string]$Module,[object]$Message) {
    if (-not $script:state.Contains('authorizations')) {$script:state.authorizations=[ordered]@{}}
    if (-not $script:state.authorizations.Contains($Label)) {
        $script:state.authorizations[$Label]=[ordered]@{kind=$Kind;chainId='31337';verifyingContract=$addresses[$Module];message=$Message}
        Save-ScenarioState
    }
    $request=$script:state.authorizations[$Label]
    foreach ($key in @($request.message.Keys)) {$request.message[$key]=[string]$request.message[$key]}
    Save-ScenarioState
    $path=Join-Path $OutputDirectory "$Label.signing-request.json"
    [IO.File]::WriteAllText($path,($request|ConvertTo-Json -Depth 30)+"`n",[Text.UTF8Encoding]::new($false))
    $prepared=& node (Join-Path $repoRoot 'packages/stream-client/examples/prepare.mjs') $path 2>&1
    if ($LASTEXITCODE -ne 0) {throw "Build the current client package before signing: $($prepared -join ' ')"}
    $typed=($prepared -join "`n")|ConvertFrom-Json -AsHashtable
    [IO.File]::WriteAllText((Join-Path $OutputDirectory "$Label.typed-data.json"),($typed|ConvertTo-Json -Depth 30)+"`n",[Text.UTF8Encoding]::new($false))
    $tuple='('+(($request.message.Values) -join ',')+')'
    $method=if($Kind -eq 'paymentIntent'){'paymentIntentDigest'}else{'authorizationDigest'}
    $onchain=(Read-Scenario $Module $method @($tuple))[0]
    if ($onchain -ne $typed.digest) {throw "Client digest differs from the deployed contract for $Label."}
    $rpcPrepared=& node (Join-Path $repoRoot 'packages/stream-client/examples/prepare.mjs') --rpc $path 2>&1
    if ($LASTEXITCODE -ne 0) {throw "Client RPC payload preparation failed: $($rpcPrepared -join ' ')"}
    $rpcPayload=($rpcPrepared -join "`n")|ConvertFrom-Json -AsHashtable
    return @{request=$request;typed=$typed;rpc=$rpcPayload;tuple=$tuple}
}
function Sign-ScenarioTyped([string]$Signer,[object]$Typed) {
    if (-not $Execute) {throw 'Signing local test payloads requires -Execute.'}
    if (-not $Typed.types.Contains('EIP712Domain')) {throw 'Use the client package RPC signing payload.'}
    return Invoke-ScenarioRpc 'eth_signTypedData_v4' @($Signer,($Typed|ConvertTo-Json -Depth 30 -Compress))
}
function Complete-ScenarioEntropy([string]$Label,[string]$TokenId) {
    $requestReceipt=Send-ScenarioMethod "$Label.entropy.request" $Buyer entropy requestEntropy @($TokenId)
    $event=Scenario-Event $requestReceipt entropy EntropyRequested
    if ([string]$event.tokenId -ne $TokenId -or $event.provider -ine $addresses.provider) {throw 'Entropy event identity differs from the scenario token/provider.'}
    $raw=Hash-ScenarioText "Development-only product entropy $Label $TokenId"
    $receipt=Send-ScenarioMethod "$Label.entropy.fulfill" $controller provider fulfill @([string]$event.providerRequestId,$raw)
    $seed=Read-Scenario entropy tokenSeed @($TokenId)
    if (-not $seed[1] -or $seed[0] -eq $zero) {throw 'Scenario entropy did not finalize.'}
    $notification=Find-ScenarioEvent $receipt $addresses.core (Hash-ScenarioText 'MetadataUpdate(uint256)')
    $decoded=Invoke-ScenarioCast @('abi-decode','f()(uint256)',$notification.data,'--json')|ConvertFrom-Json -NoEnumerate
    if ([string]$decoded[0] -ne $TokenId -or (Read-Scenario entropy metadataNotificationPending @($TokenId))[0]) {throw 'Metadata notification did not complete for the scenario token.'}
    $uri=(Read-Scenario core tokenURI @($TokenId))[0]
    if (-not $uri.StartsWith('data:application/json;base64,')) {throw 'Expected onchain metadata.'}
    $json=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($uri.Split(',')[1]));$metadata=$json|ConvertFrom-Json
    if ($metadata.metadata_state -ne 'final' -or [string]$metadata.token_id -ne $TokenId -or [string]$metadata.collection_id -ne $script:state.collectionId -or $metadata.hash -ne $seed[0] -or $metadata.artist -ine $Artist) {throw 'Final metadata identity, artist or seed differs from the scenario token.'}
    [IO.File]::WriteAllText((Join-Path $OutputDirectory "$Label.metadata.json"),$json+"`n",[Text.UTF8Encoding]::new($false))
    return @{tokenId=$TokenId;requestKey=$event.requestKey;providerRequestId=[string]$event.providerRequestId;seed=$seed[0];metadataState='final';notificationDelivered=$true;randomness='Controller-supplied development value, not secure randomness.'}
}
function Release-ScenarioProceeds([string]$Label,[string]$Asset,[string]$Amount) {
    if (-not $script:state.Contains('withdrawals')) {$script:state.withdrawals=[ordered]@{}}
    $receiptA=Send-ScenarioMethod "$Label.artist.withdraw" $Artist wallet release @($Asset,$Artist,$Artist)
    $receiptP=Send-ScenarioMethod "$Label.protocol.withdraw" $controller wallet release @($Asset,$protocol,$protocol)
    $eventName=if($Asset -eq $zeroAddress){'NativeReleased'}else{'ERC20Released'}
    $a=Scenario-Event $receiptA wallet $eventName;$p=Scenario-Event $receiptP wallet $eventName
    $artistAmount=[bigint]::Divide((Scenario-UInt $Amount)*9,10);$protocolAmount=(Scenario-UInt $Amount)-$artistAmount
    if ((Scenario-UInt $a.amount) -ne $artistAmount -or (Scenario-UInt $p.amount) -ne $protocolAmount) {throw "Unexpected split amounts in $Label receipts."}
    if ((Scenario-UInt (Read-Scenario wallet accountReleased @($Asset,$Artist))[0]) -lt $artistAmount -or (Scenario-UInt (Read-Scenario wallet accountReleased @($Asset,$protocol))[0]) -lt $protocolAmount) {throw 'Split release accounting is inconsistent.'}
    $script:state.withdrawals[$Label]=@{asset=$Asset;artist=$artistAmount.ToString();protocol=$protocolAmount.ToString()};Save-ScenarioState
}
function Invoke-ScenarioNative {
    Require-ScenarioOnboarded
    $id=$script:state.collectionId;$phase=$script:state.phases.native;$price='1000000000000'
    $tokenData='0x'+[Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes('Second artist native purchase'))
    $now=Scenario-UInt (Invoke-ScenarioRpc 'eth_getBlockByNumber' @('pending',$false)).timestamp
    $message=[ordered]@{collectionId=$id;phaseId=$phase;payer=$Buyer;recipient=$Buyer;artist=$Artist;profileId=$script:state.profileId;tokenDataHash=(Hash-ScenarioHex $tokenData);mintCommitment=(Hash-ScenarioText "Native artwork $id");mintPolicyHash=(Read-Scenario manager phasePolicyHash @($id,$phase))[0];price=$price;nonce=(Hash-ScenarioText "Product demo native $id");deadline=($now+3600).ToString();signerEpoch=(Read-Scenario nativeSale signerEpoch)[0]}
    $auth=New-ScenarioAuthorization 'native' 'nativeSale' 'nativeSale' $message
    $platform=(Read-Scenario nativeSale platformSigner)[0]
    $receipt=Send-ScenarioMethod 'native.buy' $Buyer nativeSale buy @($auth.tuple,$tokenData,(Sign-ScenarioTyped $platform $auth.rpc),(Sign-ScenarioTyped $Artist $auth.rpc)) $price
    $event=Scenario-Event $receipt nativeSale NativeSaleSettled
    $tokenId=[string]$event.tokenId
    $script:state.native=Complete-ScenarioEntropy 'native' $tokenId
    if ((Read-Scenario core ownerOf @($tokenId))[0] -ine $Buyer) {throw 'Native purchaser does not own the NFT.'}
    Release-ScenarioProceeds 'native' $zeroAddress $price
    $script:state.native.price=$price;Save-ScenarioState
}
function Invoke-ScenarioERC20 {
    Require-ScenarioOnboarded
    $prepared=Initialize-ScenarioPaymentToken
    $artifact=Get-ScenarioArtifact paymentToken
    $receipt=Send-Scenario 'erc20.token.deploy' $controller $zeroAddress $artifact.bytecode.object
    if ($script:state.Contains('paymentToken') -and $script:state.paymentToken -ine $receipt.contractAddress) {throw 'Stored test-token address differs from its deployment receipt.'}
    $script:state.paymentToken=$receipt.contractAddress
    $code=Invoke-ScenarioRpc 'eth_getCode' @($receipt.contractAddress,'latest')
    if ($code -ine $artifact.deployedBytecode.object) {throw 'Local test-token runtime differs from the selected artifact.'}
    # Reproduction checks current source against the original transaction/runtime;
    # it does not relabel an older token's original compiler provenance.
    $script:state.paymentTokenCurrentSourceReproduction=$prepared
    $script:state.paymentTokenDisclosure='MockStreamPaymentToken in standard mode, deployed only on local chain 31337. Not an approved public stablecoin.'
    Save-ScenarioState
    $addresses.paymentToken=$script:state.paymentToken;$contracts.paymentToken='MockStreamPaymentToken'
    $id=$script:state.collectionId;$phase=$script:state.phases.erc20;$price='1000'
    if (-not $script:state.governance.Contains('erc20.configure')) {
        $policy=Read-Scenario erc20Sale primaryPolicy @($id,$script:state.revenueClass)
        $now=Scenario-UInt (Invoke-ScenarioRpc 'eth_getBlockByNumber' @('pending',$false)).timestamp
        $config="($id,$phase,$($addresses.paymentToken),$($script:state.revenueClass),$price,$((Read-Scenario manager phasePolicyHash @($id,$phase))[0]),$($policy[0]),0,$($now+2592000))"
        $calls=@(New-ScenarioCall assetPolicy setAssetStatus @($addresses.paymentToken,'1',(Hash-ScenarioText 'Local standard-mode test token')))
        $calls+=New-ScenarioCall erc20Sale registerSale @($config)
        Invoke-ScenarioGovernance 'erc20.configure' $calls
    } else {Invoke-ScenarioGovernance 'erc20.configure' @()}
    $configured=Scenario-Event $script:state.operations['erc20.configure.execute'].receipt erc20Sale SaleConfigured
    $saleId=$configured.saleId;$record=(Read-Scenario erc20Sale saleRecord @($saleId))[0]
    $null=Send-ScenarioMethod 'erc20.token.mint' $controller paymentToken mint @($Buyer,'10000')
    $null=Send-ScenarioMethod 'erc20.approve' $Buyer paymentToken approve @($addresses.erc20Sale,$price)
    $tokenData='0x'+[Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes('Second artist ERC20 purchase'))
    $now=Scenario-UInt (Invoke-ScenarioRpc 'eth_getBlockByNumber' @('pending',$false)).timestamp
    $message=[ordered]@{saleId=$saleId;saleConfigHash=$record[2];payer=$Buyer;recipient=$Buyer;artist=$Artist;tokenDataHash=(Hash-ScenarioHex $tokenData);mintCommitment=(Hash-ScenarioText "ERC20 artwork $id");nonce=(Hash-ScenarioText "Product demo ERC20 $id");deadline=($now+3600).ToString();signerEpoch=(Read-Scenario erc20Sale signerEpoch)[0]}
    $auth=New-ScenarioAuthorization 'erc20.sale' 'erc20Sale' 'erc20Sale' $message
    $intent=[ordered]@{payer=$Buyer;asset=$addresses.paymentToken;maxAmount=$price;saleRef=$saleId;expectedPrimaryPolicyHash=$record[0][6];nonce=(Hash-ScenarioText "Product demo payer $id");deadline=$auth.request.message.deadline}
    $payment=New-ScenarioAuthorization 'erc20.payment' 'paymentIntent' 'erc20Sale' $intent
    $platform=(Read-Scenario erc20Sale platformSigner)[0]
    $receipt=Send-ScenarioMethod 'erc20.buy' $controller erc20Sale buy @($auth.tuple,$tokenData,(Sign-ScenarioTyped $platform $auth.rpc),(Sign-ScenarioTyped $Artist $auth.rpc),$payment.tuple,(Sign-ScenarioTyped $Buyer $payment.rpc))
    $event=Scenario-Event $receipt erc20Sale ERC20SaleSettled;$tokenId=[string]$event.tokenId
    $script:state.erc20=Complete-ScenarioEntropy 'erc20' $tokenId
    if ((Read-Scenario core ownerOf @($tokenId))[0] -ine $Buyer) {throw 'ERC20 purchaser does not own the NFT.'}
    Release-ScenarioProceeds 'erc20' $addresses.paymentToken $price
    $script:state.erc20.saleId=$saleId;$script:state.erc20.price=$price;$script:state.erc20.asset=$addresses.paymentToken;Save-ScenarioState
}
function Invoke-ScenarioAuction {
    Require-ScenarioOnboarded
    $id=$script:state.collectionId;$phase=$script:state.phases.auction
    $tokenData='0x'+[Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes('Second artist auction artwork'))
    $now=Scenario-UInt (Invoke-ScenarioRpc 'eth_getBlockByNumber' @('pending',$false)).timestamp
    $message=[ordered]@{collectionId=$id;phaseId=$phase;artist=$Artist;profileId=$script:state.profileId;tokenDataHash=(Hash-ScenarioHex $tokenData);mintCommitment=(Hash-ScenarioText "Auction artwork $id");mintPolicyHash=(Read-Scenario manager phasePolicyHash @($id,$phase))[0];reservePrice='1000000000000';startTime=$now.ToString();endTime=($now+600).ToString();extensionWindow='60';minBidIncrementBps='1000';nonce=(Hash-ScenarioText "Product demo auction $id");deadline=($now+3600).ToString();signerEpoch=(Read-Scenario auction signerEpoch)[0]}
    $auth=New-ScenarioAuthorization 'auction' 'auction' 'auction' $message
    $platform=(Read-Scenario auction platformSigner)[0]
    $receipt=Send-ScenarioMethod 'auction.create' $controller auction createAuction @($auth.tuple,$tokenData,(Sign-ScenarioTyped $platform $auth.rpc),(Sign-ScenarioTyped $Artist $auth.rpc))
    $created=Scenario-Event $receipt auction AuctionCreated;$tokenId=[string]$created.tokenId
    $script:state.auction=Complete-ScenarioEntropy 'auction' $tokenId
    $null=Send-ScenarioMethod 'auction.bid.first' $Buyer auction bid @($tokenId,$Buyer) '1000000000000'
    $null=Send-ScenarioMethod 'auction.bid.second' $SecondBidder auction bid @($tokenId,$SecondBidder) '1100000000000'
    $refund=Send-ScenarioMethod 'auction.refund.first' $Buyer auction withdrawRefund @($Buyer)
    $refunded=Scenario-Event $refund auction AuctionRefundWithdrawn
    if ((Scenario-UInt $refunded.amount) -ne 1000000000000 -or (Scenario-UInt (Read-Scenario auction refundCredit @($Buyer))[0]) -ne 0) {throw 'Outbid buyer refund did not complete.'}
    $auction=(Read-Scenario auction auction @($tokenId))[0]
    $now=Scenario-UInt (Invoke-ScenarioRpc 'eth_getBlockByNumber' @('latest',$false)).timestamp
    if ($now -le (Scenario-UInt $auction[5])) {
        if (-not $AdvanceLocalTime) {throw "Auction $tokenId ends at $($auction[5]); rerun after that timestamp."}
        $null=Invoke-ScenarioRpc 'evm_increaseTime' @([long]((Scenario-UInt $auction[5])-$now+1));$null=Invoke-ScenarioRpc 'evm_mine'
    }
    $null=Send-ScenarioMethod 'auction.settle' $controller auction settle @($tokenId)
    if ((Read-Scenario core ownerOf @($tokenId))[0] -ine $SecondBidder) {throw 'Winning bidder did not receive the auction NFT.'}
    Release-ScenarioProceeds 'auction' $zeroAddress '1100000000000'
    $script:state.auction.winner=$SecondBidder;$script:state.auction.winningBid='1100000000000';$script:state.auction.refund='1000000000000';Save-ScenarioState
}
function Invoke-ScenarioExport {
    Require-ScenarioOnboarded
    if (-not $script:state.Contains('export')) {
        if (-not $Execute) {throw 'Export publication requires -Execute.'}
        $null=Invoke-ScenarioRpc 'evm_mine'
        $height=(Scenario-UInt (Invoke-ScenarioRpc 'eth_blockNumber'))-1
        $anchor=Invoke-ScenarioRpc 'eth_getBlockByNumber' @((Scenario-Hex $height),$false)
        $snapshot=[ordered]@{schema='6529stream.product-demo-snapshot.v1';scope='Demonstration collection ownership, not a complete protocol reconstruction';chainId='31337';core=$addresses.core;blockNumber=$height.ToString();blockHash=$anchor.hash;collectionId=$script:state.collectionId;artist=$Artist;profileId=$script:state.profileId;tokens=[ordered]@{}}
        foreach ($label in @('native','erc20','auction')) {
            if ($script:state.Contains($label)) {
                $tokenId=$script:state[$label].tokenId
                $owner=Invoke-ScenarioCast @('call',$addresses.core,'ownerOf(uint256)(address)',$tokenId,'--block',$height.ToString(),'--rpc-url',$RpcUrl)
                $snapshot.tokens[$label]=@{tokenId=$tokenId;owner=$owner}
            }
        }
        $path=Join-Path $OutputDirectory 'state-export.snapshot.json'
        $bytes=[Text.Encoding]::UTF8.GetBytes(($snapshot|ConvertTo-Json -Depth 20 -Compress)+"`n");[IO.File]::WriteAllBytes($path,$bytes)
        $hash=Hash-ScenarioHex ('0x'+[Convert]::ToHexString($bytes))
        $script:state.export=[ordered]@{blockNumber=$height.ToString();blockHash=$anchor.hash;exportHash=$hash;manifestHash=(Read-Scenario manifest streamSystemManifest)[0];manifestURI="urn:6529stream:local-product-export:$hash";snapshotFile=$path;snapshotSha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()};Save-ScenarioState
    }
    $e=$script:state.export
    $receipt=Send-ScenarioMethod 'export.publish' $controller executor publishStateExport @($e.blockNumber,$e.blockHash,$e.exportHash,$e.manifestHash,$e.manifestURI)
    $event=Scenario-Event $receipt executor StateExportPublished
    $latest=Read-Scenario executor latestStateExport
    if ($event.exportHash -ne $e.exportHash -or $latest[2] -ne $e.exportHash -or $latest[1] -ne $e.blockHash) {throw 'Published export readback differs from the snapshot claim.'}
    $script:state.export.published=$true;Save-ScenarioState
}

function New-ScenarioClientConfig {
    $public=[ordered]@{}
    foreach ($name in @('core','manager','nativeSale','erc20Sale','auction','artistRegistry','entropy','splitFactory','primaryRevenue','assetPolicy','executor')) {$public[$name]=$addresses[$name]}
    return [ordered]@{schemaVersion=1;chainId='31337';addresses=$public}
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
    $script:state.addresses=$addresses
    $config=New-ScenarioClientConfig
    [IO.File]::WriteAllText((Join-Path $OutputDirectory 'client-config.json'),($config | ConvertTo-Json -Depth 8)+"`n",[Text.UTF8Encoding]::new($false))
    if ($Stage -in @('Onboard','All')) {Invoke-ScenarioOnboarding}
    if ($Stage -in @('Native','All')) {Invoke-ScenarioNative}
    if ($Stage -in @('ERC20','All')) {Invoke-ScenarioERC20}
    if ($Stage -in @('Auction','All')) {Invoke-ScenarioAuction}
    if ($Stage -in @('Export','All')) {Invoke-ScenarioExport}
    Save-ScenarioState
    Write-Output $statePath
} finally {$lock.Dispose()}
