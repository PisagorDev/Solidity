// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

error AuthorizationError();
error ZeroError();





abstract contract BattleMancersOperatorAccess {

    address public operator;

    constructor(address _operator) {
        operator = _operator;
    }

    event OperatorSet(address indexed operator);

    modifier onlyOperator{
        if(msg.sender != operator) revert AuthorizationError();
        _;
    }

    function setOperator(address _operator) external onlyOperator{
        if(_operator == address(0)) revert ZeroError();
        operator = _operator;
        emit OperatorSet(_operator);
    }

}

abstract contract BattleMancersModeratorAccess is BattleMancersOperatorAccess{

    constructor(address _operator) BattleMancersOperatorAccess(_operator) {}

    mapping(address => bool) private moderator;

    event ModeratorSet(address indexed moderator, bool status);
    
    modifier onlyModerator{
        if(msg.sender != operator || moderator[msg.sender]) revert AuthorizationError();
        _;
    }

    function setModerator(address _moderator,bool _status) external onlyOperator{
        if(_moderator == address(0)) revert ZeroError();
        moderator[_moderator] = _status;
        emit ModeratorSet(_moderator, _status);
    }
}

contract BattleMancers is ERC721A, BattleMancersModeratorAccess, ReentrancyGuard {


    using SafeMath for uint256;
    address payable public SELLER = payable(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
    uint256 public PRICE = 0.077 ether;
    uint256 public DEFAULT_MAX_MINT =  2;
    uint256 public whitelistMintTime;
    uint256 public publicMintTime;

    constructor(address _operator) BattleMancersModeratorAccess(_operator) ERC721A("BattleMancers", "BM") {}

    event DefaultMaxMintQuantitySet(uint256 quantity);
    event Mint(address indexed to, uint256 quantity);

    mapping(address => bool) private whitelist;
    mapping(address => uint256) private maxMintQuantity;
    mapping(address => uint256) private mintedQuantity;
    mapping(uint256 => bool) private lock;
    function getLock(uint256 id) public view returns(bool){
        return lock[id];
    }
    function getMaxQuantity(address _user) public view returns(uint256 _maxQuantity){
        _maxQuantity = maxMintQuantity[_user] > DEFAULT_MAX_MINT ? maxMintQuantity[_user] : DEFAULT_MAX_MINT;
    }

    function setMaxMintQuantity(address user, uint256 quantity) external onlyModerator{
        maxMintQuantity[user] = quantity;
    }
    function getRemainingQuantity(address _user) public view returns(uint256){
        return getMaxQuantity(_user).sub(mintedQuantity[_user]);
    }
    function setDefaultMaxMintQuantity(uint256 _maxMint) external onlyModerator{
        DEFAULT_MAX_MINT = _maxMint;
        emit DefaultMaxMintQuantitySet(_maxMint);
    }
    function setWhitelist(address[] calldata _list) external onlyModerator{
        uint256 _len = _list.length;
        for(uint256 i = 0; i < _len; i++){
            whitelist[_list[i]] = true;
        }
    }
    function removeWhitelist(address[] calldata _list) external onlyModerator{
        uint256 _len = _list.length;
        for(uint256 i = 0; i < _len; i++){
            whitelist[_list[i]] = false;
        }
    }
    function publicMint(uint256 quantity) external payable{
        require(block.timestamp >= publicMintTime);
        address _sender = msg.sender;
        uint256 remaining = getRemainingQuantity(_sender);
        quantity = quantity > remaining ? remaining : quantity;
        
        (bool success, bytes memory data) = SELLER.call{value: quantity.mul(PRICE)}("");
        require(success, "Failed to send Ether");

        _mint(_sender, quantity);

        emit Mint(_sender, quantity);
    }
    function whitelistMint(uint256 quantity) external payable{
        address _sender = msg.sender;
        require(whitelist[_sender]);
        require(block.timestamp >= whitelistMintTime);
        uint256 remaining = getRemainingQuantity(_sender);
        quantity = quantity > remaining ? remaining : quantity;
        
        (bool success, bytes memory data) = SELLER.call{value: quantity.mul(PRICE)}("");
        require(success, "Failed to send Ether");

        _mint(_sender, quantity);

        emit Mint(_sender, quantity);
    }
    function setTransferLock(uint256 id, bool status) external onlyModerator{
        lock[id] = status;
    }
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override{
        require(!getLock(startTokenId), "Banned!");
    }
}
