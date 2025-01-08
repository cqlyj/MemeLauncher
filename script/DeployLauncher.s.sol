// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Launcher} from "src/Launcher.sol";

contract DeployLauncher is Script {
    Launcher public launcher;
    uint256 public constant FEE = 0.01 ether;

    function run() public {
        vm.startBroadcast();
        launcher = new Launcher(FEE);
        vm.stopBroadcast();

        console.log("Launcher deployed at address: ", address(launcher));
    }
}
