// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GiftTest1 is ERC721, ERC721Burnable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _totalSupplyCounter;

    bytes32[50] public merkleRoots; // Having multiple roots for each group of allow lists

    mapping(address => uint256) public numberOfMints;
    mapping(address => uint256) public numberOfAllowance;


    string private hiddenMetadataUri;   // https://gateway.pinata.cloud/ipfs/QmcdnfcVrJDFX3pio2xTcG88Ry5VJG3SJoHK2jb7tsXTTd/                BEFORE-DEPLOY
    string private baseMetadataUri;     // https://gateway.pinata.cloud/ipfs/QmSSZrpJ9zXkWDmR6z6vBWzESG86WjdPos3nw3oFjZEYrn/hidden.json     BEFORE-DEPLOY

    uint256 public maxSupply = 666;
    uint256 public totalSupply;
    uint256 public mintPrice = 0.1 ether;

    bool public isWhitelistMintOpen = true;
    bool public isPublicMintOpen = false;
    bool public isRevealed = true;          // Start false, change it BEFORE-DEPLOY

    // >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< ><  >< >< >< >< >< >< >< >< >< >< >< >< >< >< ><

    constructor(string memory _baseMetadataUri, string memory _hiddenMetadataUri) 
        ERC721("GiftTest1", "GT1") {
            baseMetadataUri = _baseMetadataUri;
            hiddenMetadataUri = _hiddenMetadataUri;            
            _tokenIdCounter.increment();    // The collection starts from 1
    }

    modifier mintCompliance(uint256 _mintAmount) {
        require(_mintAmount > 0, 'Invalid mint amount!');
        require(totalSupply + _mintAmount <= maxSupply, 'Max supply exceeded!');
        _;
    }

    // >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< >< ><  >< >< >< >< >< >< >< >< >< >< >< >< >< >< ><

    function _baseURI() internal view override returns (string memory) {
        return baseMetadataUri;
    }

    function baseURI() public view returns (string memory) {
        if (isRevealed){
            return baseMetadataUri;
        }
        else {
            return hiddenMetadataUri;
        }
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory){        
        require(_exists(_tokenId), 'ERC721Metadata: URI query for nonexistent token');

        if (!isRevealed){
            return hiddenMetadataUri;
        }
        
        return super.tokenURI(_tokenId);
    }

    function publicMint(uint256 _mintAmount) public payable mintCompliance(_mintAmount){
        require(msg.value >= mintPrice * _mintAmount);

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(_msgSender());
        }
    }

    function whitelistMint(uint256 _mintAmount, bytes32[] calldata _merkleProof) public mintCompliance(_mintAmount) returns (uint256){
        // Verify whitelist requirements
        require(isWhitelistMintOpen, "The whitelist sale is not enabled!");    
        require((merkleCheck(_merkleProof)), "The address is not whitelisted!");

        // Check if it is exceeding the allowance
        require((numberOfMints[_msgSender()] + _mintAmount <= numberOfAllowance[_msgSender()]), "The number of allowance is exceeded!");

        numberOfMints[_msgSender()] += _mintAmount;
        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(_msgSender());
        }

        return numberOfAllowance[_msgSender()] - numberOfMints[_msgSender()];
    }

    /*
        @dev increase tokenID and total supply before mint
    */
    function _safeMint(address to) internal virtual {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        totalSupply++;
        _totalSupplyCounter.increment();

        super._safeMint(to, tokenId);
    }

    function remainingAllowance(bytes32[] calldata _merkleProof) public returns (uint256) {        
        require((merkleCheck(_merkleProof)), "The address is not whitelisted!");

        return numberOfAllowance[_msgSender()] - numberOfMints[_msgSender()];
    }

    function merkleCheck (bytes32[] calldata _merkleProof) internal returns (bool) {
        bool isWhitelisted = false;
        bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
        
        // if the address has no allowance record, check the roots
        if (numberOfAllowance[_msgSender()] == 0){
            for (uint256 i = 0; i < merkleRoots.length; i++){
                // If the proof valid for this index, give the index number as allowance number
                if (MerkleProof.verify(_merkleProof, merkleRoots[i], leaf)){
                    numberOfAllowance[_msgSender()] = i;
                    isWhitelisted = true;
                    break;
                }
            }
        }
        else { // if address already has a allowance record
            isWhitelisted = true;
        }

        return isWhitelisted;
    }
        

    /*  ->->->->->->->->->->        ADMIN FUNCTIONS         ->->->->->->->->->->
                                                           .------.------.    
            +-------------+                                |      |      |    
            |             |                                |      |      |    
            |             |        _           ____        |      |      |    
            |             |     ___))         [  | \___    |      |      |    
            |             |     ) //o          | |     \   |      |      |    
            |             |  _ (_    >         | |      ]  |      |      |    
            |          __ | (O)  \__<          | | ____/   '------'------'    
            |         /  o| [/] /   \)        [__|/_                          
            |             | [\]|  ( \         __/___\_____                    
            |             | [/]|   \ \__  ___|            |                   
            |             | [\]|    \___E/%%/|____________|_____              
            |             | [/]|=====__   (_____________________)             
            |             | [\] \_____ \    |                  |              
            |             | [/========\ |   |                  |              
            |             | [\]     []| |   |                  |              
            |             | [/]     []| |_  |                  |              
            |             | [\]     []|___) |                  |    MEPH          
            ====================================================================
    */    
    function setWhitelistMintOpen(bool _state) public onlyOwner {
        isWhitelistMintOpen = _state;
    }

    function setPublicMintOpen(bool _state) public onlyOwner {
        isPublicMintOpen = _state;
    }

    function setRevealed(bool _state) public onlyOwner {
        isRevealed = _state;
    }

    function setBaseMetadataUri(string memory _baseMetadataUri) public onlyOwner {
        hiddenMetadataUri = _baseMetadataUri;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setMerkleRootArray(bytes32 _merkleRoot, uint256 _rootIndex) public onlyOwner {
        merkleRoots[_rootIndex] = _merkleRoot;
    }

    function withdraw() public payable onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }
}
