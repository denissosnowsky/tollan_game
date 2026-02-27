// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {TollanUniverseItems} from "../src/TollanUniverseItems.sol";

contract DefineItemScript is Script {
    function run() external {
        // Load env variables
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address contractAddress = vm.envOr(
            "CONTRACT_ADDRESS",
            0xA51795956EB95D678b01Db4edB7858456cd01cA4
        );

        // item data
        string memory physicalId = "CNY_LEGENDARY_CHARACTER";
        string memory metadataURI = "/";
        uint256 amountCap = 0;

        console.log("Defining item on contract:", contractAddress);
        console.log("Physical ID:", physicalId);
        console.log("Metadata URI:", metadataURI);
        console.log("Amount Cap:", amountCap);

        TollanUniverseItems tollan = TollanUniverseItems(contractAddress);

        vm.startBroadcast(privateKey);
        uint256 nftId = tollan.defineItem(physicalId, metadataURI, amountCap);
        vm.stopBroadcast();

        console.log("Item defined successfully!");
        console.log("NFT ID:", nftId);
    }
}
