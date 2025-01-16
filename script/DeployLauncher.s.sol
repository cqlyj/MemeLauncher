// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Launcher} from "src/contracts/Launcher.sol";

contract DeployLauncher is Script {
    Launcher public launcher;
    uint256 public constant FEE = 0.01 ether;

    function run() public {
        vm.startBroadcast();
        // @update update with the real address
        // https://docs.uniswap.org/contracts/v4/deployments
        launcher = new Launcher(FEE, address(0), address(0));
        vm.stopBroadcast();

        console.log("Launcher deployed at address: ", address(launcher));
    }
}
