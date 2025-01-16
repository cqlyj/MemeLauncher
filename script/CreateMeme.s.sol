// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Launcher} from "src/contracts/Launcher.sol";
import {Vm, VmSafe} from "forge-std/Vm.sol";

contract CreateMeme is Script {
    string public constant NAME = "Doge";
    string public constant SYMBOL = "DOGE";
    uint256 public constant FEE = 0.01 ether;

    function createMeme(address mostRecentlyDeployment) public {
        Launcher launcher = Launcher(mostRecentlyDeployment);
        vm.startBroadcast();
        launcher.createMeme{value: FEE}(NAME, SYMBOL);
        vm.stopBroadcast();

        console.log("Meme created!");
    }

    function run() public {
        // This is for getting more transaction details

        // Vm.BroadcastTxSummary memory broadcast = Vm(address(vm)).getBroadcast(
        //     "Launcher",
        //     uint64(block.chainid),
        //     // @issue: Vm.BroadcastTxType not working...
        //     VmSafe.BroadcastTxType.Create
        // );
        // console.log("Most recent broadcast Launcher contract address:");
        // console.logAddress(broadcast.contractAddress); // New contract address

        address deployAddress = Vm(address(vm)).getDeployment(
            "Launcher",
            uint64(block.chainid)
        );

        console.log("Most recent Launcher deployment address:");
        console.logAddress(deployAddress); // New contract address

        createMeme(deployAddress);
    }
}
