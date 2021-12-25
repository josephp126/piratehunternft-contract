pragma solidity ^0.8.8;

// SPDX-License-Identifier: MIT

interface IBootyChest {

    function RANK_A() external returns(uint8);
    function RANK_B() external returns(uint8);
    function RANK_C() external returns(uint8);

    function isOwnerOf(uint tokenId, address owner) external view returns (bool);
    function effectRankUp(uint tokenId, uint newRank) external;


//    function randomPirateOwner() external returns (address);
    function addTokensToStake(address account, uint16[] calldata tokenIds) external;
}
