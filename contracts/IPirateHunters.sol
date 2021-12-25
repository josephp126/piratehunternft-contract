// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.8;

interface IPirateHunters {

    function ownerOf(uint id) external view returns (address);
    function isPirate(uint16 id) external view returns (bool);
    function transferFrom(address from, address to, uint tokenId) external;
    function safeTransferFrom(address from, address to, uint tokenId, bytes memory _data) external;
}
