// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {TollanUniverseItems} from "../src/TollanUniverseItems.sol";

contract TollanUniverseItemsScript is Script {
    function run() external returns (TollanUniverseItems tollan) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        address admin = vm.envAddress("ADMIN");
        console.log("admin:", admin);
        address minter = vm.envAddress("MINTER");
        console.log("minter:", minter);
        address burner = vm.envAddress("BURNER");
        console.log("burner:", burner);
        address signer = vm.envAddress("SIGNER");
        console.log("signer:", signer);
        string memory name712 = vm.envString("NAME712");
        console.log("name712:", name712);
        string memory version712 = vm.envString("VERSION712");
        console.log("version712:", version712);

        vm.startBroadcast(privateKey);
        ProxyAdmin proxyAdmin;
        address implementationAddress;
        (tollan, proxyAdmin, implementationAddress) = deploy(
            admin,
            minter,
            burner,
            signer,
            name712,
            version712
        );
        vm.stopBroadcast();

        console.log("TollanUniverseItems:", address(tollan));
        console.log("ProxyAdmin:", address(proxyAdmin));
        console.log("Implementation:", implementationAddress);
    }

    function deploy(
        address admin,
        address minter,
        address burner,
        address signer,
        string memory name712,
        string memory version712
    )
        public
        returns (
            TollanUniverseItems tollan,
            ProxyAdmin proxyAdmin,
            address implementationAddress
        )
    {
        // Deploy implementation
        TollanUniverseItems implementation = new TollanUniverseItems();
        implementationAddress = address(implementation);

        // Deploy ProxyAdmin
        proxyAdmin = new ProxyAdmin(admin);

        // Encode initializer
        bytes memory initData = abi.encodeCall(
            TollanUniverseItems.initialize,
            (admin, minter, burner, signer, name712, version712)
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            initData
        );

        tollan = TollanUniverseItems(address(proxy));
    }
}
