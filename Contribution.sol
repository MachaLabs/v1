//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ERC1155Token is ERC1155URIStorage, Ownable {
    string public name;
    string public symbol;
    string public baseURI;
    string public baseExtension = ".json";

    using Counters for Counters.Counter;
    Counters.Counter private tokenId;

    mapping(uint256 => Token) public tokenIdToToken;
    mapping(uint256 => mapping(address => bool)) private tokenIdToAllowed;

    // Each token represent different cohort of buildspace
    struct Token {
        uint256 id;
        string name;
        bool limited;
        uint128 tokenLimit;
        uint128 tokenMinted;
        bool allowed;
        bool allowedListOnly;
        bool allowedTransfer;
        bool exists;
    }

    constructor(string memory _name, string memory _symbol, string memory _baseURI) ERC1155(_baseURI) {
        name = _name;
        symbol = _symbol;
        baseURI = _baseURI;
        // Already sets value for default _uri
    }

    /*------------------------------MODIFIERS-------------------------------*/

    modifier checkMinting(uint256 _tokenId) {
        // Check for _tokenId to exist in our mapping
        require (tokenIdToToken[_tokenId].exists, "Token do not exists");
        if (tokenIdToToken[_tokenId].limited) {
            require (
                tokenIdToToken[_tokenId].tokenMinted < tokenIdToToken[_tokenId].tokenLimit,
                "Max tokens issued"
            );
        }
        _;
    }

    modifier checkBalance(uint256 _tokenId, address _account) {
        require (balanceOf(_account, _tokenId)==0, "Token already minted");
        _;
    }

    modifier checkAllowed(uint256 _tokenId, address _account) {
        // check if tokenId exists in tokenIdToToken
        if (tokenIdToToken[_tokenId].allowed) {
            require (
                tokenIdToAllowed[_tokenId][_account] == true,
                "Account is not allowed"
            );
        }
        _;
    }

    /*------------------------------MINTING-------------------------------*/

    function createToken(string memory _name, string memory _tokenURI, bool _limited, uint128 _limit, bool _allowed, bool _allowedListOnly, bool _allowedTransfer) external onlyOwner returns (uint256) {
        require(
            !tokenIdToToken[tokenId.current()].exists,
            "Token already exists"
        );
        // ID, Name, Limited, Limit, Minted
        Token memory token = Token(tokenId.current(), _name, _limited, _limit, 0, _allowed, _allowedListOnly, _allowedTransfer, true);
        _setURI(tokenId.current(), _tokenURI);
        tokenIdToToken[tokenId.current()] = token;
        // Mint one token for the owner
        mintTokenItem(msg.sender, tokenId.current());
        // Incremement the tokenId for next token
        tokenId.increment();
        return token.id;
    }

    // Set token allowed list - owner

    function mintTokenItem(address to, uint256 _tokenId) public onlyOwner checkMinting(_tokenId) {
        _mint(to, _tokenId, 1, '');
        tokenIdToToken[_tokenId].tokenMinted += 1;
    }

    function batchMintTokenItem(address[] memory to, uint256 _tokenId) public onlyOwner {
        uint length = to.length;
        for (uint i = 0; i < length; i++) {
            mintTokenItem(to[i], _tokenId);
        }
    }


    // Mint by anyone 
    function mintTokenItemByAccount(uint256 _tokenId) public checkMinting(_tokenId) checkBalance(_tokenId, msg.sender) {
        require (tokenIdToToken[_tokenId].allowed, "Token Item Minting is not allowed");
        require (!tokenIdToToken[_tokenId].allowedListOnly || (tokenIdToToken[_tokenId].allowedListOnly && tokenIdToAllowed[_tokenId][msg.sender]), "Minting not allowed");
        _mint(msg.sender, _tokenId, 1, '');
        tokenIdToToken[_tokenId].tokenMinted += 1;
    }
    
    /*------------------------------SETTERS-------------------------------*/
    function setBaseUri(string memory _newURI) public onlyOwner {
        baseURI = _newURI;
    }

    function setTokenAllowed(uint256 _tokenId, bool _allowed) public onlyOwner {
        tokenIdToToken[_tokenId].allowed = _allowed;
    }

    function setTokenAllowedListOnly(uint256 _tokenId, bool _allowedListOnly) public onlyOwner {
        tokenIdToToken[_tokenId].allowedListOnly = _allowedListOnly;
    }

    function setTokenLimited(uint256 _tokenId, bool _limited) public onlyOwner {
        tokenIdToToken[_tokenId].limited = _limited;
    }

    function setTokenLimit(uint256 _tokenId, uint128 _limit) public onlyOwner {
        require (_limit > tokenIdToToken[_tokenId].tokenMinted);
        tokenIdToToken[_tokenId].tokenLimit = _limit;
    }

    function setTokenAllowedAccount(uint256 _tokenId, address _account, bool _allowed) public onlyOwner {
        tokenIdToAllowed[_tokenId][_account] = _allowed;
    }

    function setTokenAllowedTransfer(uint256 _tokenId, bool _allowedTransfer) public onlyOwner {
        tokenIdToToken[_tokenId].allowedTransfer = _allowedTransfer;
    }

    /*------------------------------GETTERS-------------------------------*/

    function tokenAllowed(uint256 _tokenId) public view returns (bool) {
        return tokenIdToToken[_tokenId].allowed;
    }

    function tokenAllowesListOnly(uint256 _tokenId) public view returns (bool) {
        return tokenIdToToken[_tokenId].allowedListOnly;
    }

    function tokenName(uint256 _tokenId) public view returns (string memory) {
        return tokenIdToToken[_tokenId].name;
    }

    function tokenLimited(uint256 _tokenId) public view returns (bool) {
        return tokenIdToToken[_tokenId].limited;
    }

    function tokenLimit(uint256 _tokenId) public view returns (uint128) {
        return tokenIdToToken[_tokenId].tokenLimit;
    }

    function tokenMinted(uint256 _tokenId) public view returns (uint128) {
        return tokenIdToToken[_tokenId].tokenMinted;
    }

    function tokenAccountAllowed(uint256 _tokenId, address _account) public view returns (bool) {
        return tokenIdToAllowed[_tokenId][_account];
    }
}