# Restartable Sepolia transactions. Definitions only; loading this file performs no I/O.
# Operational checkpoints contain signed call arguments and must remain local.
function Initialize-TransactionJournal {
    if (-not $state.Contains('transactionIntents')) {$state.transactionIntents=[ordered]@{}}
}

function Assert-TransactionEnvelope([object]$Intent,[object]$Transaction) {
    $sender=if ($Transaction.Contains('signer')) {$Transaction.signer} else {$Transaction.from}
    foreach ($name in @('chainId','nonce','gas','value','maxFeePerGas','maxPriorityFeePerGas')) {
        if (-not $Transaction.Contains($name) -or (Uint $Transaction[$name]) -ne (Uint $Intent[$name])) {
            throw "Recorded transaction $name differs from its prepared intent."
        }
    }
    if ((Uint $Transaction.type) -ne 2 -or $sender -ine $Intent.from -or
        $Transaction.to -ine $Intent.to -or $Transaction.input -ine $Intent.input -or
        @($Transaction.accessList).Count -ne 0) {
        throw 'Recorded transaction sender, destination, calldata or envelope differs from its intent.'
    }
    if ($Intent.Contains('transactionHash') -and $Transaction.hash -ine $Intent.transactionHash) {
        throw 'Recorded transaction hash differs from its intent.'
    }
}

function Assert-ReceiptInclusion([string]$Label,[object]$Intent,[object]$transaction,[object]$receipt,[object]$block) {
    if ($null -eq $transaction) {throw "Receipt transaction unavailable for $Label; retain the checkpoint and retry."}
    Assert-TransactionEnvelope $Intent $transaction
    $index=Uint $receipt.transactionIndex
    if ($null -eq $block -or $block.hash -ine $receipt.blockHash -or
        $transaction.blockHash -ine $receipt.blockHash -or
        (Uint $block.number) -ne (Uint $receipt.blockNumber) -or
        (Uint $transaction.blockNumber) -ne (Uint $receipt.blockNumber) -or
        (Uint $transaction.transactionIndex) -ne $index -or $index -lt 0 -or $index -ge @($block.transactions).Count -or
        $block.transactions[[int]$index] -ine $Intent.transactionHash -or
        $receipt.transactionHash -ine $Intent.transactionHash -or
        $receipt.from -ine $Intent.from -or $receipt.to -ine $Intent.to) {
        throw "Receipt for $Label is not bound to its canonical transaction."
    }
    if ($receipt.status -notin @('0x0','0','0x1','1',0,1)) {throw "Receipt for $Label has an invalid status."}
}

function Get-IntentReceipt([string]$Label,[object]$Intent) {
    $receipt=Rpc 'eth_getTransactionReceipt' @($Intent.transactionHash)
    if ($null -eq $receipt) {return $null}
    $transaction=Rpc 'eth_getTransactionByHash' @($Intent.transactionHash)
    $block=Rpc 'eth_getBlockByNumber' @($receipt.blockNumber,'false')
    Assert-ReceiptInclusion $Label $Intent $transaction $receipt $block
    $Intent.receiptStatus=[string]$receipt.status
    $Intent.receiptBlockHash=$receipt.blockHash
    if ($receipt.status -notin @('0x1','1',1)) {
        $Intent.status='reverted'
        Save-State
        throw "Transaction reverted: $Label ($($Intent.transactionHash)). It will not be sent again."
    }
    $Intent.status='confirmed'
    Record-Receipt $Label $receipt
    return $receipt
}

function New-SignedIntent([object]$Intent) {
    $raw=With-Signer $deployer 'cast' @(
        'mktx',$Intent.to,$Intent.input,'--from',$Intent.from,'--chain',$Intent.chainId,
        '--nonce',$Intent.nonce,'--value',$Intent.value,'--gas-limit',$Intent.gas,
        '--gas-price',$Intent.maxFeePerGas,'--priority-gas-price',$Intent.maxPriorityFeePerGas,
        '--rpc-url',$RpcUrl
    )
    if ($raw -notmatch '^0x02[0-9a-fA-F]+$') {throw 'Signer did not return a type-2 transaction.'}
    # Read raw signed bytes through stdin; they never enter durable state or command arguments.
    $decoded=(Invoke-Tool 'cast' @('decode-transaction') $raw) | ConvertFrom-Json -AsHashtable
    if ($decoded -is [string]) {$decoded=$decoded | ConvertFrom-Json -AsHashtable}
    Assert-TransactionEnvelope $Intent $decoded
    $hash=Cast @('keccak',$raw)
    if ($decoded.hash -ine $hash -or ($Intent.Contains('transactionHash') -and $Intent.transactionHash -ine $hash)) {
        throw 'Signer did not reproduce the prepared transaction hash.'
    }
    return @{raw=$raw;hash=$hash}
}

function Complete-Intent([string]$Label,[object]$Intent) {
    if ($Intent.chainId -ne '11155111' -or $Intent.from -ine $deployer.address) {
        throw 'Prepared intent belongs to another chain or deployer.'
    }
    $receipt=Get-IntentReceipt $Label $Intent
    if ($null -ne $receipt) {return $receipt}
    if ($Intent.status -in @('confirmed','reverted')) {
        throw "Previously mined transaction $Label is currently unavailable; reconcile its chain inclusion."
    }
    $pending=Rpc 'eth_getTransactionByHash' @($Intent.transactionHash)
    if ($null -ne $pending) {
        Assert-TransactionEnvelope $Intent $pending
    } else {
        $confirmedNonce=Uint (Rpc 'eth_getTransactionCount' @($deployer.address,'latest'))
        $pendingNonce=Uint (Rpc 'eth_getTransactionCount' @($deployer.address,'pending'))
        if ($confirmedNonce -ne (Uint $Intent.nonce) -or $pendingNonce -ne $confirmedNonce) {
            throw "Transaction $Label is unknown or replaced at its reserved nonce; no replacement was sent."
        }
        if (-not $Broadcast) {throw "Prepared transaction $Label has not been observed onchain. Use its original stage with -Broadcast to resume."}
        $signed=New-SignedIntent $Intent
        try {
            # State was durably saved before publication. An uncertain RPC outcome preserves this hash.
            $parameters=ConvertTo-Json -InputObject @($signed.raw) -Compress
            $published=(Invoke-Tool 'cast' @('rpc','eth_sendRawTransaction','--raw','--rpc-url',$RpcUrl) $parameters) | ConvertFrom-Json
            if ($published -ine $Intent.transactionHash) {throw 'RPC returned a different transaction hash.'}
            $Intent.status='submitted'
            Save-State
        } finally {$parameters=$null;$signed.raw=$null;$signed=$null}
    }
    $until=[DateTime]::UtcNow.AddSeconds($ReceiptWaitSeconds)
    do {
        $receipt=Get-IntentReceipt $Label $Intent
        if ($null -ne $receipt) {return $receipt}
        if ([DateTime]::UtcNow -ge $until) {break}
        Start-Sleep -Milliseconds 750
    } while ($true)
    throw "Transaction $Label is pending ($($Intent.transactionHash)). Rerun the same stage to recover it."
}

function Resume-RecordedTransaction([string]$Label) {
    Initialize-TransactionJournal
    if (-not $state.transactionIntents.Contains($Label)) {return $null}
    return Complete-Intent $Label $state.transactionIntents[$Label]
}

function Import-HistoricalIntent([string]$Label,[string]$Target,[string]$Signature) {
    Initialize-TransactionJournal
    if ($state.transactionIntents.Contains($Label) -or -not $state.receipts.Contains($Label)) {return}
    $hash=$state.receipts[$Label].transactionHash
    $tx=Rpc 'eth_getTransactionByHash' @($hash)
    if ($null -eq $tx) {throw "Historical transaction $Label is unavailable."}
    $selector=Cast @('sig',$Signature)
    if ($tx.hash -ine $hash -or $tx.from -ine $deployer.address -or $tx.to -ine $Target -or
        (Uint $tx.chainId) -ne 11155111 -or -not $tx.input.StartsWith($selector,[StringComparison]::OrdinalIgnoreCase)) {
        throw "Historical transaction $Label does not belong to its launch stage."
    }
    $state.transactionIntents[$Label]=[ordered]@{from=$tx.from;to=$tx.to;input=$tx.input;chainId='11155111';nonce=(Uint $tx.nonce).ToString()
        value=(Uint $tx.value).ToString();gas=(Uint $tx.gas).ToString();maxFeePerGas=(Uint $tx.maxFeePerGas).ToString()
        maxPriorityFeePerGas=(Uint $tx.maxPriorityFeePerGas).ToString();transactionHash=$tx.hash;status='confirmed'}
}

function Send-JournaledTransaction(
    [string]$Label,[string]$Target,[string]$Signature,[string[]]$Arguments=@(),[string]$Value='0',[long]$GasLimit=0
) {
    Initialize-TransactionJournal
    $inputData=Cast (@('calldata',$Signature)+$Arguments)
    if ($state.transactionIntents.Contains($Label)) {
        $intent=$state.transactionIntents[$Label]
        if ($intent.to -ine $Target -or $intent.input -ine $inputData -or (Uint $intent.value) -ne (Uint $Value)) {
            throw "Stage $Label already has different prepared arguments. Resume its recorded transaction first."
        }
        return Complete-Intent $Label $intent
    }
    if ($state.receipts.Contains($Label)) {
        # Upgrade earlier successful checkpoints using the actual chain transaction, never just a local flag.
        $tx=Rpc 'eth_getTransactionByHash' @($state.receipts[$Label].transactionHash)
        if ($null -eq $tx) {throw "Historical transaction $Label is unavailable."}
        if ($tx.from -ine $deployer.address -or $tx.to -ine $Target -or $tx.input -ine $inputData -or
            (Uint $tx.value) -ne (Uint $Value) -or (Uint $tx.chainId) -ne 11155111) {
            throw "Historical transaction $Label differs from the requested stage."
        }
        $intent=[ordered]@{from=$tx.from;to=$tx.to;input=$tx.input;chainId='11155111';nonce=(Uint $tx.nonce).ToString()
            value=(Uint $tx.value).ToString();gas=(Uint $tx.gas).ToString();maxFeePerGas=(Uint $tx.maxFeePerGas).ToString()
            maxPriorityFeePerGas=(Uint $tx.maxPriorityFeePerGas).ToString();transactionHash=$tx.hash;status='confirmed'}
        $state.transactionIntents[$Label]=$intent
        return Complete-Intent $Label $intent
    }
    if (-not $Broadcast) {throw 'A new transaction requires -Broadcast.'}
    foreach ($entry in $state.transactionIntents.GetEnumerator()) {
        if ($entry.Value.status -notin @('confirmed','reverted')) {
            throw "Stage $($entry.Key) has an unresolved transaction. Recover it before preparing $Label."
        }
    }
    $nonce=Uint (Rpc 'eth_getTransactionCount' @($deployer.address,'latest'))
    foreach ($prior in $state.transactionIntents.Values) {
        if ((Uint $prior.nonce) -ge $nonce) {throw 'Confirmed nonce regressed behind the checkpoint; reconcile chain inclusion before another send.'}
    }
    if ((Uint (Rpc 'eth_getTransactionCount' @($deployer.address,'pending'))) -ne $nonce) {
        throw 'Deployer has a pending transaction; recover it before preparing another stage.'
    }
    if ($GasLimit -ne 0) {$limit=[bigint]$GasLimit}
    else {
        $estimate=Uint (Cast (@('estimate',$Target,$Signature)+$Arguments+@('--from',$deployer.address,'--rpc-url',$RpcUrl,'--value',$Value)))
        $limit=[bigint]::Max(21000,[bigint]::Divide(($estimate*120+99),100))
    }
    if ($limit -lt 21000 -or $limit -gt $transactionGasCap) {throw "$Label gas allocation is below intrinsic gas or exceeds the transaction cap."}
    $balance=Uint (Cast @('balance',$deployer.address,'--rpc-url',$RpcUrl))
    if ($balance -lt $limit*$maxFee+(Uint $Value)) {throw "Insufficient balance for $Label."}
    $intent=[ordered]@{from=$deployer.address;to=$Target;input=$inputData;chainId='11155111';nonce=$nonce.ToString()
        value=(Uint $Value).ToString();gas=$limit.ToString();maxFeePerGas=$maxFee.ToString()
        maxPriorityFeePerGas=$tip.ToString();status='prepared'}
    $signed=New-SignedIntent $intent
    try {
        $intent.transactionHash=$signed.hash
        $state.transactionIntents[$Label]=$intent
        Save-State
    } finally {$signed.raw=$null;$signed=$null}
    return Complete-Intent $Label $intent
}
