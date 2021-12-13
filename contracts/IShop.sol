pragma solidity ^0.8.8;

// SPDX-License-Identifier: MIT

interface IShop {

    function getOffensive(uint16 tokenid) external view returns (uint); // for estimating
    function useOffensive(uint16 tokenid) external returns (uint);
    function getDefensive(uint16 tokenid) external view returns (uint); // for estimating
    function useDefensive(uint16 tokenid) external returns (uint);

}
