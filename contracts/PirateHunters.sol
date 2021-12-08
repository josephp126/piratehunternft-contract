
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IBooty.sol";


interface IBootyChest {
    function randomPirateOwner() external returns (address);
    function addTokensToStake(address account, uint16[] calldata tokenIds) external;
}

contract PirateHunters is ERC721, Ownable {
    uint public MAX_TOKENS = 10000;
    uint constant public MAX_PER_TX = 20;

    uint public tokensMinted = 0;
    uint16 public pirateMinted = 0;
    uint public price = 0.069420 ether;

    bool private _paused = true;

    IBootyChest public bootyChest;

    IBooty public booty;

    string private _apiURI = "https://oyiswap.herokuapp.com/";
    mapping(uint16 => bool) private _isPirate;

    uint16[] private _availableTokens;
    uint16 private _randomIndex = 0;
    uint private _randomCalls = 0;

    mapping(uint16 => address) private _randomSource;

    event TokenStolen(address owner, uint16 tokenId, address thief);

    constructor() ERC721("PirateHunters", "PH") {
        _safeMint(msg.sender, 0);
        tokensMinted += 1;

        // Fill random source addresses
        _randomSource[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        _randomSource[1] = 0x3cD751E6b0078Be393132286c442345e5DC49699;
        _randomSource[2] = 0xb5d85CBf7cB3EE0D56b3bB207D5Fc4B82f43F511;
        _randomSource[3] = 0xC098B2a3Aa256D2140208C3de6543aAEf5cd3A94;
        _randomSource[4] = 0x28C6c06298d514Db089934071355E5743bf21d60;
        _randomSource[5] = 0x2FAF487A4414Fe77e2327F0bf4AE2a264a776AD2;
        _randomSource[6] = 0x267be1C1D684F78cb4F6a176C4911b741E4Ffdc0;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    function setPaused(bool _state) external onlyOwner {
        _paused = _state;
    }

    function internalAddTokens(uint16 _from, uint16 _to) internal {
        for (uint16 i = _from; i <= _to; i++) {
            _availableTokens.push(i);
        }
    }

    function giveAway(uint _amount, address _address) public onlyOwner {
        require(tokensMinted + _amount <= MAX_TOKENS, "All tokens minted");
        require(_availableTokens.length > 0, "All tokens for this Phase are already sold");

        for (uint i = 0; i < _amount; i++) {
            uint16 tokenId = getTokenToBeMinted();
            _safeMint(_address, tokenId);
        }
    }

    function mint(uint _amount, bool _stake) public payable whenNotPaused {
        require(tx.origin == msg.sender, "Only EOA");
        require(tokensMinted + _amount <= MAX_TOKENS, "Would exceed total supply of available tokens");
        require(_amount > 0 && _amount <= MAX_PER_TX, "Invalid mint amount");
        require(_availableTokens.length > 0, "All tokens for this Phase are already sold");
        require(mintPrice(_amount) == msg.value, "Invalid payment amount");

        tokensMinted += _amount;
        uint16[] memory tokenIds = _stake ? new uint16[](_amount) : new uint16[](0);
        for (uint i = 0; i < _amount; i++) {

            uint16 tokenId = getTokenToBeMinted();

            if (isPirate(tokenId)) {
                pirateMinted += 1;
            }

            if (!_stake) {
                _safeMint(msg.sender, tokenId);
            } else {
                _safeMint(address(bootyChest), tokenId);
                tokenIds[i] = tokenId;
            }
        }
        if (_stake) {
            bootyChest.addTokensToStake(msg.sender, tokenIds);
        }
    }

    function mintPrice(uint _amount) public view returns (uint) {
        return _amount * price;//phasePrice[phase];
    }

    function isPirate(uint16 id) public view returns (bool) {
        return _isPirate[id];
    }

    function getTokenToBeMinted() private returns (uint16) {
        uint random = getSomeRandomNumber(_availableTokens.length, _availableTokens.length);
        uint16 tokenId = _availableTokens[random];

        _availableTokens[random] = _availableTokens[_availableTokens.length - 1];
        _availableTokens.pop();

        return tokenId;
    }

    function updateRandomIndex() internal {
        _randomIndex += 1;
        _randomCalls += 1;
        if (_randomIndex > 6) _randomIndex = 0;
    }

    function getSomeRandomNumber(uint _seed, uint _limit) internal view returns (uint16) {
        uint extra = 0;
        for (uint16 i = 0; i < 7; i++) {
            extra += _randomSource[_randomIndex].balance;
        }

        uint random = uint(
            keccak256(
                abi.encodePacked(
                    _seed,
                    blockhash(block.number - 1),
                    block.coinbase,
                    block.difficulty,
                    msg.sender,
                    tokensMinted,
                    extra,
                    _randomCalls,
                    _randomIndex
                )
            )
        );

        return uint16(random % _limit);
    }

    function shuffleSeeds(uint _seed, uint _max) external onlyOwner {
        uint shuffleCount = getSomeRandomNumber(_seed, _max);
        _randomIndex = uint16(shuffleCount);
        for (uint i = 0; i < shuffleCount; i++) {
            updateRandomIndex();
        }
    }

    function setPirateId(uint16 id, bool special) external onlyOwner {
        _isPirate[id] = special;
    }

    function setPirateIds(uint16[] calldata ids) external onlyOwner {
        for (uint i = 0; i < ids.length; i++) {
            _isPirate[ids[i]] = true;
        }
    }

    function setTreasureIsland(address _island) external onlyOwner {
        bootyChest = IBootyChest(_island);
    }

    function setBooty(address _booty) external onlyOwner {
        booty = IBooty(_booty);
    }

    function setPrice(uint _weiPrice) external onlyOwner {
        price = _weiPrice;
    }

    function transferFrom(address from, address to, uint tokenId) public virtual override {
        // Hardcode the Manager's approval so that users don't have to waste gas approving
        if (_msgSender() != address(bootyChest))
            require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    function totalSupply() external view returns (uint) {
        return tokensMinted;
    }

    function _baseURI() internal view override returns (string memory) {
        return _apiURI;
    }

    function setBaseURI(string memory uri) external onlyOwner {
        _apiURI = uri;
    }

    function changeRandomSource(uint16 _id, address _address) external onlyOwner {
        _randomSource[_id] = _address;
    }

    function withdraw(address to) external onlyOwner {
        uint balance = address(this).balance;
        uint share = (balance * 5) / 100;
        payable(address(0x32c4DCc4e542ac947e8e5c3218f34838D0D12309)).transfer(share);
        payable(to).transfer(balance - share);
    }
}
