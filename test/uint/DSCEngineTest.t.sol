// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test,console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizeStableCoin} from "../../src/DecentralizeStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTEst is Test{

    DeployDSC deployer;
    DecentralizeStableCoin dsc;
    DSCEngine dscEngine; 
    HelperConfig helperConfig;

      address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey = 10 ether;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL= 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;


    function setUp() public {
        deployer = new DeployDSC();
        (dsc,dscEngine , helperConfig) = deployer.run();
        ( ethUsdPriceFeed,  btcUsdPriceFeed,  weth,  wbtc, deployerKey) = helperConfig.activeNetworkConfig();
        ERC20Mock(weth).mint(USER,STARTING_ERC20_BALANCE);
    }

    ////////////////
    // PRICE TEST //
    ////////////////
    function testGetUsdValue()    public {

        uint256 ethAmount = 15e18;
        uint256 expectedUsd=  30000e18;
        uint256 actualUsd= dscEngine.getUsdtUsdValue(weth ,ethAmount ); 
       assertEq(actualUsd, expectedUsd);
    }

    //////////////////////////////
    // DEPOSIT COLLATERAL TEST //
    //////////////////////////////

    function testRevertsIfCollateralIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
 

}