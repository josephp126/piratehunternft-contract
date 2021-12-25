pragma solidity ^0.8.8;

// SPDX-License-Identifier: MIT

interface IBooty {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function balanceOf(address owner) external view returns (uint);
}
