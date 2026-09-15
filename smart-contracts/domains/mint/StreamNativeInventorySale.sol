// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeInventoryState.sol";
import "./StreamPrivateSaleCustody.sol";
import "./StreamPrivateSaleAccounting.sol";
import {
    IStreamNativeInventorySale as I
} from "../../interfaces/stream/mint/IStreamNativeInventorySale.sol";

/// @notice Fixed custody/manifest worker. Caller, host, original digest store and Core pins are
///      supplied by the guarded existing private-sale host, with no independent authority.
library StreamNativeInventorySale {
    event InventoryConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bytes32 indexed inventoryHash,
        address indexed consignor,
        bytes32 configHash,
        uint256[] tokenIds
    );
    event InventoryOpened(uint16 schemaVersion, bytes32 indexed saleId);
    event SaleConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint8 saleKind,
        address asset,
        bytes32 saleConfigHash,
        bytes32 expectedPrimaryPolicyHash,
        uint8 primaryPolicyMode
    );
    event SaleStatusChanged(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint8 previousStatus,
        uint8 newStatus,
        bytes32 reasonHash
    );

    function registerEncoded(
        StreamNativeInventoryState.State storage self,
        StreamPrivateSaleSupport.Context memory context,
        mapping(uint256 => P.CollectionSigner) storage signers,
        address platformSigner,
        uint256 nonce,
        bytes calldata data
    ) public returns (bytes32) {
        (I.Config memory c, uint256[] memory ids) = abi.decode(data[4:], (I.Config, uint256[]));
        return _register(self, context, signers[c.collectionId], platformSigner, nonce, c, ids);
    }

    function _register(
        StreamNativeInventoryState.State storage self,
        StreamPrivateSaleSupport.Context memory context,
        P.CollectionSigner memory signer,
        address platformSigner,
        uint256 nonce,
        I.Config memory c,
        uint256[] memory ids
    ) private returns (bytes32 id) {
        if (
            c.collectionId == 0 || c.consignor == address(0) || c.consignor == address(this)
                || c.unitPrice == 0 || c.startTime >= c.deadline || c.deadline < block.timestamp
                || !c.secondaryConsignment || c.expectedPrimaryPolicyHash != 0 || ids.length == 0
                || ids.length > 64 || !signer.enabled || signer.revision == 0
                || c.signerEvidenceHash != signer.evidenceHash
                || c.signerRevision != signer.revision || c.signerAuthority != signer.authority
                || block.timestamp == 0 || block.timestamp > type(uint64).max
        ) revert I.InvalidInventory();
        uint64 revision = StreamPrivateSaleSupport.requireAdmission(context, 0, 0);
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                uint8(14),
                c.collectionId,
                bytes32(0),
                nonce
            )
        );
        I.Inventory storage sale = self.inventories[id];
        if (sale.saleNonce != 0) revert I.InvalidInventory();
        bytes32 manifest = keccak256(abi.encode(ids));
        bytes32 configHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SECONDARY_INVENTORY_CONFIG_V1"),
                block.chainid,
                address(this),
                nonce,
                platformSigner,
                c,
                manifest
            )
        );
        sale.config = c;
        sale.configHash = configHash;
        sale.inventoryHash = manifest;
        sale.saleNonce = nonce;
        sale.createdAt = uint64(block.timestamp);
        sale.registryRevision = revision;
        sale.status = 1;
        uint256 prior;
        for (uint256 i; i < ids.length; ++i) {
            uint256 token = ids[i];
            if (token <= prior) revert I.InvalidInventory();
            prior = token;
            StreamPrivateSaleSupport.requireToken(context, c.collectionId, token);
            if (StreamPrivateSaleSupport.ownerOf(context, token) != c.consignor) {
                revert P.CustodyGrantInvalid();
            }
            sale.tokenIds.push(token);
            P.Sale storage item = self.tokens[id][token];
            item.config = P.SaleConfig(
                14,
                c.collectionId,
                token,
                c.consignor,
                address(0),
                c.unitPrice,
                c.startTime,
                c.deadline,
                0,
                c.signerEvidenceHash,
                c.signerRevision,
                c.signerAuthority,
                true,
                0
            );
            item.configHash = configHash;
            item.saleNonce = nonce;
            item.createdAt = uint64(block.timestamp);
            item.registryRevision = revision;
            item.status = 1;
        }
        emit SaleConfigured(1, id, c.collectionId, 0, 14, address(0), configHash, 0, 0);
        emit InventoryConfigured(1, id, manifest, c.consignor, configHash, ids);
    }

    function depositEncoded(
        StreamNativeInventoryState.State storage self,
        StreamPrivateSaleSupport.Context memory context,
        mapping(bytes32 => bool) storage consumed,
        uint256 cap,
        bytes calldata data
    ) public {
        (
            bytes32 id,
            StreamPrivateSaleTypes.SaleCustodyGrant memory grant,
            uint8 kind,
            bytes memory signature
        ) = abi.decode(data[4:], (bytes32, StreamPrivateSaleTypes.SaleCustodyGrant, uint8, bytes));
        I.Inventory storage sale = known(self, id);
        P.Sale storage item = token(self, id, grant.tokenId);
        if (sale.status != 1 || item.status != 1 || block.timestamp > sale.config.deadline) {
            revert I.InventoryTokenUnavailable(id, grant.tokenId);
        }
        StreamPrivateSaleSupport.requireAdmission(context, sale.createdAt, sale.registryRevision);
        StreamPrivateSaleCustody.enter(
            context, item, consumed, self.grantSale, id, grant, kind, signature, cap
        );
        StreamPrivateSaleSupport.requireAdmission(context, sale.createdAt, sale.registryRevision);
    }

    function open(
        StreamNativeInventoryState.State storage self,
        StreamPrivateSaleSupport.Context memory context,
        bytes32 id,
        address configurationOwner
    ) public {
        I.Inventory storage sale = known(self, id);
        if (msg.sender != configurationOwner && msg.sender != sale.config.consignor) {
            revert P.PrivateSaleAuthorityInvalid(msg.sender);
        }
        if (sale.status != 1 || block.timestamp > sale.config.deadline) {
            revert P.PrivateSaleUnavailable(id);
        }
        StreamPrivateSaleSupport.requireAdmission(context, sale.createdAt, sale.registryRevision);
        for (uint256 i; i < sale.tokenIds.length; ++i) {
            uint256 t = sale.tokenIds[i];
            if (
                self.tokens[id][t].status != 2
                    || StreamPrivateSaleSupport.ownerOf(context, t) != address(this)
            ) {
                revert I.InventoryTokenUnavailable(id, t);
            }
        }
        sale.status = 2;
        emit InventoryOpened(1, id);
    }

    /// @dev The host has authenticated the full original grant and canonical revocation payload.
    function revoke(
        StreamNativeInventoryState.State storage self,
        StreamPrivateSaleTypes.SaleCustodyGrant calldata grant,
        bytes32 digest
    ) public {
        bytes32 id = self.grantSale[digest];
        P.Sale storage item = token(self, id, grant.tokenId);
        if (item.status == 3) revert P.PrivateSaleUnavailable(id);
        if (
            item.custodyGrantDigest != digest || grant.owner != item.config.consignor
                || grant.saleRef != id
        ) {
            revert P.CustodyGrantInvalid();
        }
        if (item.status == 2) {
            item.status = 4;
            item.nftClaim = 2;
        }
    }

    function close(
        StreamNativeInventoryState.State storage self,
        bytes32 id,
        bool expired,
        address configurationOwner
    ) public {
        I.Inventory storage sale = known(self, id);
        if (sale.status != 1 && sale.status != 2) revert P.PrivateSaleUnavailable(id);
        if (expired) {
            if (block.timestamp <= sale.config.deadline) revert P.PrivateSaleUnavailable(id);
        } else if (msg.sender != configurationOwner && msg.sender != sale.config.consignor) {
            revert P.PrivateSaleAuthorityInvalid(msg.sender);
        }
        uint8 status = expired ? 5 : 4;
        uint8 old = sale.status;
        sale.status = status;
        for (uint256 i; i < sale.tokenIds.length; ++i) {
            P.Sale storage item = self.tokens[id][sale.tokenIds[i]];
            if (item.status == 2) item.nftClaim = 2;
            if (item.status == 1 || item.status == 2) item.status = status;
        }
        emit SaleStatusChanged(
            1,
            id,
            old,
            status,
            expired ? keccak256("PRIVATE_SALE_EXPIRED") : keccak256("PRIVATE_SALE_CANCELLED")
        );
    }

    function claimEncoded(
        StreamNativeInventoryState.State storage self,
        StreamPrivateSaleSupport.Context memory context,
        mapping(bytes32 => bool) storage revoked,
        uint256 cap,
        bytes calldata data
    ) public returns (bool) {
        bytes32 id;
        uint256 tokenId;
        address receiver;
        bool retry;
        if (bytes4(data[:4]) == I.claimInventoryNft.selector) {
            (id, tokenId, receiver) = abi.decode(data[4:], (bytes32, uint256, address));
        } else if (bytes4(data[:4]) == I.retryInventoryNft.selector) {
            (id, tokenId) = abi.decode(data[4:], (bytes32, uint256));
            retry = true;
        } else {
            revert I.InvalidInventory();
        }
        P.Sale storage item = token(self, id, tokenId);
        address beneficiary = item.nftClaim == 1 ? item.config.buyer : item.config.consignor;
        if (item.nftClaim == 0 || (!retry && (msg.sender != beneficiary || receiver == address(0))))
        {
            revert P.PrivateSaleClaimUnavailable();
        }
        return StreamPrivateSaleCustody.deliverClaim(
            context, item, revoked, id, retry ? beneficiary : receiver, cap
        );
    }

    /// @dev The original private/offer getter uses this same exact storage tuple encoder.
    function encodedPrivateSale(P.Sale storage sale) public view returns (bytes memory) {
        return abi.encode(sale);
    }

    /// @dev Terminal views only; the host forwards this canonical tuple unchanged.
    function encodedRead(StreamNativeInventoryState.State storage self, bytes calldata data)
        public
        view
        returns (bytes memory)
    {
        if (bytes4(data[:4]) == I.inventoryDetails.selector) {
            return abi.encode(self.inventories[abi.decode(data[4:], (bytes32))]);
        }
        if (bytes4(data[:4]) == I.inventoryToken.selector) {
            (bytes32 id, uint256 t) = abi.decode(data[4:], (bytes32, uint256));
            return abi.encode(self.tokens[id][t]);
        }
        revert I.InvalidInventory();
    }

    function known(StreamNativeInventoryState.State storage self, bytes32 id)
        internal
        view
        returns (I.Inventory storage sale)
    {
        sale = self.inventories[id];
        if (sale.saleNonce == 0) revert P.PrivateSaleUnavailable(id);
    }

    function token(StreamNativeInventoryState.State storage self, bytes32 id, uint256 t)
        internal
        view
        returns (P.Sale storage item)
    {
        item = self.tokens[id][t];
        if (item.saleNonce == 0) revert I.InventoryTokenUnavailable(id, t);
    }
}
