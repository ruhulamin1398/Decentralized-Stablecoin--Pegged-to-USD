// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

// import {OracleLib, AggregatorV3Interface} from "./libraries/OracleLib.sol";
// The correct path for ReentrancyGuard in latest Openzeppelin contracts is
//"import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DecentralizeStableCoin} from "./DecentralizeStableCoin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/*
 * @title DSCEngine
 * @author Ruhul amin
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */
contract DSCEngine is ReentrancyGuard {
    ///////////////////
    // Errors
    ///////////////////
    error DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenNotAllowed(address token);
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactorValue);
    error DSCEngine__MintFailed();
    error DSCEngine__BurnFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    ///////////////////
    // Types
    ///////////////////

    ///////////////////
    // State Variables
    ///////////////////
    uint256 public constant PRECISION = 1e18; // 10^18
    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FECTOR = 1e18;
    mapping(address token => address priceFeed) private s_priceFeeds; // token to pricefeed
    mapping(address user => mapping(address token => uint256)) private s_collateralDeposited; // user to token to balance
    address[] private s_collateralTokens; // tokens
    DecentralizeStableCoin private immutable i_dsc;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted; // user to amount minted

    ///////////////////
    // Events
    ///////////////////
    event CollateralDeposited(address indexed user, address token, uint256 amount);
    event CollateralRedeemed(address indexed user, address token, uint256 amount);
    

    ///////////////////
    // Modifiers
    ///////////////////
    modifier moreThenZero(uint256 amountCollateral) {
        if (amountCollateral == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    ///////////////////
    // Functions
    ///////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizeStableCoin(dscAddress);
    }

 /*
    *   @param tokenCollateralAdress The address of the token to deposit as collateral
    *   @param amountCollateral The amount of collateral to deposit
    *   @param amountDscToMint The amount of DSC to mint
    *   @notice this function will deposit collateral and mint DSC
    */

    function depositCollateralAndMintDsc(address tokenCollateralAdress, uint256 amountCollatarel, uint256 amounDscToMint)
        external
    {
        depositCollateral(tokenCollateralAdress, amountCollatarel);
        mintDsc(amounDscToMint);
    }
    

    // in order to redeem collatarel 
    // 1. health factor must be over 1 After collatarel pulled 
    /*
    *   @notice follows CEI
    *   @param tokenCollateralAdress The address of the token to deposit as collateral
    *   @param amountCollateral The amount of collateral to deposit
    */

    function depositCollateral(address tokenCollateralAdress, uint256 amountCollateral)
        public
        moreThenZero(amountCollateral)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAdress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAdress, amountCollateral);
        bool success = IERC20(tokenCollateralAdress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender);

    }

    function redeemCollateralForDsc( address tokenCollateralAdress , uint256 amountCollataral, uint256 amountDscBurn) external {
        burnDsc(amountDscBurn);
        redeedCollateral(tokenCollateralAdress, amountCollataral);    
        }

    /*
    *   @notice follows CEI
    *   @param tokenCollateralAdress The address of the token to reddem from collateral
    *   @param amountCollateral The amount of collateral to redeem
    */
    
    function redeedCollateral( address tokenCollateralAdress , uint256 amountCollateral) public moreThenZero(amountCollateral)  nonReentrant{
        s_collateralDeposited[msg.sender][tokenCollateralAdress] -= amountCollateral;
        emit CollateralRedeemed(msg.sender, tokenCollateralAdress, amountCollateral);
        bool success = IERC20(tokenCollateralAdress).transferFrom(msg.sender, address(this), amountCollateral);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
    }

    function mintDsc(uint256 amountDscToMint) public moreThenZero(amountDscToMint) {
        s_DSCMinted[msg.sender] += amountDscToMint;
        // if they minted too much ($150 DSC , $100 ETH)
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDsc(uint256 amount) public moreThenZero(amount) {
        s_DSCMinted[msg.sender] -= amount;
        bool burned = i_dsc.transferFrom(msg.sender, address(this), amount);
        if (!burned) {
            revert DSCEngine__BurnFailed();
        }
        i_dsc.burn(amount);
        _revertIfHealthFactorIsBroken(msg.sender); // i don't think this will be called
    }
    
   
    function liquidate() external {}
    function getHealthFactor() external view returns (uint256) {}

    //////////////////////////////////
    //  Private & Internal Functions
    ///////////////////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValueInUsd(user);
    }

    /*
    * Returns how close to liquidation a user is
    * if a user goes below , then they can get liquidated 
    */
    function _healthFector(address user) private view returns (uint256) {
        // total DSC minted
        // total collateral value
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        // $150 ETH / 100 DSC = 1.5
        // 150 *50 = 7500 / 100 = (75 / 100 )<1

        // $1000 ETH / 100 DSC
        // 1000 * 50 = 50000 / 100 = (500/100)>1

        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    // 1. Check health factor ( do they have enough collateral? )
    // 2. Revert if they don't

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 healthFactor = _healthFector(user);
        if (healthFactor < MIN_HEALTH_FECTOR) {
            revert DSCEngine__BreaksHealthFactor(healthFactor);
        }
    }

    //////////////////////////////////
    //  public  & external view Functions
    ///////////////////////////////////

    function getAccountCollateralValueInUsd(address user) public view returns (uint256 collateralValueInUsd) {
        // loop through each collateral token, get the amount they have deposited , and map it to
        // the price , geth the USD value
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            collateralValueInUsd += getUsdtUsdValue(token, amount);
        }

        return collateralValueInUsd;
    }

    function getUsdtUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
