# Read and reconcile the existing demo. Definitions only; no signer or credential access.
function Restore-SubscriptionCreated([object]$Receipt) {
    $topic=Cast @('keccak','SubscriptionCreated(uint256,address)')
    $events=@($Receipt.logs | Where-Object {$_.address -ieq $coordinator -and $_.topics.Count -eq 2 -and $_.topics[0] -eq $topic})
    if ($events.Count -ne 1) {throw 'Subscription creation has an invalid event.'}
    $owner=(Cast @('abi-decode','f()(address)',$events[0].data,'--json')) | ConvertFrom-Json -NoEnumerate
    if ($owner[0] -ine $deployer.address) {throw 'Subscription was created for another owner.'}
    $subscriptionId=(Uint $events[0].topics[1]).ToString()
    if ($state.Contains('subscriptionId') -and $state.subscriptionId -ne $subscriptionId) {throw 'Recovered subscription differs from checkpoint.'}
    $state.subscriptionId=$subscriptionId
    Save-State
}

function Get-LaunchStatus {
    if ($state.schema -ne '6529stream.current-sepolia.v1' -or $state.chainId -ne 11155111) {throw 'Incompatible Sepolia checkpoint.'}
    if ((Uint (Rpc 'eth_chainId')) -ne 11155111) {throw 'Sepolia RPC required.'}
    $result=[ordered]@{schema='6529stream.launch-status.v1';chainId=11155111;transactions=[ordered]@{};nextActions=@()}
    if ($state.Contains('accounts')) {
        $sender=$state.accounts.deployer
        $result.deployer=$sender
        $result.balanceWei=(Uint (Rpc 'eth_getBalance' @($sender,'latest'))).ToString()
        $result.confirmedNonce=(Uint (Rpc 'eth_getTransactionCount' @($sender,'latest'))).ToString()
        $result.pendingNonce=(Uint (Rpc 'eth_getTransactionCount' @($sender,'pending'))).ToString()
    }
    if ($state.Contains('transactionIntents')) {
        foreach ($entry in $state.transactionIntents.GetEnumerator()) {
            $intent=$entry.Value
            $receipt=Rpc 'eth_getTransactionReceipt' @($intent.transactionHash)
            $transaction=Rpc 'eth_getTransactionByHash' @($intent.transactionHash)
            $observed='unobserved'
            if ($null -ne $transaction) {
                Assert-TransactionEnvelope $intent $transaction
                $observed='pending'
            }
            if ($null -ne $receipt) {
                $block=Rpc 'eth_getBlockByNumber' @($receipt.blockNumber,'false')
                Assert-ReceiptInclusion $entry.Key $intent $transaction $receipt $block
                $observed=if ($receipt.status -in @('0x1','1',1)) {'confirmed'} else {'reverted'}
            }
            $result.transactions[$entry.Key]=@{hash=$intent.transactionHash;observed=$observed;checkpoint=$intent.status}
        }
    }
    if ($state.Contains('subscriptionId')) {
        $subscription=Read $coordinator 'getSubscription(uint256)(uint96,uint96,uint64,address,address[])' @($state.subscriptionId)
        $result.subscription=@{id=$state.subscriptionId;nativeBalanceWei=[string]$subscription[1];owner=$subscription[3];consumers=$subscription[4]}
    }
    if (-not $state.Contains('addresses')) {
        $result.nextActions+=if ($state.Contains('deploymentAttempt')) {'ResumeDeploy'} else {'Subscription then Deploy'}
        return $result
    }
    $result.addresses=$state.addresses
    if (-not $state.Contains('activated') -or -not $state.activated) {$result.nextActions+='Activate'}
    if (-not $state.Contains('tokenId')) {
        $result.nextActions+='Mint (recover a recorded paidMint intent first, if present)'
        return $result
    }
    $tokenId=[string]$state.tokenId
    $entropyAddress=(Read $state.addresses.core 'coordinatorAtMint(uint256)(address)' @($tokenId))[0]
    $entropy=Read $entropyAddress 'tokenEntropy(uint256)(uint8,bytes32,address,uint32,bytes32,bytes32,uint256,uint16)' @($tokenId)
    $names=@('NONE','DISABLED','NOT_REQUIRED','REGISTERED','REQUESTED','FINALIZED','STALE','FAILED')
    $number=[int](Uint $entropy[0])
    if ($number -lt 0 -or $number -ge $names.Count) {throw 'Unexpected entropy status.'}
    $notificationResult=Read $entropyAddress 'metadataNotificationPending(uint256)(bool)' @($tokenId)
    $notification=[bool]$notificationResult[0]
    $result.token=@{id=$tokenId;owner=(Read $state.addresses.core 'ownerOf(uint256)(address)' @($tokenId))[0]
        entropyCoordinator=$entropyAddress;entropyStatus=$names[$number];metadataNotificationPending=$notification}
    if ($number -eq 3) {$result.nextActions+='RequestEntropy'}
    if ((Uint $entropy[6]) -ne 0) {
        $provider=Read $entropy[2] 'providerResultStatus(uint256)(uint8,bytes32,bytes32,bool,bool)' @([string]$entropy[6])
        if ($provider[1] -ine $entropy[5]) {throw 'Provider result does not belong to the token request.'}
        $providerNames=@('UNKNOWN','REQUESTED','RAW_RANDOMNESS_RECEIVED','DELIVERED','TERMINAL_STALE','TERMINAL_FAILED')
        $providerNumber=[int](Uint $provider[0])
        if ($providerNumber -lt 0 -or $providerNumber -ge $providerNames.Count) {throw 'Unexpected provider status.'}
        $result.token.provider=@{address=$entropy[2];requestId=[string]$entropy[6];requestKey=$entropy[5];status=$providerNames[$providerNumber]}
        if ($providerNumber -eq 1) {$result.nextActions+='Wait for Chainlink fulfilment; inspect subscription funding'}
        if ($providerNumber -eq 2) {$result.nextActions+='RetryEntropyDelivery'}
    }
    if ($notification) {$result.nextActions+='RetryMetadataNotification'}
    if ($number -eq 5 -and (-not $state.Contains('demonstrated') -or -not $state.demonstrated)) {$result.nextActions+='Readback then Settle'}
    if ($number -in @(6,7)) {$result.nextActions+='Inspect terminal entropy state; this runner does not request another random draw'}
    $result.demonstrationRecorded=($state.Contains('demonstrated') -and [bool]$state.demonstrated)
    if ($result.demonstrationRecorded) {$result.nextActions+='Demonstration recorded; use Readback for current chain observations'}
    return $result
}

function Restore-MintSettlement([object]$Receipt) {
    $token=Mint-TokenId $Receipt $state.addresses.sale
    $topic=Cast @('keccak','NativeSaleSettled(bytes32,bytes32,uint256,bytes32,bytes32,address,uint256)')
    $event=@($Receipt.logs | Where-Object {$_.address -ieq $state.addresses.sale -and $_.topics[0] -eq $topic})[0]
    $fields=(Cast @('abi-decode','f()(bytes32,bytes32,address,uint256)',$event.data,'--json')) | ConvertFrom-Json
    $wallet=(Read $state.addresses.factory 'walletFor(bytes32)(address)' @($fields[1]))[0]
    if ($wallet -ine $fields[2] -or (Uint $fields[3]) -le 0) {throw 'Paid mint settlement has an unexpected wallet or amount.'}
    if ($state.Contains('tokenId') -and [string]$state.tokenId -ne $token) {throw 'Paid mint receipt differs from the recorded token.'}
    $state.tokenId=$token
    $state.wallet=$wallet
    $state.mintPriceWei=(Uint $fields[3]).ToString()
    Save-State
}

function Restore-EntropyRequest([object]$Receipt) {
    $topic=Cast @('keccak','VRFEntropyRequested(uint16,bytes32,uint256,uint256,uint32,bytes32,uint16,uint32,uint32)')
    $events=@($Receipt.logs | Where-Object {$_.address -ieq $state.addresses.provider -and $_.topics.Count -eq 4 -and $_.topics[0] -eq $topic})
    if ($events.Count -ne 1) {throw 'Expected one VRF provider request event.'}
    if ((Uint $events[0].topics[3]) -ne (Uint $state.subscriptionId)) {throw 'VRF receipt belongs to another subscription.'}
    $requestId=(Uint $events[0].topics[2]).ToString()
    $token=Read $state.addresses.entropy 'tokenEntropy(uint256)(uint8,bytes32,address,uint32,bytes32,bytes32,uint256,uint16)' @([string]$state.tokenId)
    if ($token[2] -ine $state.addresses.provider -or $token[5] -ine $events[0].topics[1] -or [string]$token[6] -ne $requestId) {
        throw 'VRF receipt does not match the token-bound entropy request.'
    }
    $state.providerRequestId=$requestId
    $state.requestKey=$events[0].topics[1]
    $state.entropyRequested=$true
    Save-State
}
