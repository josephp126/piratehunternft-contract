pragma solidity ^0.8.10;

// SPDX-License-Identifier: MIT

interface IBooty {
  function mint(address to, uint256 amount) external;
  function burn(address from, uint256 amount) external;
}