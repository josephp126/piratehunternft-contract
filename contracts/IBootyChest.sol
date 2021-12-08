pragma solidity ^0.8.8;

// SPDX-License-Identifier: MIT

interface IBootyChest {
    function randomPirateOwner() external returns (address);
    function addTokensToStake(address account, uint16[] calldata tokenIds) external;
}
