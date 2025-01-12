// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Launcher} from "src/contracts/Launcher.sol";
import {Vm} from "forge-std/Vm.sol";

contract WithdrawFee is Script {
    uint256 public constant AMOUNT = 0.01 ether;

    function withdrawFee(address mostRecentlyDeployment) public {
        Launcher launcher = Launcher(mostRecentlyDeployment);
        vm.startBroadcast();
        launcher.withdrawFee(AMOUNT);
        vm.stopBroadcast();

        console.log("Fee withdrawn!");
    }

    function run() public {
        address deployAddress = Vm(address(vm)).getDeployment(
            "Launcher",
            uint64(block.chainid)
        );

        console.log("Most recent Launcher deployment address:");
        console.logAddress(deployAddress);

        withdrawFee(deployAddress);
    }
}
