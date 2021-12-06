
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';


contract PirateHunters is ERC721Enumerable, Ownable {
    using Strings for uint256;


    constructor() ERC721 ("PirateHunters", "PH"){
        //setBaseURI(_initBaseURI);
    }
}
