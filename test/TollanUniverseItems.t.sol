// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {TollanUniverseItems} from "../src/TollanUniverseItems.sol";
import {TollanUniverseItemsScript} from "../script/TollanUniverseItemsScript.s.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";

contract TollanUniverseItemsTest is Test {
    TollanUniverseItems tollanUniverseItems;
    TollanUniverseItemsScript tollanUniverseItemsScript;

    address admin = makeAddr("admin");
    address minter = makeAddr("minter");
    address burner = makeAddr("burner");
    uint256 signerPrivateKey =
        0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    address signer;
    address user = makeAddr("user");
    address user2 = makeAddr("user2");

    string constant name712 = "TollanUniverseItems";
    string constant version712 = "1.0.0";

    // Test data
    string constant PHYSICAL_ID_1 = "SWORD_001";
    string constant PHYSICAL_ID_2 = "SHIELD_002";
    string constant PHYSICAL_ID_3 = "POTION_003";
    string constant METADATA_URI_1 = "ipfs://QmTest1";
    string constant METADATA_URI_2 = "ipfs://QmTest2";
    string constant METADATA_URI_3 = "ipfs://QmTest3";
    uint256 constant AMOUNT_CAP_UNLIMITED = 0;
    uint256 constant AMOUNT_CAP_100 = 100;

    // EIP-712 typehashes
    bytes32 constant CLAIM_TYPEHASH =
        0xea97b92824caa45e673dad22b48157385b7963088a25cd77eda4e99f0b4450a2;
    bytes32 constant CLAIM_BATCH_TYPEHASH =
        0x70dae5e3916ec9bad3f26be7851dac19106818068928cf478718012a94764f52;

    event ItemDefined(
        string indexed physicalId,
        uint256 indexed nftId,
        string metadataURI
    );
    event TokenURIUpdated(uint256 indexed tokenId, string newURI);
    event BaseURIUpdated(string newBaseURI);
    event ItemsClaimed(
        address indexed user,
        uint256[] tokenIds,
        uint256[] amounts
    );
    event ItemClaimed(address indexed user, uint256 tokenId, uint256 amount);
    event SignerUpdated(address indexed oldSigner, address indexed newSigner);
    event MinterUpdated(address indexed oldMinter, address indexed newMinter);
    event BurnerUpdated(address indexed oldBurner, address indexed newBurner);

    function setUp() public {
        signer = vm.addr(signerPrivateKey);

        deal(admin, 100 ether);
        deal(minter, 100 ether);
        deal(burner, 100 ether);
        deal(signer, 100 ether);
        deal(user, 100 ether);
        deal(user2, 100 ether);

        tollanUniverseItemsScript = new TollanUniverseItemsScript();
        (tollanUniverseItems, , ) = tollanUniverseItemsScript.deploy(
            admin,
            minter,
            burner,
            signer,
            name712,
            version712
        );
    }

    // =============================================================
    // INITIALIZE TESTS
    // =============================================================

    function test_Initialize_SetsRolesCorrectly() public view {
        // Check owner is set correctly (Ownable2StepUpgradeable)
        assertEq(tollanUniverseItems.owner(), admin);
        // Check minter is set correctly
        assertEq(tollanUniverseItems.getMinter(), minter);
        // Check burner is set correctly
        assertEq(tollanUniverseItems.getBurner(), burner);
        // Check signer is set correctly
        assertEq(tollanUniverseItems.getSigner(), signer);
    }

    function test_Initialize_SetsNextTokenIdTo1() public view {
        assertEq(tollanUniverseItems.getNextTokenId(), 1);
    }

    function test_Initialize_CannotBeCalledTwice() public {
        vm.expectRevert();
        tollanUniverseItems.initialize(
            admin,
            minter,
            burner,
            signer,
            name712,
            version712
        );
    }

    // =============================================================
    // DEFINE ITEM TESTS
    // =============================================================

    function test_DefineItem_Success() public {
        vm.prank(admin);
        uint256 nftId = tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(nftId, 1);
        assertEq(tollanUniverseItems.getNextTokenId(), 2);
        assertEq(tollanUniverseItems.getNftIdByPhysicalId(PHYSICAL_ID_1), 1);
        assertEq(tollanUniverseItems.getPhysicalIdByTokenId(1), PHYSICAL_ID_1);
    }

    function test_DefineItem_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit ItemDefined(PHYSICAL_ID_1, 1, METADATA_URI_1);

        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
    }

    function test_DefineItem_RevertsIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
    }

    function test_DefineItem_RevertsIfEmptyPhysicalId() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.EmptyString.selector, "")
        );
        tollanUniverseItems.defineItem(
            "",
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
    }

    function test_DefineItem_RevertsIfAlreadyDefined() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IErrors.ItemAlreadyDefined.selector,
                PHYSICAL_ID_1
            )
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();
    }

    function test_DefineItem_WithAmountCap() public {
        vm.prank(admin);
        uint256 nftId = tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_100
        );

        assertEq(
            tollanUniverseItems.getAmountCap(PHYSICAL_ID_1),
            AMOUNT_CAP_100
        );
        assertEq(nftId, 1);
    }

    // =============================================================
    // DEFINE ITEMS (BATCH) TESTS
    // =============================================================

    function test_DefineItems_Success() public {
        string[] memory physicalIds = new string[](3);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;
        physicalIds[2] = PHYSICAL_ID_3;

        string[] memory metadataURIs = new string[](3);
        metadataURIs[0] = METADATA_URI_1;
        metadataURIs[1] = METADATA_URI_2;
        metadataURIs[2] = METADATA_URI_3;

        uint256[] memory amountCaps = new uint256[](3);
        amountCaps[0] = AMOUNT_CAP_UNLIMITED;
        amountCaps[1] = AMOUNT_CAP_100;
        amountCaps[2] = AMOUNT_CAP_UNLIMITED;

        vm.prank(admin);
        uint256[] memory nftIds = tollanUniverseItems.defineItems(
            physicalIds,
            metadataURIs,
            amountCaps
        );

        assertEq(nftIds.length, 3);
        assertEq(nftIds[0], 1);
        assertEq(nftIds[1], 2);
        assertEq(nftIds[2], 3);
        assertEq(tollanUniverseItems.getNextTokenId(), 4);

        assertEq(tollanUniverseItems.getNftIdByPhysicalId(PHYSICAL_ID_1), 1);
        assertEq(tollanUniverseItems.getNftIdByPhysicalId(PHYSICAL_ID_2), 2);
        assertEq(tollanUniverseItems.getNftIdByPhysicalId(PHYSICAL_ID_3), 3);
        assertEq(tollanUniverseItems.getPhysicalIdByTokenId(1), PHYSICAL_ID_1);
        assertEq(tollanUniverseItems.getPhysicalIdByTokenId(2), PHYSICAL_ID_2);
        assertEq(tollanUniverseItems.getPhysicalIdByTokenId(3), PHYSICAL_ID_3);
        assertEq(
            tollanUniverseItems.getAmountCap(PHYSICAL_ID_1),
            AMOUNT_CAP_UNLIMITED
        );
        assertEq(
            tollanUniverseItems.getAmountCap(PHYSICAL_ID_2),
            AMOUNT_CAP_100
        );
        assertEq(
            tollanUniverseItems.getAmountCap(PHYSICAL_ID_3),
            AMOUNT_CAP_UNLIMITED
        );
    }

    function test_DefineItems_RevertsIfLengthMismatch() public {
        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        string[] memory metadataURIs = new string[](3);
        metadataURIs[0] = METADATA_URI_1;
        metadataURIs[1] = METADATA_URI_2;
        metadataURIs[2] = METADATA_URI_3;

        uint256[] memory amountCaps = new uint256[](2);

        vm.prank(admin);
        vm.expectRevert(IErrors.LengthMismatch.selector);
        tollanUniverseItems.defineItems(physicalIds, metadataURIs, amountCaps);
    }

    function test_DefineItems_RevertsIfNotAdmin() public {
        string[] memory physicalIds = new string[](1);
        physicalIds[0] = PHYSICAL_ID_1;

        string[] memory metadataURIs = new string[](1);
        metadataURIs[0] = METADATA_URI_1;

        uint256[] memory amountCaps = new uint256[](1);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.defineItems(physicalIds, metadataURIs, amountCaps);
    }

    function test_DefineItems_RevertsIfEmptyPhysicalId() public {
        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = "";

        string[] memory metadataURIs = new string[](2);
        metadataURIs[0] = METADATA_URI_1;
        metadataURIs[1] = METADATA_URI_2;

        uint256[] memory amountCaps = new uint256[](2);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.EmptyString.selector, "")
        );
        tollanUniverseItems.defineItems(physicalIds, metadataURIs, amountCaps);
    }

    // =============================================================
    // SET TOKEN URI TESTS
    // =============================================================

    function test_SetTokenURI_Success() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.expectEmit(true, false, false, true);
        emit TokenURIUpdated(1, METADATA_URI_2);
        assertEq(tollanUniverseItems.uri(1), METADATA_URI_1);

        tollanUniverseItems.setTokenURI(1, METADATA_URI_2);
        vm.stopPrank();

        assertEq(tollanUniverseItems.uri(1), METADATA_URI_2);
    }

    function test_SetTokenURI_RevertsIfNotAdmin() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.setTokenURI(1, METADATA_URI_2);
    }

    function test_SetTokenURI_RevertsIfZeroTokenId() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IErrors.ZeroUint.selector, 0));
        tollanUniverseItems.setTokenURI(0, METADATA_URI_1);
    }

    function test_SetTokenURI_RevertsIfItemNotDefined() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ItemNotDefined.selector, "")
        );
        tollanUniverseItems.setTokenURI(999, METADATA_URI_1);
    }

    // =============================================================
    // SET BASE URI TESTS
    // =============================================================

    function test_SetBaseURI_Success() public {
        string memory newBaseURI = "https://api.tollan.io/metadata/";

        vm.expectEmit(false, false, false, true);
        emit BaseURIUpdated(newBaseURI);

        vm.prank(admin);
        tollanUniverseItems.setBaseURI(newBaseURI);

        vm.prank(admin);
        tollanUniverseItems.defineItem("1", "uri", AMOUNT_CAP_UNLIMITED);

        assertEq(tollanUniverseItems.uri(1), string.concat(newBaseURI, "uri"));
    }

    function test_SetBaseURI_RevertsIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.setBaseURI("https://example.com/");
    }

    // =============================================================
    // PAUSE/UNPAUSE TESTS
    // =============================================================

    function test_Pause_Success() public {
        vm.prank(admin);
        tollanUniverseItems.pause();

        assertTrue(tollanUniverseItems.paused());
    }

    function test_Pause_RevertsIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.pause();
    }

    function test_Unpause_Success() public {
        vm.startPrank(admin);
        tollanUniverseItems.pause();
        assertTrue(tollanUniverseItems.paused());

        tollanUniverseItems.unpause();
        assertFalse(tollanUniverseItems.paused());
        vm.stopPrank();
    }

    function test_Unpause_RevertsIfNotAdmin() public {
        vm.prank(admin);
        tollanUniverseItems.pause();

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.unpause();
    }

    // =============================================================
    // SET TOKEN ROYALTY TESTS
    // =============================================================

    function test_SetTokenRoyalty_Success() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.setTokenRoyalty(1, admin, 500); // 5%
        tollanUniverseItems.setTokenRoyalty(2, user, 1000); // 10%
        vm.stopPrank();

        (address receiver, uint256 royaltyAmount) = tollanUniverseItems
            .royaltyInfo(1, 10000);
        assertEq(receiver, admin);
        assertEq(royaltyAmount, 500);

        (address receiver2, uint256 royaltyAmount2) = tollanUniverseItems
            .royaltyInfo(2, 10000);
        assertEq(receiver2, user);
        assertEq(royaltyAmount2, 1000);
    }

    function test_SetTokenRoyalty_RevertsIfNotAdmin() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.setTokenRoyalty(1, admin, 500);
    }

    // =============================================================
    // SET DEFAULT ROYALTY TESTS
    // =============================================================

    function test_SetDefaultRoyalty_Success() public {
        vm.prank(admin);
        tollanUniverseItems.setDefaultRoyalty(admin, 250); // 2.5%

        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        (address receiver, uint256 royaltyAmount) = tollanUniverseItems
            .royaltyInfo(1, 10000);
        assertEq(receiver, admin);
        assertEq(royaltyAmount, 250);
    }

    function test_SetDefaultRoyalty_RevertsIfNotAdmin() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.setDefaultRoyalty(admin, 250);
    }

    // =============================================================
    // OWNERSHIP TRANSFER TESTS (Ownable2StepUpgradeable)
    // =============================================================

    function test_Owner_ReturnsInitialOwner() public view {
        assertEq(tollanUniverseItems.owner(), admin);
    }

    function test_PendingOwner_ReturnsZeroAddressInitially() public view {
        assertEq(tollanUniverseItems.pendingOwner(), address(0));
    }

    function test_TransferOwnership_SetsPendingOwner() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(admin);
        tollanUniverseItems.transferOwnership(newOwner);

        assertEq(tollanUniverseItems.pendingOwner(), newOwner);
        // Owner should still be admin until accepted
        assertEq(tollanUniverseItems.owner(), admin);
    }

    function test_TransferOwnership_RevertsIfNotOwner() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.transferOwnership(newOwner);
    }

    function test_AcceptOwnership_Success() public {
        address newOwner = makeAddr("newOwner");

        // Step 1: Current owner initiates transfer
        vm.prank(admin);
        tollanUniverseItems.transferOwnership(newOwner);

        // Step 2: New owner accepts ownership
        vm.prank(newOwner);
        tollanUniverseItems.acceptOwnership();

        assertEq(tollanUniverseItems.owner(), newOwner);
        assertEq(tollanUniverseItems.pendingOwner(), address(0));
    }

    function test_AcceptOwnership_RevertsIfNotPendingOwner() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(admin);
        tollanUniverseItems.transferOwnership(newOwner);

        // User tries to accept (not the pending owner)
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.acceptOwnership();
    }

    function test_AcceptOwnership_RevertsIfNoPendingOwner() public {
        // No transfer was initiated, so no pending owner
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.acceptOwnership();
    }

    function test_TransferOwnership_CanBeOverwritten() public {
        address newOwner1 = makeAddr("newOwner1");
        address newOwner2 = makeAddr("newOwner2");

        // Initiate transfer to newOwner1
        vm.prank(admin);
        tollanUniverseItems.transferOwnership(newOwner1);
        assertEq(tollanUniverseItems.pendingOwner(), newOwner1);

        // Overwrite with newOwner2
        vm.prank(admin);
        tollanUniverseItems.transferOwnership(newOwner2);
        assertEq(tollanUniverseItems.pendingOwner(), newOwner2);

        // newOwner1 cannot accept anymore
        vm.prank(newOwner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                newOwner1
            )
        );
        tollanUniverseItems.acceptOwnership();

        // newOwner2 can accept
        vm.prank(newOwner2);
        tollanUniverseItems.acceptOwnership();
        assertEq(tollanUniverseItems.owner(), newOwner2);
    }

    function test_NewOwner_CanPerformAdminFunctions() public {
        address newOwner = makeAddr("newOwner");

        // Transfer ownership
        vm.prank(admin);
        tollanUniverseItems.transferOwnership(newOwner);

        vm.prank(newOwner);
        tollanUniverseItems.acceptOwnership();

        // New owner can perform admin functions
        vm.prank(newOwner);
        uint256 nftId = tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(nftId, 1);
    }

    function test_OldOwner_CannotPerformAdminFunctionsAfterTransfer() public {
        address newOwner = makeAddr("newOwner");

        // Transfer ownership
        vm.prank(admin);
        tollanUniverseItems.transferOwnership(newOwner);

        vm.prank(newOwner);
        tollanUniverseItems.acceptOwnership();

        // Old owner (admin) cannot perform admin functions anymore
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                admin
            )
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
    }

    function test_RenounceOwnership_Success() public {
        vm.prank(admin);
        tollanUniverseItems.renounceOwnership();

        assertEq(tollanUniverseItems.owner(), address(0));
    }

    function test_RenounceOwnership_RevertsIfNotOwner() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.renounceOwnership();
    }

    function test_RenounceOwnership_NoOneCanPerformAdminFunctions() public {
        vm.prank(admin);
        tollanUniverseItems.renounceOwnership();

        // No one can perform admin functions
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                admin
            )
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
    }

    // =============================================================
    // SIGNER MANAGEMENT TESTS
    // =============================================================

    function test_GetSigner_ReturnsInitialSigner() public view {
        assertEq(tollanUniverseItems.getSigner(), signer);
    }

    function test_SetSigner_Success() public {
        address newSigner = makeAddr("newSigner");

        vm.expectEmit(true, true, false, false);
        emit SignerUpdated(signer, newSigner);

        vm.prank(admin);
        tollanUniverseItems.setSigner(newSigner);

        assertEq(tollanUniverseItems.getSigner(), newSigner);
    }

    function test_SetSigner_RevertsIfNotAdmin() public {
        address newSigner = makeAddr("newSigner");

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.setSigner(newSigner);
    }

    function test_SetSigner_RevertsIfZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ZeroAddress.selector, address(0))
        );
        tollanUniverseItems.setSigner(address(0));
    }

    function test_SetSigner_EmitsEvent() public {
        address newSigner = makeAddr("newSigner");

        vm.expectEmit(true, true, false, false);
        emit SignerUpdated(signer, newSigner);

        vm.prank(admin);
        tollanUniverseItems.setSigner(newSigner);
    }

    function test_Claim_RevertsAfterSignerChange_WithOldSignature() public {
        // Define item
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256 tokenId = 1;
        uint256 amount = 10;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tollanUniverseItems.nonces(user);

        // Sign with original signer
        bytes memory signature = _signClaim(
            user,
            tokenId,
            PHYSICAL_ID_1,
            amount,
            nonce,
            deadline
        );

        // Change signer
        uint256 newSignerPrivateKey = 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890;
        address newSigner = vm.addr(newSignerPrivateKey);

        vm.prank(admin);
        tollanUniverseItems.setSigner(newSigner);

        // Try to claim with old signature
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IErrors.InvalidSigner.selector));
        tollanUniverseItems.claim(
            tokenId,
            PHYSICAL_ID_1,
            amount,
            deadline,
            signature
        );
    }

    function test_Claim_SuccessAfterSignerChange_WithNewSignature() public {
        // Define item
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256 tokenId = 1;
        uint256 amount = 10;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tollanUniverseItems.nonces(user);

        // Change signer
        uint256 newSignerPrivateKey = 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890;
        address newSigner = vm.addr(newSignerPrivateKey);

        vm.prank(admin);
        tollanUniverseItems.setSigner(newSigner);

        // Sign with new signer
        bytes memory signature = _signClaimWithKey(
            user,
            tokenId,
            PHYSICAL_ID_1,
            amount,
            nonce,
            deadline,
            newSignerPrivateKey
        );

        // Claim should succeed with new signature
        vm.prank(user);
        tollanUniverseItems.claim(
            tokenId,
            PHYSICAL_ID_1,
            amount,
            deadline,
            signature
        );

        assertEq(tollanUniverseItems.balanceOf(user, tokenId), amount);
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), amount);
    }

    // =============================================================
    // MINTER MANAGEMENT TESTS
    // =============================================================

    function test_GetMinter_ReturnsInitialMinter() public view {
        assertEq(tollanUniverseItems.getMinter(), minter);
    }

    function test_SetMinter_Success() public {
        address newMinter = makeAddr("newMinter");

        vm.expectEmit(true, true, false, false);
        emit MinterUpdated(minter, newMinter);

        vm.prank(admin);
        tollanUniverseItems.setMinter(newMinter);

        assertEq(tollanUniverseItems.getMinter(), newMinter);
    }

    function test_SetMinter_RevertsIfNotAdmin() public {
        address newMinter = makeAddr("newMinter");

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.setMinter(newMinter);
    }

    function test_SetMinter_RevertsIfZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ZeroAddress.selector, address(0))
        );
        tollanUniverseItems.setMinter(address(0));
    }

    function test_SetMinter_EmitsEvent() public {
        address newMinter = makeAddr("newMinter");

        vm.expectEmit(true, true, false, false);
        emit MinterUpdated(minter, newMinter);

        vm.prank(admin);
        tollanUniverseItems.setMinter(newMinter);
    }

    function test_MintByPhysicalId_RevertsAfterMinterChange_WithOldMinter() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        // Change minter
        address newMinter = makeAddr("newMinter");
        vm.prank(admin);
        tollanUniverseItems.setMinter(newMinter);

        // Try to mint with old minter
        vm.prank(minter);
        vm.expectRevert(IErrors.InvalidMinter.selector);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);
    }

    function test_MintByPhysicalId_SuccessAfterMinterChange_WithNewMinter() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        // Change minter
        address newMinter = makeAddr("newMinter");
        vm.prank(admin);
        tollanUniverseItems.setMinter(newMinter);

        // Mint with new minter should succeed
        vm.prank(newMinter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 10);
    }

    // =============================================================
    // BURNER MANAGEMENT TESTS
    // =============================================================

    function test_GetBurner_ReturnsInitialBurner() public view {
        assertEq(tollanUniverseItems.getBurner(), burner);
    }

    function test_SetBurner_Success() public {
        address newBurner = makeAddr("newBurner");

        vm.expectEmit(true, true, false, false);
        emit BurnerUpdated(burner, newBurner);

        vm.prank(admin);
        tollanUniverseItems.setBurner(newBurner);

        assertEq(tollanUniverseItems.getBurner(), newBurner);
    }

    function test_SetBurner_RevertsIfNotAdmin() public {
        address newBurner = makeAddr("newBurner");

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        tollanUniverseItems.setBurner(newBurner);
    }

    function test_SetBurner_RevertsIfZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ZeroAddress.selector, address(0))
        );
        tollanUniverseItems.setBurner(address(0));
    }

    function test_SetBurner_EmitsEvent() public {
        address newBurner = makeAddr("newBurner");

        vm.expectEmit(true, true, false, false);
        emit BurnerUpdated(burner, newBurner);

        vm.prank(admin);
        tollanUniverseItems.setBurner(newBurner);
    }

    function test_BurnByPhysicalId_RevertsAfterBurnerChange_WithOldBurner() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);

        // Change burner
        address newBurner = makeAddr("newBurner");
        vm.prank(admin);
        tollanUniverseItems.setBurner(newBurner);

        // Try to burn with old burner
        vm.prank(burner);
        vm.expectRevert(IErrors.InvalidBurner.selector);
        tollanUniverseItems.burnByPhysicalId(user, PHYSICAL_ID_1, 5);
    }

    function test_BurnByPhysicalId_SuccessAfterBurnerChange_WithNewBurner() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);

        // Change burner
        address newBurner = makeAddr("newBurner");
        vm.prank(admin);
        tollanUniverseItems.setBurner(newBurner);

        // Burn with new burner should succeed
        vm.prank(newBurner);
        tollanUniverseItems.burnByPhysicalId(user, PHYSICAL_ID_1, 5);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 5);
    }

    // =============================================================
    // MINT BY PHYSICAL ID TESTS
    // =============================================================

    function test_MintByPhysicalId_Success() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 10);
        assertEq(tollanUniverseItems.totalSupply(1), 10);
    }

    function test_MintByPhysicalId_RevertsIfNotMinter() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(user);
        vm.expectRevert(IErrors.InvalidMinter.selector);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);
    }

    function test_MintByPhysicalId_RevertsIfZeroAddress() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ZeroAddress.selector, address(0))
        );
        tollanUniverseItems.mintByPhysicalId(address(0), PHYSICAL_ID_1, 10);
    }

    function test_MintByPhysicalId_RevertsIfZeroAmount() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(IErrors.ZeroUint.selector, 0));
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 0);
    }

    function test_MintByPhysicalId_RevertsIfEmptyPhysicalId() public {
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.EmptyString.selector, "")
        );
        tollanUniverseItems.mintByPhysicalId(user, "", 10);
    }

    function test_MintByPhysicalId_RevertsIfItemNotDefined() public {
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrors.ItemNotDefined.selector,
                PHYSICAL_ID_1
            )
        );
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);
    }

    function test_MintByPhysicalId_RevertsIfPaused() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(admin);
        tollanUniverseItems.pause();

        vm.prank(minter);
        vm.expectRevert();
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);
    }

    function test_MintByPhysicalId_RevertsIfAmountCapExceeded() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_100
        );

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.AmountCapExceeded.selector, 101, 100)
        );
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 101);
    }

    // =============================================================
    // MINT BATCH BY PHYSICAL ID TESTS
    // =============================================================

    function test_MintBatchByPhysicalId_Success() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        vm.prank(minter);
        tollanUniverseItems.mintBatchByPhysicalId(user, physicalIds, amounts);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 10);
        assertEq(tollanUniverseItems.balanceOf(user, 2), 20);
    }

    function test_MintBatchByPhysicalId_RevertsIfNotMinter() public {
        string[] memory physicalIds = new string[](1);
        physicalIds[0] = PHYSICAL_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;

        vm.prank(user);
        vm.expectRevert(IErrors.InvalidMinter.selector);
        tollanUniverseItems.mintBatchByPhysicalId(user, physicalIds, amounts);
    }

    function test_MintBatchByPhysicalId_RevertsIfLengthMismatch() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;

        vm.prank(minter);
        vm.expectRevert(IErrors.LengthMismatch.selector);
        tollanUniverseItems.mintBatchByPhysicalId(user, physicalIds, amounts);
    }

    function test_MintBatchByPhysicalId_RevertsIfZeroAddress() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        string[] memory physicalIds = new string[](1);
        physicalIds[0] = PHYSICAL_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ZeroAddress.selector, address(0))
        );
        tollanUniverseItems.mintBatchByPhysicalId(
            address(0),
            physicalIds,
            amounts
        );
    }

    function test_MintBatchByPhysicalId_RevertsIfItemNotDefined() public {
        string[] memory physicalIds = new string[](1);
        physicalIds[0] = PHYSICAL_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrors.ItemNotDefined.selector,
                PHYSICAL_ID_1
            )
        );
        tollanUniverseItems.mintBatchByPhysicalId(user, physicalIds, amounts);
    }

    // =============================================================
    // BURN BY PHYSICAL ID TESTS
    // =============================================================

    function test_BurnByPhysicalId_Success() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 10);

        vm.prank(burner);
        tollanUniverseItems.burnByPhysicalId(user, PHYSICAL_ID_1, 5);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 5);
        assertEq(tollanUniverseItems.totalSupply(1), 5);
    }

    function test_BurnByPhysicalId_RevertsIfNotBurner() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);

        vm.prank(user);
        vm.expectRevert(IErrors.InvalidBurner.selector);
        tollanUniverseItems.burnByPhysicalId(user, PHYSICAL_ID_1, 5);
    }

    function test_BurnByPhysicalId_RevertsIfZeroAddress() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(burner);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ZeroAddress.selector, address(0))
        );
        tollanUniverseItems.burnByPhysicalId(address(0), PHYSICAL_ID_1, 5);
    }

    function test_BurnByPhysicalId_RevertsIfZeroAmount() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(burner);
        vm.expectRevert(abi.encodeWithSelector(IErrors.ZeroUint.selector, 0));
        tollanUniverseItems.burnByPhysicalId(user, PHYSICAL_ID_1, 0);
    }

    function test_BurnByPhysicalId_RevertsIfEmptyPhysicalId() public {
        vm.prank(burner);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.EmptyString.selector, "")
        );
        tollanUniverseItems.burnByPhysicalId(user, "", 5);
    }

    function test_BurnByPhysicalId_RevertsIfItemNotDefined() public {
        vm.prank(burner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrors.ItemNotDefined.selector,
                PHYSICAL_ID_1
            )
        );
        tollanUniverseItems.burnByPhysicalId(user, PHYSICAL_ID_1, 5);
    }

    function test_BurnByPhysicalId_RevertsIfInsufficientBalance() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 5);

        vm.prank(burner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector,
                user,
                5,
                10,
                1
            )
        );
        tollanUniverseItems.burnByPhysicalId(user, PHYSICAL_ID_1, 10);
    }

    // =============================================================
    // BURN BATCH BY PHYSICAL ID TESTS
    // =============================================================

    function test_BurnBatchByPhysicalId_Success() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory mintAmounts = new uint256[](2);
        mintAmounts[0] = 10;
        mintAmounts[1] = 20;

        vm.prank(minter);
        tollanUniverseItems.mintBatchByPhysicalId(
            user,
            physicalIds,
            mintAmounts
        );

        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 5;
        burnAmounts[1] = 10;

        vm.prank(burner);
        tollanUniverseItems.burnBatchByPhysicalId(
            user,
            physicalIds,
            burnAmounts
        );

        assertEq(tollanUniverseItems.balanceOf(user, 1), 5);
        assertEq(tollanUniverseItems.balanceOf(user, 2), 10);
    }

    function test_BurnBatchByPhysicalId_RevertsIfNotBurner() public {
        string[] memory physicalIds = new string[](1);
        physicalIds[0] = PHYSICAL_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5;

        vm.prank(user);
        vm.expectRevert(IErrors.InvalidBurner.selector);
        tollanUniverseItems.burnBatchByPhysicalId(user, physicalIds, amounts);
    }

    function test_BurnBatchByPhysicalId_RevertsIfLengthMismatch() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5;

        vm.prank(burner);
        vm.expectRevert(IErrors.LengthMismatch.selector);
        tollanUniverseItems.burnBatchByPhysicalId(user, physicalIds, amounts);
    }

    function test_BurnBatchByPhysicalId_RevertsIfZeroAddress() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        string[] memory physicalIds = new string[](1);
        physicalIds[0] = PHYSICAL_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5;

        vm.prank(burner);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ZeroAddress.selector, address(0))
        );
        tollanUniverseItems.burnBatchByPhysicalId(
            address(0),
            physicalIds,
            amounts
        );
    }

    // =============================================================
    // CLAIM TESTS
    // =============================================================

    function test_Claim_Success() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256 tokenId = 1;
        uint256 amount = 10;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tollanUniverseItems.nonces(user);

        bytes memory signature = _signClaim(
            user,
            tokenId,
            PHYSICAL_ID_1,
            amount,
            nonce,
            deadline
        );

        vm.expectEmit(true, false, false, true);
        emit ItemClaimed(user, tokenId, amount);

        vm.prank(user);
        tollanUniverseItems.claim(
            tokenId,
            PHYSICAL_ID_1,
            amount,
            deadline,
            signature
        );

        assertEq(tollanUniverseItems.balanceOf(user, tokenId), amount);
        assertEq(tollanUniverseItems.nonces(user), nonce + 1);
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), amount);
    }

    function test_Claim_AccumulatesCorrectly() public {
        // Define item
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256 tokenId = 1;

        // First claim: 50 tokens
        uint256 amount1 = 50;
        uint256 deadline1 = block.timestamp + 1 hours;
        uint256 nonce1 = tollanUniverseItems.nonces(user);
        bytes memory signature1 = _signClaim(
            user,
            tokenId,
            PHYSICAL_ID_1,
            amount1,
            nonce1,
            deadline1
        );

        vm.prank(user);
        tollanUniverseItems.claim(
            tokenId,
            PHYSICAL_ID_1,
            amount1,
            deadline1,
            signature1
        );

        // Verify first claim
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), 50);
        assertEq(tollanUniverseItems.balanceOf(user, tokenId), 50);

        // Second claim: 30 more tokens
        uint256 amount2 = 30;
        uint256 deadline2 = block.timestamp + 2 hours;
        uint256 nonce2 = tollanUniverseItems.nonces(user);
        bytes memory signature2 = _signClaim(
            user,
            tokenId,
            PHYSICAL_ID_1,
            amount2,
            nonce2,
            deadline2
        );

        vm.prank(user);
        tollanUniverseItems.claim(
            tokenId,
            PHYSICAL_ID_1,
            amount2,
            deadline2,
            signature2
        );

        // Verify accumulation
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), 80); // 50 + 30
        assertEq(tollanUniverseItems.balanceOf(user, tokenId), 80);
    }

    function test_Claim_SeparatesClaimedByPhysicalId() public {
        // Define two items
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        // Claim 100 of item 1
        uint256 amount1 = 100;
        uint256 deadline1 = block.timestamp + 1 hours;
        uint256 nonce1 = tollanUniverseItems.nonces(user);
        bytes memory signature1 = _signClaim(
            user,
            1,
            PHYSICAL_ID_1,
            amount1,
            nonce1,
            deadline1
        );

        vm.prank(user);
        tollanUniverseItems.claim(
            1,
            PHYSICAL_ID_1,
            amount1,
            deadline1,
            signature1
        );

        // Claim 50 of item 2
        uint256 amount2 = 50;
        uint256 deadline2 = block.timestamp + 2 hours;
        uint256 nonce2 = tollanUniverseItems.nonces(user);
        bytes memory signature2 = _signClaim(
            user,
            2,
            PHYSICAL_ID_2,
            amount2,
            nonce2,
            deadline2
        );

        vm.prank(user);
        tollanUniverseItems.claim(
            2,
            PHYSICAL_ID_2,
            amount2,
            deadline2,
            signature2
        );

        // Verify separate tracking
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), 100);
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_2), 50);
        assertEq(tollanUniverseItems.balanceOf(user, 1), 100);
        assertEq(tollanUniverseItems.balanceOf(user, 2), 50);
    }

    function test_Claim_RevertsIfZeroAmount() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        bytes memory signature = "";

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IErrors.ZeroUint.selector, 0));
        tollanUniverseItems.claim(
            1,
            PHYSICAL_ID_1,
            0,
            block.timestamp + 1 hours,
            signature
        );
    }

    function test_Claim_RevertsIfEmptyPhysicalId() public {
        bytes memory signature = "";

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.EmptyString.selector, "")
        );
        tollanUniverseItems.claim(
            1,
            "",
            10,
            block.timestamp + 1 hours,
            signature
        );
    }

    function test_Claim_RevertsIfExpired() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tollanUniverseItems.nonces(user);
        bytes memory signature = _signClaim(
            user,
            1,
            PHYSICAL_ID_1,
            10,
            nonce,
            deadline
        );

        // Warp past the deadline
        vm.warp(deadline + 1);

        vm.prank(user);
        vm.expectRevert(IErrors.SignatureExpired.selector);
        tollanUniverseItems.claim(1, PHYSICAL_ID_1, 10, deadline, signature);
    }

    function test_Claim_RevertsIfItemNotDefined() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signClaim(
            user,
            999,
            PHYSICAL_ID_1,
            10,
            0,
            deadline
        );

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ItemNotDefined.selector, "")
        );
        tollanUniverseItems.claim(999, PHYSICAL_ID_1, 10, deadline, signature);
    }

    function test_Claim_RevertsIfInvalidSigner() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256 deadline = block.timestamp + 1 hours;
        // Sign with wrong private key
        bytes memory signature = _signClaimWithKey(
            user,
            1,
            PHYSICAL_ID_1,
            10,
            0,
            deadline,
            0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
        );

        vm.prank(user);
        vm.expectRevert(IErrors.InvalidSigner.selector);
        tollanUniverseItems.claim(1, PHYSICAL_ID_1, 10, deadline, signature);
    }

    function test_Claim_RevertsIfPaused() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(admin);
        tollanUniverseItems.pause();

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signClaim(
            user,
            1,
            PHYSICAL_ID_1,
            10,
            0,
            deadline
        );

        vm.prank(user);
        vm.expectRevert();
        tollanUniverseItems.claim(1, PHYSICAL_ID_1, 10, deadline, signature);
    }

    function test_Claim_WithZeroDeadline_DoesNotExpire() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256 tokenId = 1;
        uint256 amount = 10;
        uint256 deadline = 0; // No expiry
        uint256 nonce = tollanUniverseItems.nonces(user);

        bytes memory signature = _signClaim(
            user,
            tokenId,
            PHYSICAL_ID_1,
            amount,
            nonce,
            deadline
        );

        // Warp far into the future
        vm.warp(block.timestamp + 365 days);

        vm.prank(user);
        tollanUniverseItems.claim(
            tokenId,
            PHYSICAL_ID_1,
            amount,
            deadline,
            signature
        );

        assertEq(tollanUniverseItems.balanceOf(user, tokenId), amount);
    }

    // =============================================================
    // CLAIM BATCH TESTS
    // =============================================================

    function test_ClaimBatch_Success() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tollanUniverseItems.nonces(user);

        bytes memory signature = _signClaimBatch(
            user,
            tokenIds,
            physicalIds,
            amounts,
            nonce,
            deadline
        );

        vm.expectEmit(true, false, false, true);
        emit ItemsClaimed(user, tokenIds, amounts);

        vm.prank(user);
        tollanUniverseItems.claimBatch(
            tokenIds,
            physicalIds,
            amounts,
            deadline,
            signature
        );

        assertEq(tollanUniverseItems.balanceOf(user, 1), 10);
        assertEq(tollanUniverseItems.balanceOf(user, 2), 20);
        assertEq(tollanUniverseItems.nonces(user), nonce + 1);
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), 10);
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_2), 20);
    }

    function test_ClaimBatch_AccumulatesWithSingleClaim() public {
        // Define items
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        // Batch claim
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        uint256 deadline1 = block.timestamp + 1 hours;
        uint256 nonce1 = tollanUniverseItems.nonces(user);
        bytes memory signature1 = _signClaimBatch(
            user,
            tokenIds,
            physicalIds,
            amounts,
            nonce1,
            deadline1
        );

        vm.prank(user);
        tollanUniverseItems.claimBatch(
            tokenIds,
            physicalIds,
            amounts,
            deadline1,
            signature1
        );

        // Verify batch claim tracking
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), 10);
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_2), 20);

        // Single claim 5 more of PHYSICAL_ID_1
        uint256 amount2 = 5;
        uint256 deadline2 = block.timestamp + 2 hours;
        uint256 nonce2 = tollanUniverseItems.nonces(user);
        bytes memory signature2 = _signClaim(
            user,
            1,
            PHYSICAL_ID_1,
            amount2,
            nonce2,
            deadline2
        );

        vm.prank(user);
        tollanUniverseItems.claim(
            1,
            PHYSICAL_ID_1,
            amount2,
            deadline2,
            signature2
        );

        // Verify accumulation
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_1), 15); // 10 + 5
        assertEq(tollanUniverseItems.getClaimed(user, PHYSICAL_ID_2), 20); // unchanged
    }

    function test_ClaimBatch_RevertsIfLengthMismatch() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        string[] memory physicalIds = new string[](1);
        physicalIds[0] = PHYSICAL_ID_1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        bytes memory signature = "";

        vm.prank(user);
        vm.expectRevert(IErrors.LengthMismatch.selector);
        tollanUniverseItems.claimBatch(
            tokenIds,
            physicalIds,
            amounts,
            block.timestamp + 1 hours,
            signature
        );
    }

    function test_ClaimBatch_RevertsIfExpired() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = tollanUniverseItems.nonces(user);
        bytes memory signature = _signClaimBatch(
            user,
            tokenIds,
            physicalIds,
            amounts,
            nonce,
            deadline
        );

        // Warp past the deadline
        vm.warp(deadline + 1);

        vm.prank(user);
        vm.expectRevert(IErrors.SignatureExpired.selector);
        tollanUniverseItems.claimBatch(
            tokenIds,
            physicalIds,
            amounts,
            deadline,
            signature
        );
    }

    function test_ClaimBatch_RevertsIfItemNotDefined() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 999; // Not defined

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signClaimBatch(
            user,
            tokenIds,
            physicalIds,
            amounts,
            0,
            deadline
        );

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ItemNotDefined.selector, "")
        );
        tollanUniverseItems.claimBatch(
            tokenIds,
            physicalIds,
            amounts,
            deadline,
            signature
        );
    }

    function test_ClaimBatch_RevertsIfInvalidSigner() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        uint256 deadline = block.timestamp + 1 hours;
        // Sign with wrong key
        bytes memory signature = _signClaimBatchWithKey(
            user,
            tokenIds,
            physicalIds,
            amounts,
            0,
            deadline,
            0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
        );

        vm.prank(user);
        vm.expectRevert(IErrors.InvalidSigner.selector);
        tollanUniverseItems.claimBatch(
            tokenIds,
            physicalIds,
            amounts,
            deadline,
            signature
        );
    }

    // =============================================================
    // VIEW FUNCTIONS TESTS
    // =============================================================

    function test_GetNftIdByPhysicalId_Success() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(tollanUniverseItems.getNftIdByPhysicalId(PHYSICAL_ID_1), 1);
    }

    function test_GetNftIdByPhysicalId_RevertsIfNotDefined() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrors.ItemNotDefined.selector,
                PHYSICAL_ID_1
            )
        );
        tollanUniverseItems.getNftIdByPhysicalId(PHYSICAL_ID_1);
    }

    function test_GetPhysicalIdByTokenId_Success() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(tollanUniverseItems.getPhysicalIdByTokenId(1), PHYSICAL_ID_1);
    }

    function test_GetPhysicalIdByTokenId_RevertsIfNotDefined() public {
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ItemNotDefined.selector, "")
        );
        tollanUniverseItems.getPhysicalIdByTokenId(999);
    }

    function test_GetNextTokenId() public {
        assertEq(tollanUniverseItems.getNextTokenId(), 1);

        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(tollanUniverseItems.getNextTokenId(), 2);
    }

    function test_IsPhysicalIdDefined() public {
        assertFalse(tollanUniverseItems.isPhysicalIdDefined(PHYSICAL_ID_1));

        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertTrue(tollanUniverseItems.isPhysicalIdDefined(PHYSICAL_ID_1));
    }

    function test_BalanceOfPhysicalId() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(
            tollanUniverseItems.balanceOfPhysicalId(user, PHYSICAL_ID_1),
            0
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 10);

        assertEq(
            tollanUniverseItems.balanceOfPhysicalId(user, PHYSICAL_ID_1),
            10
        );
    }

    function test_BalanceOfPhysicalId_RevertsIfNotDefined() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrors.ItemNotDefined.selector,
                PHYSICAL_ID_1
            )
        );
        tollanUniverseItems.balanceOfPhysicalId(user, PHYSICAL_ID_1);
    }

    function test_Uri_Success() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(tollanUniverseItems.uri(1), METADATA_URI_1);
    }

    function test_Uri_RevertsIfNotDefined() public {
        vm.expectRevert(
            abi.encodeWithSelector(IErrors.ItemNotDefined.selector, "")
        );
        tollanUniverseItems.uri(999);
    }

    function test_TotalSupply() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        assertEq(tollanUniverseItems.totalSupply(1), 0);

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 100);

        assertEq(tollanUniverseItems.totalSupply(1), 100);
    }

    function test_SupportsInterface() public view {
        // ERC1155
        assertTrue(
            tollanUniverseItems.supportsInterface(type(IERC1155).interfaceId)
        );
        // ERC165
        assertTrue(tollanUniverseItems.supportsInterface(0x01ffc9a7));
    }

    // =============================================================
    // ERC1155 INHERITED FUNCTIONS TESTS
    // =============================================================

    function test_BalanceOf() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 50);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 50);
    }

    function test_SafeTransferFrom() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 50);

        vm.prank(user);
        tollanUniverseItems.safeTransferFrom(user, user2, 1, 20, "");

        assertEq(tollanUniverseItems.balanceOf(user, 1), 30);
        assertEq(tollanUniverseItems.balanceOf(user2, 1), 20);
    }

    function test_SafeBatchTransferFrom() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 50;
        amounts[1] = 100;

        vm.prank(minter);
        tollanUniverseItems.mintBatchByPhysicalId(user, physicalIds, amounts);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 20;
        transferAmounts[1] = 30;

        vm.prank(user);
        tollanUniverseItems.safeBatchTransferFrom(
            user,
            user2,
            ids,
            transferAmounts,
            ""
        );

        assertEq(tollanUniverseItems.balanceOf(user, 1), 30);
        assertEq(tollanUniverseItems.balanceOf(user, 2), 70);
        assertEq(tollanUniverseItems.balanceOf(user2, 1), 20);
        assertEq(tollanUniverseItems.balanceOf(user2, 2), 30);
    }

    function test_SetApprovalForAll() public {
        vm.prank(user);
        tollanUniverseItems.setApprovalForAll(user2, true);

        assertTrue(tollanUniverseItems.isApprovedForAll(user, user2));
    }

    // =============================================================
    // ERC1155 BURNABLE TESTS
    // =============================================================

    function test_Burn_ByOwner() public {
        vm.prank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );

        vm.prank(minter);
        tollanUniverseItems.mintByPhysicalId(user, PHYSICAL_ID_1, 50);

        vm.prank(user);
        tollanUniverseItems.burn(user, 1, 20);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 30);
    }

    function test_BurnBatch_ByOwner() public {
        vm.startPrank(admin);
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_1,
            METADATA_URI_1,
            AMOUNT_CAP_UNLIMITED
        );
        tollanUniverseItems.defineItem(
            PHYSICAL_ID_2,
            METADATA_URI_2,
            AMOUNT_CAP_UNLIMITED
        );
        vm.stopPrank();

        string[] memory physicalIds = new string[](2);
        physicalIds[0] = PHYSICAL_ID_1;
        physicalIds[1] = PHYSICAL_ID_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 50;
        amounts[1] = 100;

        vm.prank(minter);
        tollanUniverseItems.mintBatchByPhysicalId(user, physicalIds, amounts);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 10;
        burnAmounts[1] = 20;

        vm.prank(user);
        tollanUniverseItems.burnBatch(user, ids, burnAmounts);

        assertEq(tollanUniverseItems.balanceOf(user, 1), 40);
        assertEq(tollanUniverseItems.balanceOf(user, 2), 80);
    }

    // =============================================================
    // HELPER FUNCTIONS
    // =============================================================

    function _signClaim(
        address to,
        uint256 tokenId,
        string memory physicalId,
        uint256 amount,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory) {
        return
            _signClaimWithKey(
                to,
                tokenId,
                physicalId,
                amount,
                nonce,
                deadline,
                signerPrivateKey
            );
    }

    function _signClaimWithKey(
        address to,
        uint256 tokenId,
        string memory physicalId,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_TYPEHASH,
                to,
                tokenId,
                keccak256(bytes(physicalId)),
                amount,
                nonce,
                deadline
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _signClaimBatch(
        address to,
        uint256[] memory tokenIds,
        string[] memory physicalIds,
        uint256[] memory amounts,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory) {
        return
            _signClaimBatchWithKey(
                to,
                tokenIds,
                physicalIds,
                amounts,
                nonce,
                deadline,
                signerPrivateKey
            );
    }

    function _signClaimBatchWithKey(
        address to,
        uint256[] memory tokenIds,
        string[] memory physicalIds,
        uint256[] memory amounts,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 tokenIdsHash = keccak256(abi.encode(tokenIds));
        bytes32 amountsHash = keccak256(abi.encode(amounts));

        bytes32[] memory pHashes = new bytes32[](physicalIds.length);
        for (uint256 i = 0; i < physicalIds.length; i++) {
            pHashes[i] = keccak256(bytes(physicalIds[i]));
        }
        bytes32 physicalIdsHash = keccak256(abi.encode(pHashes));

        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_BATCH_TYPEHASH,
                to,
                tokenIdsHash,
                physicalIdsHash,
                amountsHash,
                nonce,
                deadline
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _hashTypedDataV4(
        bytes32 structHash
    ) internal view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name712)),
                keccak256(bytes(version712)),
                block.chainid,
                address(tollanUniverseItems)
            )
        );
        return MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
    }
}
