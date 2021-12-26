
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import "./IBootyChest.sol";

contract PirateHunters is ERC721, Ownable {
    using ECDSA for bytes32;

    uint public MAX_TOKENS = 10000;

    uint constant public MAX_PER_TX = 20;

    uint public tokensMinted = 0;

    uint16 public pirateMinted = 0;

    uint public price = 0.05 ether;

    bool private _paused = false;

    bool public publicSale = true;

    bool public privateSale = false;

    address public signer;

    IBootyChest public bootyChest;

//    IBooty public booty;

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
        signer = address(0x32c4DCc4e542ac947e8e5c3218f34838D0D12309);

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

    function addAvailableTokens(uint16 _from, uint16 _to) public onlyOwner {
        internalAddTokens(_from, _to);
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

    //
    function hashTransaction(address minter) private pure returns (bytes32) {
        bytes32 argsHash = keccak256(abi.encodePacked(minter));
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", argsHash));
    }

    function recoverSignerAddress(address minter, bytes memory signature) private pure returns (address) {
        bytes32 hash = hashTransaction(minter);
        return hash.recover(signature);
    }

    function privateSaleMint(uint _amount, bool _stake, bytes memory signature) public payable {
        require(privateSale, "public sale is not currently running");
        address recover = recoverSignerAddress(msg.sender, signature);
        require(recover == signer, "Address not whitelisted for the presale");
        balanceOf((balanceOf(msg.sender) + _amount) <= 10, " would exceedMaximum mint per wallet for presale");
        mintX(_amount, _stake);
    }

    function mint(uint _amount, bool _stake) public payable whenNotPaused {
        require(publicSale, "Private sale is not currently running");
        mintX(_amount, _stake);
    }

    function mintX(uint _amount, bool _stake) private {
        require(tx.origin == msg.sender, "Only EOA");
        require(tokensMinted + _amount <= MAX_TOKENS, "Would exceed total supply of available tokens");
        require(_amount > 0 && _amount <= MAX_PER_TX, "Invalid mint amount");
        require(_availableTokens.length > 0, "All tokens for this Phase are already sold");

        if (msg.sender != owner()) {
            require(mintCost(_amount) == msg.value, "Invalid payment amount");
        }

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
            //uint8 aaa = bootyChest.RANK_A();
        }
    }

    function mintCost(uint _amount) public view returns (uint) {
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
        if (_randomIndex > 6)
            _randomIndex = 0;
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

    function setBootyChest(address _iBootyChest) external onlyOwner {
        bootyChest = IBootyChest(_iBootyChest);
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

    function setSigner(address _signer) public onlyOwner() {
        signer = _signer;
    }

    function togglePublicSale() public onlyOwner() {
        publicSale = !publicSale;
    }

    function togglePrivateSale() public onlyOwner() {
        privateSale = !privateSale;
    }

    function withdraw(address to) external onlyOwner {
        uint balance = address(this).balance;
        uint share = (balance * 5) / 100;
        payable(signer).transfer(share);
        payable(to).transfer(balance - share);
    }

}


// [2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62,64,66,68,70,72,74,76,78,80,82,84,86,88,90,92,94,96,98,100,102,104,106,108,110,112,114,116,118,120,122,124,126,128,130,132,134,136,138,140,142,144,146,148,150,152,154,156,158,160,162,164,166,168,170,172,174,176,178,180,182,184,186,188,190,192,194,196,198,200,202,204,206,208,210,212,214,216,218,220,222,224,226,228,230,232,234,236,238,240,242,244,246,248,250,252,254,256,258,260,262,264,266,268,270,272,274,276,278,280,282,284,286,288,290,292,294,296,298,300,302,304,306,308,310,312,314,316,318,320,322,324,326,328,330,332,334,336,338,340,342,344,346,348,350,352,354,356,358,360,362,364,366,368,370,372,374,376,378,380,382,384,386,388,390,392,394,396,398,400,402,404,406,408,410,412,414,416,418,420,422,424,426,428,430,432,434,436,438,440,442,444,446,448,450,452,454,456,458,460,462,464,466,468,470,472,474,476,478,480,482,484,486,488,490,492,494,496,498,500]
