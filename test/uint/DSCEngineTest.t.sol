// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizeStableCoin} from "../../src/DecentralizeStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

contract DSCEngineTEst is Test{

    DeployDSC deployer;
    DecentralizeStableCoin dsc;
    DSCEngine dscEngine; 

    function setUp() public {
        deployer = new DeployDSC();
        (dsc,dscEngine) = deployer.run();
    }

}