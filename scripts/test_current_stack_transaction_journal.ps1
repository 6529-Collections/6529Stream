# Pure journal regressions: no real RPC, signer, filesystem checkpoint, or publication.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'current-stack-transaction-journal.ps1')
$script:passed=0
$script:failed=[Collections.Generic.List[string]]::new()
function Check([bool]$Condition,[string]$Message) {if (-not $Condition) {throw $Message}}
function Reject([scriptblock]$Action,[string]$Expected) {
    $failure=$null
    try {& $Action | Out-Null} catch {$failure=$_.Exception.Message}
    Check ($null -ne $failure) "Expected rejection: $Expected"
    if ($Expected) {Check ($failure -like "*$Expected*") "Wrong rejection '$failure'; expected '$Expected'."}
}
function Copy-Map([object]$Value) {return ($Value | ConvertTo-Json -Depth 30 -Compress | ConvertFrom-Json -AsHashtable)}
function Uint([string]$Value) {
    if ($Value.StartsWith('0x')) {return [bigint]::Parse(('0'+$Value.Substring(2)),[Globalization.NumberStyles]::AllowHexSpecifier)}
    return [bigint]::Parse($Value)
}
function New-TestTransaction {
    return [ordered]@{type='0x2';chainId='0xaa36a7';from=$script:deployer.address;to=$script:target
        nonce='0x7';gas='0x8ca0';value='0x9';maxFeePerGas='0x64';maxPriorityFeePerGas='0xa'
        input='0x12345678';accessList=@();hash=$script:hash;blockHash=$null;blockNumber=$null;transactionIndex=$null}
}
function New-TestReceipt {
    return [ordered]@{transactionHash=$script:hash;blockNumber='0x100';blockHash=$script:blockHash
        transactionIndex='0x0';from=$script:deployer.address;to=$script:target;status='0x1';gasUsed='0x7530'
        effectiveGasPrice='0x32';logs=@()}
}
function Reset-JournalFixture {
    $script:state=[ordered]@{receipts=[ordered]@{}}
    $script:durable=Copy-Map $script:state
    $script:deployer=@{address='0x1111111111111111111111111111111111111111'}
    $script:target='0x2222222222222222222222222222222222222222'
    $script:hash='0x'+('aa'*32)
    $script:blockHash='0x'+('bb'*32)
    $script:RpcUrl='https://unused.invalid'
    $script:Broadcast=$true
    $script:ReceiptWaitSeconds=0
    $script:transactionGasCap=[bigint]16777216
    $script:maxFee=[bigint]100
    $script:tip=[bigint]10
    $script:latestNonce='0x7'
    $script:pendingNonce='0x7'
    $script:expectedSignedGas='36000'
    $script:estimate='30000'
    $script:balance='1000000000'
    $script:callData='0x12345678'
    $script:saveCount=0
    $script:failSaveAt=0
    $script:signCount=0
    $script:failSignAt=0
    $script:hashDriftAt=0
    $script:publishCount=0
    $script:publishMode='success'
    $script:receiptMode='afterPublish'
    $script:receiptLookupThrows=$false
    $script:txUnavailable=$false
    $script:published=$false
    $script:knownTransaction=$null
    $script:decodedMutation=$null
    $script:computedHashOverride=$null
    $script:events=[Collections.Generic.List[string]]::new()
    $script:tx=New-TestTransaction
    $script:receipt=New-TestReceipt
    $script:block=@{number='0x100';hash=$script:blockHash;transactions=@($script:hash)}
    $script:raw='0x02deadbeef'
    $script:rawObjects=@{}
    $script:rawObjects[$script:raw]=Copy-Map $script:tx
}
function Save-State {
    $script:saveCount++
    $script:events.Add('save-state')
    if ($script:failSaveAt -eq $script:saveCount) {throw 'simulated checkpoint crash'}
    $json=$script:state | ConvertTo-Json -Depth 30 -Compress
    Check (-not $json.Contains($script:raw)) 'Signed raw bytes entered durable state.'
    $script:durable=$json | ConvertFrom-Json -AsHashtable
}
function Record-Receipt([string]$Label,[object]$Receipt) {
    $script:events.Add('record-receipt')
    $script:state.receipts[$Label]=Copy-Map $Receipt
    Save-State
}
function Cast([string[]]$Arguments) {
    switch ($Arguments[0]) {
        'sig' {return $script:callData.Substring(0,10)}
        'calldata' {return $script:callData}
        'estimate' {$script:events.Add('estimate');return $script:estimate}
        'balance' {return $script:balance}
        'keccak' {
            Check ($script:rawObjects.Contains($Arguments[1])) 'Unexpected raw transaction hash input.'
            if ($script:computedHashOverride) {return $script:computedHashOverride}
            return $script:rawObjects[$Arguments[1]].hash
        }
        default {throw "Unexpected cast command: $($Arguments[0])"}
    }
}
function With-Signer([object]$Account,[string]$Program,[string[]]$Arguments) {
    $script:signCount++
    $script:events.Add('sign')
    if ($script:failSignAt -eq $script:signCount) {throw 'simulated signer crash'}
    Check ($Program -eq 'cast' -and $Arguments[0] -eq 'mktx') 'Signing must construct without sending.'
    Check ($Account.address -eq $script:deployer.address) 'Wrong signing account.'
    Check ($Arguments[1] -eq $script:target -and $Arguments[2] -eq $script:callData) 'Signer did not receive exact destination/calldata.'
    foreach ($pair in @(@('--from',$script:deployer.address),@('--chain','11155111'),@('--nonce','7'),@('--value','9'),@('--gas-limit',$script:expectedSignedGas),@('--gas-price','100'),@('--priority-gas-price','10'))) {
        $index=[array]::IndexOf($Arguments,$pair[0])
        Check ($index -ge 0 -and $Arguments[$index+1] -eq $pair[1]) "Missing or changed explicit signing field $($pair[0])."
    }
    $decoded=Copy-Map $script:tx
    if ($script:decodedMutation) {& $script:decodedMutation $decoded}
    if ($script:hashDriftAt -eq $script:signCount) {$decoded.hash='0x'+('cc'*32)}
    $script:rawObjects[$script:raw]=$decoded
    return $script:raw
}
function Invoke-Tool([string]$Program,[string[]]$Arguments,[AllowNull()][string]$StandardInput=$null) {
    Check ($Program -eq 'cast') 'Unexpected external tool.'
    Check ($Arguments -notcontains $script:raw) 'Signed raw bytes entered argv.'
    if ($Arguments[0] -eq 'decode-transaction') {
        Check ($StandardInput -eq $script:raw) 'Decode must receive exact raw transaction through stdin.'
        return $script:rawObjects[$StandardInput] | ConvertTo-Json -Depth 20 -Compress
    }
    Check (($Arguments[0..2] -join '|') -eq 'rpc|eth_sendRawTransaction|--raw') 'Publication must use JSON-RPC stdin.'
    $parameters=@($StandardInput | ConvertFrom-Json -NoEnumerate)
    Check ($parameters.Count -eq 1 -and $parameters[0] -eq $script:raw) 'Publication stdin must contain exactly one raw transaction.'
    Check ($script:durable.Contains('transactionIntents')) 'Publication preceded checkpoint persistence.'
    $persisted=@($script:durable.transactionIntents.Values)
    Check ($persisted.Count -eq 1 -and $persisted[0].transactionHash -eq $script:rawObjects[$script:raw].hash) 'Publication hash was not durably checkpointed.'
    $script:publishCount++
    $script:published=$true
    $script:events.Add('publish')
    if ($script:publishMode -eq 'timeout') {throw 'simulated uncertain publication timeout'}
    if ($script:publishMode -eq 'wrongHash') {return ('"0x'+('dd'*32)+'"')}
    return ('"'+$script:hash+'"')
}
function Rpc([string]$Method,[string[]]$Arguments=@()) {
    switch ($Method) {
        'eth_getTransactionReceipt' {
            if ($script:receiptLookupThrows) {throw 'simulated RPC unavailable'}
            if ($script:receiptMode -eq 'always' -or ($script:receiptMode -eq 'afterPublish' -and $script:published)) {return Copy-Map $script:receipt}
            return $null
        }
        'eth_getTransactionByHash' {
            if ($script:txUnavailable) {return $null}
            if ($null -ne $script:knownTransaction) {return Copy-Map $script:knownTransaction}
            if ($script:published -or $script:receiptMode -eq 'always') {
                $mined=Copy-Map $script:tx
                $mined.blockHash=$script:receipt.blockHash
                $mined.blockNumber=$script:receipt.blockNumber
                $mined.transactionIndex=$script:receipt.transactionIndex
                return $mined
            }
            return $null
        }
        'eth_getTransactionCount' {
            if ($Arguments[1] -eq 'latest') {return $script:latestNonce}
            Check ($Arguments[1] -eq 'pending') 'Unexpected nonce block selector.'
            return $script:pendingNonce
        }
        'eth_getBlockByNumber' {return Copy-Map $script:block}
        default {throw "Unexpected RPC method: $Method"}
    }
}
function Prepared-Intent([string]$Status='prepared') {
    $intent=[ordered]@{from=$script:deployer.address;to=$script:target;input=$script:callData;chainId='11155111'
        nonce='7';value='9';gas='36000';maxFeePerGas='100';maxPriorityFeePerGas='10'
        transactionHash=$script:hash;status=$Status}
    $script:state.transactionIntents=[ordered]@{operation=$intent}
    $script:durable=Copy-Map $script:state
    return $intent
}
function Restart-FromDurable {
    $script:state=Copy-Map $script:durable
    $script:failSaveAt=0
    $script:failSignAt=0
}
function Run-Test([string]$Name,[scriptblock]$Body) {
    Reset-JournalFixture
    try {& $Body; $script:passed++; Write-Output "PASS: $Name"}
    catch {$script:failed.Add("${Name}: $($_.Exception.Message)"); Write-Output "FAIL: ${Name}: $($_.Exception.Message)"}
}

Run-Test 'new transaction persists hash before raw stdin publication and records canonical receipt' {
    $result=Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'
    Check ($result.transactionHash -eq $script:hash) 'Wrong completed receipt.'
    Check ($script:publishCount -eq 1 -and $script:signCount -eq 2) 'Expected two equal constructions and one publication.'
    Check (($script:events.IndexOf('save-state')) -lt $script:events.IndexOf('publish')) 'Checkpoint did not precede publication.'
    Check ($script:durable.transactionIntents.operation.status -eq 'confirmed') 'Completion not durable.'
}
Run-Test 'checkpoint failure publishes nothing and leaves no durable intent' {
    $script:failSaveAt=1
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'checkpoint crash'
    Check ($script:publishCount -eq 0) 'Published despite checkpoint failure.'
    Check (-not $script:durable.Contains('transactionIntents')) 'Failed save created a durable intent.'
}
Run-Test 'first signing crash publishes nothing' {
    $script:failSignAt=1
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'signer crash'
    Check ($script:publishCount -eq 0 -and $script:saveCount -eq 0) 'Signing failure advanced state.'
}
Run-Test 'crash after prepared save resumes the identical transaction' {
    $script:failSignAt=2
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'signer crash'
    Check ($script:durable.transactionIntents.operation.transactionHash -eq $script:hash) 'Prepared hash not retained.'
    Check ($script:publishCount -eq 0) 'Unexpected publication before second signer failure.'
    Restart-FromDurable
    $result=Resume-RecordedTransaction 'operation'
    Check ($result.transactionHash -eq $script:hash -and $script:publishCount -eq 1) 'Resume did not publish exact prepared transaction.'
}
Run-Test 'uncertain broadcast followed by crash recovers mined receipt without republishing' {
    $script:publishMode='timeout'
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'uncertain publication'
    Check ($script:durable.transactionIntents.operation.status -eq 'prepared') 'Timeout rewrote prepared intent.'
    Restart-FromDurable
    $result=Resume-RecordedTransaction 'operation'
    Check ($result.transactionHash -eq $script:hash -and $script:publishCount -eq 1 -and $script:signCount -eq 2) 'Recovery duplicated publication/signing.'
}
Run-Test 'submitted-save crash recovers by hash without another publication' {
    $script:failSaveAt=2
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'checkpoint crash'
    Restart-FromDurable
    $null=Resume-RecordedTransaction 'operation'
    Check ($script:publishCount -eq 1) 'Recovery sent a second transaction.'
}
Run-Test 'receipt-save crash reconstructs canonical completion' {
    $script:failSaveAt=3
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'checkpoint crash'
    Check ($script:durable.transactionIntents.operation.status -eq 'submitted') 'Wrong retained crash boundary.'
    Restart-FromDurable
    $null=Resume-RecordedTransaction 'operation'
    Check ($script:publishCount -eq 1 -and $script:durable.transactionIntents.operation.status -eq 'confirmed') 'Receipt recovery failed.'
}
Run-Test 'hash drift during recreation cannot publish' {
    $script:hashDriftAt=2
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'hash differs'
    Check ($script:publishCount -eq 0 -and $script:durable.transactionIntents.operation.transactionHash -eq $script:hash) 'Hash drift altered prepared identity.'
}
Run-Test 'RPC returns wrong publication hash while original checkpoint remains recoverable' {
    $script:publishMode='wrongHash'
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'different transaction hash'
    Check ($script:durable.transactionIntents.operation.transactionHash -eq $script:hash) 'RPC replaced prepared hash.'
    Restart-FromDurable
    $null=Resume-RecordedTransaction 'operation'
    Check ($script:publishCount -eq 1) 'Wrong RPC response caused duplicate send.'
}
Run-Test 'known pending transaction waits without signing or publishing even with advanced pending nonce' {
    $intent=Prepared-Intent
    $script:knownTransaction=Copy-Map $script:tx
    $script:pendingNonce='0x8'
    $script:receiptMode='none'
    Reject {Complete-Intent 'operation' $intent} 'is pending'
    Check ($script:signCount -eq 0 -and $script:publishCount -eq 0) 'Known pending transaction was duplicated.'
}
foreach ($pair in @(@('0x8','0x8'),@('0x7','0x8'),@('0x6','0x7'))) {
    $latest=$pair[0];$pending=$pair[1]
    Run-Test "unknown hash with nonce conflict latest=$latest pending=$pending" {
        $intent=Prepared-Intent
        $script:latestNonce=$latest;$script:pendingNonce=$pending;$script:receiptMode='none'
        Reject {Complete-Intent 'operation' $intent} 'unknown or replaced'
        Check ($script:publishCount -eq 0 -and $script:signCount -eq 0) 'Nonce conflict triggered signing.'
    }
}
Run-Test 'unknown receipt RPC outcome is never treated as absent' {
    $intent=Prepared-Intent
    $script:receiptLookupThrows=$true
    Reject {Complete-Intent 'operation' $intent} 'RPC unavailable'
    Check ($script:publishCount -eq 0 -and $script:signCount -eq 0) 'RPC failure triggered another send.'
}
Run-Test 'read-only absent transaction cannot sign' {
    $intent=Prepared-Intent
    $script:Broadcast=$false;$script:receiptMode='none'
    Reject {Complete-Intent 'operation' $intent} 'Use its original stage'
    Check ($script:signCount -eq 0 -and $script:publishCount -eq 0) 'Read-only recovery signed.'
}
Run-Test 'confirmed transaction disappearing after reorg does not consume new nonce' {
    $intent=Prepared-Intent 'confirmed'
    $script:receiptMode='none'
    Reject {Complete-Intent 'operation' $intent} 'Previously mined transaction'
    Check ($script:signCount -eq 0 -and $script:publishCount -eq 0) 'Disappeared confirmation caused replay.'
}
Run-Test 'reverted receipt persists terminal outcome and cannot be republished' {
    $intent=Prepared-Intent
    $script:receiptMode='always';$script:receipt.status='0x0'
    Reject {Complete-Intent 'operation' $intent} 'Transaction reverted'
    Check ($script:durable.transactionIntents.operation.status -eq 'reverted') 'Revert was not durable.'
    Restart-FromDurable
    $script:receiptMode='none'
    Reject {Resume-RecordedTransaction 'operation'} 'Previously mined transaction'
    Check ($script:signCount -eq 0 -and $script:publishCount -eq 0) 'Reverted transaction was recreated.'
}
Run-Test 'existing prepared stage rejects changed calldata before signing' {
    $null=Prepared-Intent
    $script:callData='0x87654321'
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'different prepared arguments'
    Check ($script:signCount -eq 0) 'Changed arguments reached signer.'
}
Run-Test 'new transaction refuses outstanding nonce before signing' {
    $script:pendingNonce='0x8'
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'pending transaction'
    Check ($script:signCount -eq 0 -and $script:saveCount -eq 0) 'Pending transaction did not block new intent.'
}
Run-Test 'gas cap rejection precedes signing' {
    $script:estimate='16777216'
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'transaction cap'
    Check ($script:signCount -eq 0) 'Over-cap transaction reached signer.'
}
Run-Test 'insufficient balance rejection precedes signing' {
    $script:balance='1'
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'Insufficient balance'
    Check ($script:signCount -eq 0) 'Unfunded transaction reached signer.'
}
foreach ($field in @('chainId','nonce','gas','value','maxFeePerGas','maxPriorityFeePerGas','from','to','input','type','hash','accessList')) {
    Run-Test "canonical receipt rejects transaction envelope mutation: $field" {
        $intent=Prepared-Intent
        $script:receiptMode='always';$script:knownTransaction=Copy-Map $script:tx
        $script:knownTransaction.blockHash=$script:blockHash
        $script:knownTransaction.blockNumber='0x100';$script:knownTransaction.transactionIndex='0x0'
        $script:knownTransaction[$field]=if ($field -eq 'accessList') {@(@{address=$script:target;storageKeys=@()})} elseif ($field -in @('from','to')) {'0x3333333333333333333333333333333333333333'} elseif ($field -eq 'hash') {'0x'+('cc'*32)} elseif ($field -eq 'input') {'0xabcd'} else {'0x3'}
        Reject {Complete-Intent 'operation' $intent} 'differs'
        Check ($script:saveCount -eq 0 -and $script:signCount -eq 0) 'Invalid receipt advanced state.'
    }
}
Run-Test 'canonical receipt rejects a changed block hash' {
    $intent=Prepared-Intent;$script:receiptMode='always';$script:block.hash='0x'+('cc'*32)
    Reject {Complete-Intent 'operation' $intent} 'canonical transaction'
    Check ($script:saveCount -eq 0) 'Noncanonical receipt persisted.'
}
Run-Test 'receipt with unavailable transaction cannot be accepted' {
    $intent=Prepared-Intent;$script:receiptMode='always';$script:txUnavailable=$true
    Reject {Complete-Intent 'operation' $intent} 'Receipt transaction unavailable'
    Check ($script:saveCount -eq 0) 'Unavailable transaction was accepted.'
}
Run-Test 'receipt block number must match canonical returned block number' {
    $intent=Prepared-Intent;$script:receiptMode='always';$script:block.number='0x101'
    Reject {Complete-Intent 'operation' $intent} 'canonical'
    Check ($script:saveCount -eq 0) 'Mismatched block number persisted.'
}
Run-Test 'receipt transaction block number must match its receipt' {
    $intent=Prepared-Intent;$script:receiptMode='always';$script:knownTransaction=Copy-Map $script:tx
    $script:knownTransaction.blockHash=$script:blockHash;$script:knownTransaction.blockNumber='0x101';$script:knownTransaction.transactionIndex='0x0'
    Reject {Complete-Intent 'operation' $intent} 'canonical'
    Check ($script:saveCount -eq 0) 'Mismatched transaction block number persisted.'
}
Run-Test 'receipt transaction index must match its transaction' {
    $intent=Prepared-Intent;$script:receiptMode='always';$script:knownTransaction=Copy-Map $script:tx
    $script:knownTransaction.blockHash=$script:blockHash;$script:knownTransaction.blockNumber='0x100';$script:knownTransaction.transactionIndex='0x1'
    Reject {Complete-Intent 'operation' $intent} 'canonical'
    Check ($script:saveCount -eq 0) 'Mismatched transaction index persisted.'
}
Run-Test 'malformed receipt status is rejected without a terminal reverted checkpoint' {
    $intent=Prepared-Intent;$script:receiptMode='always';$script:receipt.status='0x2'
    Reject {Complete-Intent 'operation' $intent} ''
    Check ($script:durable.transactionIntents.operation.status -eq 'prepared' -and $script:saveCount -eq 0) 'Malformed status was misclassified as a durable revert.'
}
Run-Test 'legacy successful checkpoint is reconstructed only from exact transaction and receipt' {
    $script:state.receipts.operation=@{transactionHash=$script:hash};$script:receiptMode='always'
    $result=Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'
    Check ($result.transactionHash -eq $script:hash -and $script:durable.transactionIntents.operation.status -eq 'confirmed') 'Historical receipt migration failed.'
    Check ($script:signCount -eq 0 -and $script:publishCount -eq 0) 'Historical completion was sent again.'
}

Run-Test 'header transaction list must contain the exact hash at the receipt index' {
    $intent=Prepared-Intent;$script:receiptMode='always';$script:block.transactions=@('0x'+('cc'*32))
    Reject {Complete-Intent 'operation' $intent} 'canonical'
    Check ($script:saveCount -eq 0) 'Different canonical transaction was accepted.'
}
Run-Test 'out-of-range receipt transaction index is rejected' {
    $intent=Prepared-Intent;$script:receiptMode='always';$script:receipt.transactionIndex='0x1'
    Reject {Complete-Intent 'operation' $intent} 'canonical'
    Check ($script:saveCount -eq 0) 'Out-of-range transaction index persisted.'
}
Run-Test 'negative transaction index cannot address the last block transaction' {
    $intent=Prepared-Intent;$script:receiptMode='always';$script:receipt.transactionIndex='-1'
    Reject {Complete-Intent 'operation' $intent} ''
    Check ($script:saveCount -eq 0) 'Negative transaction index persisted.'
}
foreach ($field in @('from','to','transactionHash')) {
    Run-Test "receipt identity rejects changed $field" {
        $intent=Prepared-Intent;$script:receiptMode='always'
        $script:receipt[$field]=if ($field -eq 'transactionHash') {'0x'+('cc'*32)} else {'0x3333333333333333333333333333333333333333'}
        Reject {Complete-Intent 'operation' $intent} 'canonical'
        Check ($script:saveCount -eq 0) 'Incorrect receipt identity persisted.'
    }
}
Run-Test 'prepared intent from another chain cannot reach signer' {
    $intent=Prepared-Intent;$intent.chainId='1'
    Reject {Complete-Intent 'operation' $intent} 'another chain or deployer'
    Check ($script:signCount -eq 0 -and $script:publishCount -eq 0) 'Foreign intent was signed.'
}
Run-Test 'prepared intent from another deployer cannot reach signer' {
    $intent=Prepared-Intent;$intent.from='0x3333333333333333333333333333333333333333'
    Reject {Complete-Intent 'operation' $intent} 'another chain or deployer'
    Check ($script:signCount -eq 0 -and $script:publishCount -eq 0) 'Foreign signer intent was signed.'
}
Run-Test 'signer changed nonce is rejected before checkpoint' {
    $script:decodedMutation={param($decoded) $decoded.nonce='0x8'}
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'nonce differs'
    Check ($script:saveCount -eq 0 -and $script:publishCount -eq 0) 'Signer changed nonce became durable.'
}
Run-Test 'signer added access list is rejected before checkpoint' {
    $script:decodedMutation={param($decoded) $decoded.accessList=@(@{address=$script:target;storageKeys=@()})}
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'envelope differs'
    Check ($script:saveCount -eq 0 -and $script:publishCount -eq 0) 'Signer access list became durable.'
}
Run-Test 'signer legacy decoded envelope is rejected before checkpoint' {
    $script:decodedMutation={param($decoded) $decoded.type='0x0'}
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'envelope differs'
    Check ($script:saveCount -eq 0 -and $script:publishCount -eq 0) 'Signer changed transaction type became durable.'
}
Run-Test 'decoded hash must match independently computed signed raw hash' {
    $script:computedHashOverride='0x'+('cc'*32)
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'prepared transaction hash'
    Check ($script:saveCount -eq 0 -and $script:publishCount -eq 0) 'Wrong raw hash was persisted.'
}
Run-Test 'successful publication without a receipt remains submitted and blocks new semantics' {
    $script:receiptMode='none'
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'is pending'
    Check ($script:durable.transactionIntents.operation.status -eq 'submitted') 'Pending status was not durable.'
    $script:callData='0x87654321'
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'different prepared arguments'
    Check ($script:publishCount -eq 1) 'Pending operation was replaced.'
}
Run-Test 'unknown publication timeout can republish only the original hash at the unused nonce' {
    $script:publishMode='timeout';$script:receiptMode='none'
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'uncertain publication'
    Restart-FromDurable
    $script:published=$false;$script:publishMode='success';$script:receiptMode='afterPublish'
    $result=Resume-RecordedTransaction 'operation'
    Check ($result.transactionHash -eq $script:hash -and $script:publishCount -eq 2) 'Exact hash was not recovered/rebroadcast.'
    Check ($script:durable.transactionIntents.operation.nonce -eq '7') 'Recovery allocated a different nonce.'
}
Run-Test 'missing legacy receipt cannot silently return as a completed stage' {
    $script:state.receipts.operation=@{transactionHash=$script:hash};$script:receiptMode='none'
    $script:knownTransaction=Copy-Map $script:tx
    $script:knownTransaction.blockHash=$script:blockHash;$script:knownTransaction.blockNumber='0x100';$script:knownTransaction.transactionIndex='0x0'
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9'} 'unavailable'
    Check ($script:signCount -eq 0 -and $script:publishCount -eq 0) 'Missing historical receipt triggered a new send.'
}


foreach ($status in @('prepared','submitted','unrecognized')) {
    Run-Test "a different unresolved $status label blocks fresh signing" {
        $null=Prepared-Intent $status
        Reject {Send-JournaledTransaction 'next' $script:target 'perform()' @() '9'} 'unresolved transaction'
        Check ($script:signCount -eq 0 -and $script:publishCount -eq 0 -and $script:saveCount -eq 0) 'Other pending label was bypassed.'
    }
}
foreach ($status in @('confirmed','reverted')) {
    Run-Test "$status checkpoint cannot allocate its already-consumed nonce" {
        $null=Prepared-Intent $status
        Reject {Send-JournaledTransaction 'next' $script:target 'perform()' @() '9'} 'nonce regressed'
        Check ($script:signCount -eq 0 -and $script:saveCount -eq 0) 'Regressed nonce reached signing.'
    }
    Run-Test "older $status checkpoint permits a new nonce" {
        $intent=Prepared-Intent $status;$intent.nonce='6';$script:failSignAt=1
        Reject {Send-JournaledTransaction 'next' $script:target 'perform()' @() '9'} 'signer crash'
        Check ($script:signCount -eq 1 -and $script:publishCount -eq 0) 'Resolved earlier intent blocked valid preparation.'
    }
}
Run-Test 'explicit retry gas bypasses estimation and is signed and persisted exactly' {
    $script:expectedSignedGas='2000000';$script:tx.gas='0x1e8480'
    $result=Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9' 2000000
    Check ($script:events -notcontains 'estimate') 'Explicit retry gas still used an estimator.'
    Check ($result.transactionHash -eq $script:hash -and $script:durable.transactionIntents.operation.gas -eq '2000000') 'Explicit gas was not preserved.'
}
Run-Test 'resuming an existing retry ignores a different newly requested gas allocation' {
    $null=Prepared-Intent;$script:receiptMode='always'
    $result=Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9' 2000000
    Check ($result.transactionHash -eq $script:hash -and $script:durable.transactionIntents.operation.gas -eq '36000') 'Resume replaced the signed gas.'
    Check ($script:signCount -eq 0 -and $script:publishCount -eq 0) 'Mined retry was signed again.'
}
foreach ($invalidLimit in @(-1,20999,16777217)) {
    Run-Test "explicit invalid gas $invalidLimit rejects before signing" {
        Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9' $invalidLimit} 'gas allocation'
        Check ($script:events -notcontains 'estimate' -and $script:signCount -eq 0 -and $script:saveCount -eq 0) 'Invalid explicit gas advanced preparation.'
    }
}
Run-Test 'explicit retry gas uses its full allocation for the funding check' {
    $script:balance='199999999'
    Reject {Send-JournaledTransaction 'operation' $script:target 'perform()' @() '9' 2000000} 'Insufficient balance'
    Check ($script:signCount -eq 0 -and $script:saveCount -eq 0) 'Underfunded explicit retry was signed.'
}
Run-Test 'historical import hydrates exact chain envelope then canonical resume without signing' {
    $script:state.receipts.operation=@{transactionHash=$script:hash};$script:receiptMode='always'
    Import-HistoricalIntent 'operation' $script:target 'perform()'
    Check ($script:saveCount -eq 0 -and $script:signCount -eq 0) 'Import alone persisted unverified receipt state.'
    Check ($script:state.transactionIntents.operation.input -eq $script:tx.input -and $script:state.transactionIntents.operation.nonce -eq '7') 'Import lost envelope fields.'
    $result=Resume-RecordedTransaction 'operation'
    Check ($result.transactionHash -eq $script:hash -and $script:durable.transactionIntents.operation.status -eq 'confirmed') 'Imported envelope was not canonically confirmed.'
    Check ($script:signCount -eq 0 -and $script:publishCount -eq 0) 'Import signed or republished a mined transaction.'
}
foreach ($field in @('hash','from','to','chainId','input')) {
    Run-Test "historical import rejects wrong $field before persistence" {
        $script:state.receipts.operation=@{transactionHash=$script:hash};$script:receiptMode='always'
        $script:knownTransaction=Copy-Map $script:tx
        $script:knownTransaction[$field]=switch ($field) {
            'hash' {'0x'+('cc'*32)}
            'chainId' {'0x1'}
            'input' {'0x87654321'}
            default {'0x3333333333333333333333333333333333333333'}
        }
        Reject {Import-HistoricalIntent 'operation' $script:target 'perform()'} 'launch stage'
        Check ($script:saveCount -eq 0 -and $script:signCount -eq 0 -and -not $script:state.transactionIntents.Contains('operation')) 'Foreign historical operation was retained.'
    }
}
Run-Test 'historical import requires the public transaction to be available' {
    $script:state.receipts.operation=@{transactionHash=$script:hash};$script:txUnavailable=$true
    Reject {Import-HistoricalIntent 'operation' $script:target 'perform()'} 'unavailable'
    Check ($script:saveCount -eq 0 -and $script:signCount -eq 0) 'Missing historical transaction advanced recovery.'
}
Run-Test 'historical import cannot overwrite an already prepared intent' {
    $null=Prepared-Intent;$script:state.receipts.operation=@{transactionHash='0x'+('cc'*32)}
    Import-HistoricalIntent 'operation' $script:target 'perform()'
    Check ($script:state.transactionIntents.operation.transactionHash -eq $script:hash -and $script:saveCount -eq 0) 'Historical import replaced the prepared identity.'
}
Run-Test 'historical import without a recorded receipt is a no-op' {
    Import-HistoricalIntent 'operation' $script:target 'perform()'
    Check ($script:state.transactionIntents.Count -eq 0 -and $script:saveCount -eq 0 -and $script:signCount -eq 0) 'Absent history caused activity.'
}
Run-Test 'historical import does not turn missing canonical receipt into completion' {
    $script:state.receipts.operation=@{transactionHash=$script:hash};$script:knownTransaction=Copy-Map $script:tx
    Import-HistoricalIntent 'operation' $script:target 'perform()'
    Reject {Resume-RecordedTransaction 'operation'} 'unavailable'
    Check ($script:saveCount -eq 0 -and $script:signCount -eq 0 -and $script:publishCount -eq 0) 'Unconfirmed historical receipt was persisted or resent.'
}

Write-Output "Journal regressions: $($script:passed) passed; $($script:failed.Count) failed. All RPC/signing/persistence were stubbed."
if ($script:failed.Count -gt 0) {throw ($script:failed -join "`n")}