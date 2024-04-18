// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployFundMe is Script {
    // we use function run() external to run scripts
    function run() external returns (FundMe) {
        //  before startBroadcast -> not a real tx, we dont spend gas. ran in a simulated env
        HelperConfig helperConfig = new HelperConfig();
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();

        // after startBroadcast -> real tx, spends gas
        vm.startBroadcast(); // funder is msg.sender here with vm.startBroadcast
        FundMe fundMe = new FundMe(ethUsdPriceFeed); // takes input params based on constructor
        vm.stopBroadcast();
        return fundMe;
    }
}
