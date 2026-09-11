# Independent pure status/hydration/stage-order regressions. No live RPC or signer access.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'current-stack-transaction-journal.ps1')
. (Join-Path $PSScriptRoot 'current-stack-launch-status.ps1')
$tokens=$null;$errors=$null
$mainAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'run-current-stack-sepolia.ps1'),[ref]$tokens,[ref]$errors)
if ($errors.Count) {throw 'Main runner must parse.'}
foreach ($definition in $mainAst.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$true)) {
    if ($definition.Name -in @('Uint','Mint-TokenId','Require-Addresses')) {Invoke-Expression $definition.Extent.Text}
}
$script:passed=0;$script:failures=[Collections.Generic.List[string]]::new()
function Check([bool]$Condition,[string]$Message) {if (-not $Condition) {throw $Message}}
function Reject([scriptblock]$Action,[string]$Message='') {
    $failure=$null;try {& $Action | Out-Null} catch {$failure=$_.Exception.Message}
    Check ($null -ne $failure) "Expected rejection: $Message"
    if ($Message) {Check ($failure -like "*$Message*") "Unexpected rejection '$failure'; expected '$Message'."}
}
function Copy-Value([object]$Value) {return ($Value | ConvertTo-Json -Depth 30 -Compress | ConvertFrom-Json -AsHashtable)}
function Reset-Fixture {
    $script:state=[ordered]@{schema='6529stream.current-sepolia.v1';chainId=11155111;receipts=[ordered]@{}}
    $script:deployer=@{address='0x1111111111111111111111111111111111111111'}
    $script:artist=@{address='0x2222222222222222222222222222222222222222'}
    $script:platform=@{address='0x3333333333333333333333333333333333333333'}
    $script:coordinator='0x4444444444444444444444444444444444444444'
    $script:core='0x5555555555555555555555555555555555555555'
    $script:boundEntropy='0x6666666666666666666666666666666666666666'
    $script:provider='0x7777777777777777777777777777777777777777'
    $script:sale='0x8888888888888888888888888888888888888888'
    $script:factory='0x9999999999999999999999999999999999999999'
    $script:wallet='0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    $script:hash='0x'+('ab'*32);$script:blockHash='0x'+('cd'*32);$script:profile='0x'+('ef'*32)
    $script:zero='0x'+('0'*64)
    $script:notifications=$false
    $script:token=@(3,$script:zero,$script:provider,1,$script:hash,$script:zero,'0',0)
    $script:providerResult=@(1,$script:hash,$script:zero,$false,$false)
    $script:owner=$script:deployer.address
    $script:chain='0xaa36a7'
    $script:rpcReceipt=$null;$script:rpcTransaction=$null
    $script:rpcBlock=@{number='0x100';hash=$script:blockHash;transactions=@($script:hash)}
    $script:saveCount=0;$script:signCount=0;$script:sendCount=0
    $script:resumed=[Collections.Generic.List[string]]::new()
    $script:resumeReceipts=@{}
    $script:events=[Collections.Generic.List[string]]::new()
    $script:MintPriceWei='1000';$script:latest=@{timestamp='100'}
    $script:subscription=@('0','1200000000000000000','0',$script:deployer.address,@($script:provider))
    $script:topics=@{
        'SubscriptionCreated(uint256,address)'='0x'+('10'*32)
        'NativeSaleSettled(bytes32,bytes32,uint256,bytes32,bytes32,address,uint256)'='0x'+('20'*32)
        'VRFEntropyRequested(uint16,bytes32,uint256,uint256,uint32,bytes32,uint16,uint32,uint32)'='0x'+('30'*32)
    }
    $script:subscriptionOwner=$script:deployer.address
}
function With-Addresses {
    $script:state.addresses=@{core=$script:core;entropy=$script:boundEntropy;provider=$script:provider;sale=$script:sale
        factory=$script:factory;manager=$script:core;artists=$script:core}
    $script:state.activated=$true
}
function With-Token {
    With-Addresses;$script:state.tokenId='42';$script:state.subscriptionId='9'
}
function Save-State {$script:saveCount++;$script:events.Add('save')}
function Cast([string[]]$Arguments) {
    if ($Arguments[0] -eq 'keccak') {
        if ($script:topics.ContainsKey($Arguments[1])) {return $script:topics[$Arguments[1]]}
        return $script:hash
    }
    if ($Arguments[0] -eq 'sig') {return '0x12345678'}
    if ($Arguments[0] -eq 'abi-decode') {
        switch ($Arguments[1]) {
            'f()(address)' {return '["'+$script:subscriptionOwner+'"]'}
            'f()(bytes32,bytes32,address,uint256)' {return '["'+$script:hash+'","'+$script:profile+'","'+$script:wallet+'",1000]'}
        }
    }
    throw "Unexpected Cast $($Arguments -join ' ')"
}
function Read([string]$Target,[string]$Signature,[string[]]$Arguments=@()) {
    if ($Signature -like 'getSubscription*') {return ,$script:subscription}
    if ($Signature -like 'coordinatorAtMint*') {Check ($Target -eq $script:core) 'Wrong Core for coordinator lookup.';return ,@($script:boundEntropy)}
    if ($Signature -like 'tokenEntropy(*') {Check ($Target -eq $script:boundEntropy) 'Did not use token-bound coordinator.';return ,$script:token}
    if ($Signature -like 'metadataNotificationPending*') {Check ($Target -eq $script:boundEntropy) 'Wrong notification coordinator.';return ,@($script:notifications)}
    if ($Signature -like 'providerResultStatus*') {Check ($Target -eq $script:provider) 'Wrong token-bound provider.';return ,$script:providerResult}
    if ($Signature -like 'ownerOf*') {return ,@($script:owner)}
    if ($Signature -like 'walletFor*') {return ,@($script:wallet)}
    if ($Signature -like 'profileIdFor*') {return ,@($script:profile)}
    if ($Signature -like 'phasePolicyHash*') {return ,@($script:hash)}
    if ($Signature -like 'signerEpoch*') {return ,@('1')}
    throw "Unexpected Read $Signature"
}
function Rpc([string]$Method,[string[]]$Arguments=@()) {
    switch ($Method) {
        'eth_chainId' {return $script:chain}
        'eth_getBalance' {return '0x20000000000001'}
        'eth_getTransactionCount' {return '0x7'}
        'eth_getTransactionReceipt' {return $script:rpcReceipt}
        'eth_getTransactionByHash' {return $script:rpcTransaction}
        'eth_getBlockByNumber' {return $script:rpcBlock}
        default {throw "Unexpected RPC $Method"}
    }
}
function Sign-Typed([object]$Account,[object]$Data) {$script:signCount++;$script:events.Add('sign');return '0x1234'}
function With-Signer {throw 'No signer/credential access permitted in these tests.'}
function Send { $script:sendCount++;throw 'Unexpected fresh send during recovery/guard regression.' }
function Resume-RecordedTransaction([string]$Label) {
    $script:resumed.Add($Label);$script:events.Add("resume:$Label")
    if ($script:resumeReceipts.ContainsKey($Label)) {return $script:resumeReceipts[$Label]}
    return $null
}
function Valid-SubscriptionReceipt {
    return @{logs=@(@{address=$script:coordinator;topics=@($script:topics['SubscriptionCreated(uint256,address)'],'0x9');data='0x01'})}
}
function Valid-MintReceipt {
    return @{logs=@(@{address=$script:sale;topics=@($script:topics['NativeSaleSettled(bytes32,bytes32,uint256,bytes32,bytes32,address,uint256)'],$script:hash,$script:hash,'0x2a');data='0x02'})}
}
function Valid-RequestReceipt {
    return @{logs=@(@{address=$script:provider;topics=@($script:topics['VRFEntropyRequested(uint16,bytes32,uint256,uint256,uint32,bytes32,uint16,uint32,uint32)'],$script:hash,'0x11','0x9');data='0x03'})}
}
function With-IntentReceipt {
    $intent=@{chainId='11155111';from=$script:deployer.address;to=$script:sale;nonce='7';gas='36000';value='0'
        maxFeePerGas='100';maxPriorityFeePerGas='10';input='0x1234';transactionHash=$script:hash;status='prepared'}
    $script:state.transactionIntents=[ordered]@{operation=$intent}
    $script:rpcTransaction=@{type='0x2';chainId='11155111';from=$script:deployer.address;to=$script:sale;nonce='7';gas='36000';value='0'
        maxFeePerGas='100';maxPriorityFeePerGas='10';input='0x1234';accessList=@();hash=$script:hash
        blockHash=$script:blockHash;blockNumber='0x100';transactionIndex='0x0'}
    $script:rpcReceipt=@{from=$script:deployer.address;to=$script:sale;transactionHash=$script:hash;blockHash=$script:blockHash
        blockNumber='0x100';transactionIndex='0x0';status='0x1';gasUsed='0x7530';effectiveGasPrice='0x32'}
}
function Assert-NotConfirmed {
    $result=$null
    try {$result=Get-LaunchStatus} catch {return}
    Check ($result.transactions.operation.observed -ne 'confirmed') 'Unbound receipt was reported confirmed.'
    Check ($script:saveCount -eq 0) 'Status wrote a checkpoint.'
}
function Run-RecoveryPrelude {
    # Execute exact main-runner AST extents rather than a copied ordering model.
    Initialize-TransactionJournal
    $assignment=@($mainAst.FindAll({param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -in @('$stageLabels','$allRecordedLabels','$recordedLabels')},$true))
    $loop=@($mainAst.FindAll({param($n) $n -is [Management.Automation.Language.ForEachStatementAst] -and $n.Variable.VariablePath.UserPath -eq 'label'},$true))
    Check ($assignment.Count -eq 3 -and $loop.Count -eq 1) 'Recovery source boundary changed; review the test extraction.'
    foreach ($step in @($assignment | Sort-Object {$_.Extent.StartOffset})) {Invoke-Expression $step.Extent.Text}
    Invoke-Expression $loop[0].Extent.Text
}
function Run-MintFragment {
    $matches=@($mainAst.FindAll({param($n) $n -is [Management.Automation.Language.IfStatementAst] -and $n.Clauses[0].Item1.Extent.Text -eq '$Stage -eq ''Mint'''},$true))
    Check ($matches.Count -eq 1) 'Mint source boundary changed; review the test extraction.'
    Invoke-Expression $matches[0].Extent.Text
}
function Test-Case([string]$Name,[scriptblock]$Action) {
    Reset-Fixture
    try {& $Action;$script:passed++;Write-Output "PASS: $Name"}
    catch {$script:failures.Add("${Name}: $($_.Exception.Message)");Write-Output "FAIL: ${Name}: $($_.Exception.Message)"}
}

Test-Case 'empty status is read-only and needs no account metadata' {
    $before=$script:state | ConvertTo-Json -Depth 20 -Compress
    $result=Get-LaunchStatus
    Check ($result.nextActions -contains 'Subscription then Deploy') 'Wrong initial next action.'
    Check (($script:state | ConvertTo-Json -Depth 20 -Compress) -eq $before -and $script:saveCount -eq 0) 'Status mutated state.'
}
Test-Case 'account observations preserve bigint values as decimal strings' {
    $script:state.accounts=@{deployer=$script:deployer.address}
    $result=Get-LaunchStatus
    Check ($result.balanceWei -ceq '9007199254740993') 'Balance lost integer precision.'
    Check ($script:saveCount -eq 0) 'Read-only account status saved state.'
}
Test-Case 'registered token with actual false bool recommends request, not retry' {
    With-Token;$script:notifications=$false
    $result=Get-LaunchStatus
    Check ($result.token.metadataNotificationPending -eq $false) 'False was converted to true.'
    Check ($result.nextActions -contains 'RequestEntropy') 'Registered token needs initial request.'
    Check ($result.nextActions -notcontains 'RetryMetadataNotification') 'False notification prompted retry.'
}
Test-Case 'retained raw randomness recommends delivery retry only' {
    With-Token;$script:token[0]=4;$script:token[5]=$script:hash;$script:token[6]='17';$script:providerResult[0]=2
    $result=Get-LaunchStatus
    Check ($result.nextActions -contains 'RetryEntropyDelivery' -and $result.nextActions -notcontains 'RequestEntropy') 'Retry suggested a new random draw.'
}
Test-Case 'requested provider recommends waiting, not redrawing' {
    With-Token;$script:token[0]=4;$script:token[5]=$script:hash;$script:token[6]='17'
    $result=Get-LaunchStatus
    Check (@($result.nextActions | Where-Object {$_ -like 'Wait for Chainlink*'}).Count -eq 1) 'No pending-provider guidance.'
    Check ($result.nextActions -notcontains 'RequestEntropy') 'Pending request was offered another draw.'
}
Test-Case 'terminal entropy does not offer another random draw' {
    With-Token;$script:token[0]=6
    $result=Get-LaunchStatus
    Check (@($result.nextActions | Where-Object {$_ -like 'Inspect terminal*'}).Count -eq 1) 'Terminal boundary not explained.'
    Check ($result.nextActions -notcontains 'RequestEntropy') 'Terminal token was offered another draw.'
}
Test-Case 'provider mismatch fails before status can recommend retry' {
    With-Token;$script:token[0]=4;$script:token[5]=$script:hash;$script:token[6]='17';$script:providerResult[1]=$script:zero
    Reject {Get-LaunchStatus} 'does not belong'
}
Test-Case 'wrong RPC chain rejects status' {$script:chain='0x1';Reject {Get-LaunchStatus} 'Sepolia RPC'}
Test-Case 'wrong checkpoint chain rejects status' {$script:state.chainId=31337;Reject {Get-LaunchStatus} ''}
Test-Case 'successful canonical transaction status is read-only' {
    With-IntentReceipt
    $result=Get-LaunchStatus
    Check ($result.transactions.operation.observed -eq 'confirmed') 'Valid transaction was not recognized.'
    Check ($script:state.transactionIntents.operation.status -eq 'prepared' -and $script:saveCount -eq 0) 'Status persisted confirmation.'
}
Test-Case 'status cannot confirm a receipt whose transaction is unavailable' {With-IntentReceipt;$script:rpcTransaction=$null;Assert-NotConfirmed}
foreach ($field in @('transactionHash','from','to','blockNumber','transactionIndex')) {
    Test-Case "status rejects changed receipt $field" {
        With-IntentReceipt
        $script:rpcReceipt[$field]=if ($field -in @('blockNumber','transactionIndex')) {'0x2'} else {'0x'+('99'*32)}
        Assert-NotConfirmed
    }
}
Test-Case 'status rejects changed canonical block membership' {With-IntentReceipt;$script:rpcBlock.transactions=@('0x'+('99'*32));Assert-NotConfirmed}
Test-Case 'historical demonstrated flag does not hide current pending recovery' {
    With-Token;$script:state.demonstrated=$true;$script:notifications=$true
    $result=Get-LaunchStatus
    Check ($result.nextActions -contains 'RetryMetadataNotification') 'Historical completion hid a live pending notification.'
}
Test-Case 'subscription owner decodes from the actual single-element JSON array' {
    Restore-SubscriptionCreated (Valid-SubscriptionReceipt)
    Check ($script:state.subscriptionId -eq '9' -and $script:saveCount -eq 1) 'Valid owner was not restored.'
}
Test-Case 'wrong subscription owner cannot mutate checkpoint' {
    $script:subscriptionOwner=$script:artist.address
    Reject {Restore-SubscriptionCreated (Valid-SubscriptionReceipt)} 'another owner'
    Check ($script:saveCount -eq 0) 'Wrong owner was persisted.'
}
Test-Case 'subscription event requires exact configured coordinator and two topics' {
    $receipt=Valid-SubscriptionReceipt;$receipt.logs[0].topics+=@($script:zero)
    Reject {Restore-SubscriptionCreated $receipt} 'invalid event'
    Check ($script:saveCount -eq 0) 'Malformed creation event was persisted.'
}
Test-Case 'paid mint receipt rehydrates token, profile wallet and price' {
    With-Addresses
    Restore-MintSettlement (Valid-MintReceipt)
    Check ($script:state.tokenId -eq '42' -and $script:state.wallet -eq $script:wallet -and $script:state.mintPriceWei -eq '1000') 'Mint hydration differs from receipt.'
}
Test-Case 'VRF request receipt requires token, request and subscription binding' {
    With-Token;$script:token[5]=$script:hash;$script:token[6]='17'
    Restore-EntropyRequest (Valid-RequestReceipt)
    Check ($script:state.providerRequestId -eq '17' -and $script:state.entropyRequested -eq $true) 'Request was not restored.'
}
Test-Case 'VRF request from another subscription cannot hydrate' {
    With-Token;$script:token[5]=$script:hash;$script:token[6]='17'
    $receipt=Valid-RequestReceipt;$receipt.logs[0].topics[3]='0xa'
    Reject {Restore-EntropyRequest $receipt} 'another subscription'
    Check ($script:saveCount -eq 0) 'Foreign subscription request was persisted.'
}
Test-Case 'recorded mint intent is restored before fresh authorization' {
    With-Addresses;$script:Stage='Mint';$script:state.transactionIntents=[ordered]@{paidMint=@{}}
    $script:resumeReceipts.paidMint=Valid-MintReceipt
    Run-RecoveryPrelude
    Run-MintFragment
    Check ($script:state.tokenId -eq '42' -and $script:signCount -eq 0 -and $script:sendCount -eq 0) 'Mint recovery created fresh authorization.'
}
Test-Case 'legacy recorded mint receipt is restored before fresh authorization' {
    With-Addresses;With-IntentReceipt;$script:state.transactionIntents=[ordered]@{}
    $script:rpcTransaction.input='0x12345678'
    $script:Stage='Mint';$script:state.receipts.paidMint=@{transactionHash=$script:hash}
    $script:resumeReceipts.paidMint=Valid-MintReceipt
    Run-RecoveryPrelude
    Run-MintFragment
    Check ($script:state.tokenId -eq '42' -and $script:signCount -eq 0 -and $script:sendCount -eq 0) 'Legacy recovery created fresh authorization.'
}
Test-Case 'explicit false activated flag cannot authorize signing a mint' {
    With-Addresses;$script:Stage='Mint';$script:state.activated=$false
    Reject {Run-MintFragment} 'Run Activate first'
    Check ($script:signCount -eq 0 -and $script:sendCount -eq 0) 'False activation reached a wallet prompt.'
}
Write-Output "Launch status regressions: $($script:passed) passed; $($script:failures.Count) failed. All external boundaries stubbed."
if ($script:failures.Count) {throw ($script:failures -join "`n")}