// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Launcher} from "src/contracts/Launcher.sol";
import {Vm} from "forge-std/Vm.sol";
import {MemeToken} from "src/contracts/MemeToken.sol";

contract BuyMeme is Script {
    uint256 public constant AMOUNT = 1 ether;
    uint256 public constant PRICE = 1e16;
    MemeToken[] public memes;

    function buyMeme(address launcherAddress) public {
        Launcher launcher = Launcher(launcherAddress);
        memes = launcher.getMemes();
        vm.startBroadcast();
        launcher.buyMeme{value: PRICE}(address(memes[0]), AMOUNT);
        vm.stopBroadcast();

        console.log("Bought the meme with address:");
        console.logAddress(address(memes[0]));
    }

    function run() public {
        address deployAddress = Vm(address(vm)).getDeployment(
            "Launcher",
            uint64(block.chainid)
        );

        console.log("Most recent Launcher deployment address:");
        console.logAddress(deployAddress);

        buyMeme(deployAddress);
    }
}
