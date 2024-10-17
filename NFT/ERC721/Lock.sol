// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ERC721A.sol";

contract NFTERC721A is Ownable, ERC721A, PaymentSplitter {

    using Strings for uint;
    mapping(address => uint) public amountNFTsperWalletWhitelistSale;

    enum Step {
        WhitelistSale_Guaranteed,
        WhitelistSale_FCFS,
        PublicSale,
        SoldOut,
        Reveal
    }
    
    string public baseURI;

    Step public sellingStep;
    uint private constant MAX_SUPPLY = 10000;
    uint private constant MAX_WHITELIST_Guaranteed = 333;
    uint private constant MAX_WHITELIST_FCFS = 778;
    
    uint public MAX_PUBLIC = 6666;
    uint public MAX_PERIOD_SUPPLY_LIMIT = 0;
    uint public wlSalePrice = 0 ether;
    uint public publicSalePrice = 0 ether;
    
    uint public saleStartTime;
    uint public saleEndTime;
    uint public mintLimitPerBlock;
    uint public mintLimitPerSale;

    uint private teamLength;

    constructor(address[] memory _team, uint[] memory _teamShares, string memory _baseURI, uint _saleStartTime, uint _saleEndTime, uint _mintLimitPerBlock, uint _mintLimitPerSale, uint _quantityLimit) ERC721A("Mining Maze: Get a big treasure box!", "MM")
    PaymentSplitter(_team, _teamShares) {
        baseURI = _baseURI;
        teamLength = _team.length;
        saleStartTime = _saleStartTime;
        saleEndTime = _saleEndTime;
        mintLimitPerBlock = _mintLimitPerBlock;
        mintLimitPerSale = _mintLimitPerSale;
        MAX_PERIOD_SUPPLY_LIMIT = _quantityLimit;
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function mintingInformation() external view returns (uint256[3] memory){
        uint256[3] memory info =
            [saleStartTime, saleEndTime, mintLimitPerBlock];
        return info;
    }

    function whitelistMint_Guaranteed(address _account, uint _quantity) external payable callerIsUser {
        uint price = wlSalePrice;
        require(price == 0, "Price is not 0");

        require(_quantity == 1, "Guaranteed WL quantity is only 1");
        require(_quantity > 0 && _quantity <= mintLimitPerBlock, "Too many requests or zero request");

        require(currentTime() >= saleStartTime, "Whitelist Sale has yet to start");
        require(currentTime() < saleEndTime, "Whitelist Sale is finished");
        require(sellingStep == Step.WhitelistSale_Guaranteed, "Now whitelist sale is Guaranteed");

        require(amountNFTsperWalletWhitelistSale[msg.sender] + _quantity <= 1, "You can only get 1 NFT on the Guaranteed Whitelist Sale");

        require(totalSupply() + _quantity <= MAX_WHITELIST_Guaranteed, "Max supply exceeded");
        require(msg.value >= price * _quantity, "Not enough funds");
        
        amountNFTsperWalletWhitelistSale[msg.sender] += _quantity;
        _safeMint(_account, _quantity);
    }

    function whitelistMint_FCFS(address _account, uint _quantity) external payable callerIsUser {
        uint price = wlSalePrice;
        require(price == 0, "Price is not 0");

        require(_quantity == 1, "Only one quantity per transaction");
        require(_quantity > 0 && _quantity <= mintLimitPerBlock, "Too many requests or zero request");

        require(currentTime() >= saleStartTime, "Whitelist Sale has yet to start");
        require(currentTime() < saleEndTime, "Whitelist Sale is finished");
        require(sellingStep == Step.WhitelistSale_FCFS, "Now whitelist sale is FCFS");

        require(amountNFTsperWalletWhitelistSale[msg.sender] + _quantity <= mintLimitPerSale, "You can only get 3 NFTs on the FCFS Whitelist Sale");
        require(balanceOf(msg.sender) + _quantity <= mintLimitPerSale, "You can only get 3 NFTs on the Wallet on the FCFS Whitelist Sale");

        require(totalSupply() + _quantity <= MAX_WHITELIST_Guaranteed + MAX_WHITELIST_FCFS, "Max supply exceeded");
        require(msg.value >= price * _quantity, "Not enough funds");
        
        amountNFTsperWalletWhitelistSale[msg.sender] += _quantity;
        _safeMint(_account, _quantity);
    }

    function publicSaleMint(address _account, uint _quantity) external payable callerIsUser {
        uint price = publicSalePrice;
        require(price == 0, "Price is not 0");

        require(_quantity == 1, "Only one quantity per transaction");
        require(currentTime() >= saleStartTime, "Public Sale has not started yet");
        require(_quantity > 0 && _quantity <= mintLimitPerBlock, "Too many requests or zero request");

        require(currentTime() <= saleEndTime, "Public Sale is finished");
        require(sellingStep == Step.PublicSale, "Public sale is not activated");

       // require(amountNFTsperWalletWhitelistSale[msg.sender] + _quantity <= mintLimitPerSale, "You can only get 3 NFTs on Public Sale");

        require(totalSupply() + _quantity <= MAX_SUPPLY, "Max supply exceeded");
        require(totalSupply() + _quantity <= MAX_PERIOD_SUPPLY_LIMIT, "Max supply exceeded in this Public Sale period");
        require(msg.value >= price * _quantity, "Not enough funds");

        amountNFTsperWalletWhitelistSale[msg.sender] += _quantity;
        _safeMint(_account, _quantity);
    }

    function airDrop(address _to, uint _quantity) external onlyOwner {
        require(totalSupply() + _quantity <= MAX_SUPPLY, "Reached max Supply");
        require(totalSupply() + _quantity <= MAX_PERIOD_SUPPLY_LIMIT, "Reached max Supply");
        _safeMint(_to, _quantity);
    }

    function setUpMintInfo(uint _saleStartTime, uint _saleEndTime, uint _mintLimitPerBlock, uint _mintLimitPerSale) external onlyOwner {
        saleStartTime = _saleStartTime;
        saleEndTime = _saleEndTime;
        mintLimitPerBlock = _mintLimitPerBlock;
        mintLimitPerSale = _mintLimitPerSale;
    }

    function setBaseUri(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function setMaxPublicAmount(uint _quantity) external onlyOwner {
        MAX_PUBLIC = _quantity;
    }

    function setLimitAmount(uint _quantity) external onlyOwner {
        MAX_PERIOD_SUPPLY_LIMIT = _quantity;
    }

    function burnNFT(uint _tokenId) external onlyOwner {
        require(_tokenId <= MAX_SUPPLY, "Invalid token ID");
        require(_tokenId <= MAX_PERIOD_SUPPLY_LIMIT, "Invalid token ID");
        _burn(_tokenId);
    }

    function currentTime() internal view returns(uint) {
        return block.timestamp;
    }

    function currentBlock() internal view returns(uint) {
        return block.number;
    }

    function setStep(uint _step) external onlyOwner {
        sellingStep = Step(_step);
    }

    function tokenURI(uint _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "URI query for nonexistent token");

        return string(abi.encodePacked(baseURI, Strings.toString(_tokenId), ".json"));
    }

    //ReleaseALL
    function releaseAll() external onlyOwner {
        for(uint i = 0 ; i < teamLength ; i++) {
            release(payable(payee(i)));
        }
    }

    receive() override external payable {
        revert('Only if you mint');
    }

}