// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Launcher} from "src/contracts/Launcher.sol";
import {Vm} from "forge-std/Vm.sol";
import {MemeToken} from "src/contracts/MemeToken.sol";

contract LaunchMeme is Script {
    MemeToken[] public memes;

    function launchMeme(address mostRecentlyDeployment) public {
        Launcher launcher = Launcher(mostRecentlyDeployment);
        memes = launcher.getMemes();
        address launchedMemeAddress = address(memes[0]);

        vm.startBroadcast();
        launcher.launchMeme(launchedMemeAddress);
        vm.stopBroadcast();

        console.log("Meme launched!");
    }

    function run() public {
        address deployAddress = Vm(address(vm)).getDeployment(
            "Launcher",
            uint64(block.chainid)
        );

        console.log("Most recent Launcher deployment address:");
        console.logAddress(deployAddress);

        launchMeme(deployAddress);
    }
}
