// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/*
 * @title DecentralizeStableCoin
 * @author Ruhul Amin
 * Collateral: Exogenouns (ETH &  BTC)
 * Minting: Algorithomic
 * Relative Stabiliaty: Pagged to USD
 *
 * This is the contract meant to be govened by DSCEngine.This contract is just the ERC20 implementation of our stableCoin system.
 */

contract DecentralizeStableCoin is ERC20Burnable, Ownable {
    error DecentralizeStableCoin_MustBeGreaterThanZero();
    error DecentralizeStableCoin_BurnExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();

    constructor() ERC20('ARStableCoin', 'AR') {}
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizeStableCoin_MustBeGreaterThanZero();
        }
        if (balance < _amount) {
            revert DecentralizeStableCoin_BurnExceedsBalance();
        }

        super.burn(_amount);
    }


      function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }

}
