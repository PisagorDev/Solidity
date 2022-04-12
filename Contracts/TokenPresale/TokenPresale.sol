// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../utils/access/Access.sol";

/*
   --> @title Token Presale Contract <--
    This contract allows you to sell the 
    token you want for the token you want.
*/

contract TokenSale is Access{

    //  @author Pisagor
    //  https://t.me/P1S4G0R

    // @dev Presale contract for Tokens                      

    using SafeMath for uint;

    struct Token{
        uint price;
        uint whiteListTime;
        uint allTime;
        uint maxTokenSale;
        uint totalSold;
        bool status;
    }

    // Address to which sales revenues are sent
    address payable public SALE_OWNER;

    // An address buy max 10 (1e19) token
    uint private MAX_AMOUNT_PER_ADDRESS = 10 ether;

    // Token price with main token of chain
    uint private TOKEN_PRICE_FOR_ETHER = 1 ether;

    // Sale'll start for all addresses
    uint private SALE_START_TIME_WITH_ETHER_FOR_ALL = 0;

    // Sale'll start for only addresses in whitelist
    uint private SALE_START_TIME_WITH_ETHER_FOR_WHITELIST = 0;

    // How many tokens were sold
    uint public totalSold;
    uint public totalSoldWithEther;
    
    // How many tokens will sale
    uint public maxTokenSale;
    uint public maxTokenSaleWithEther;

    constructor(address payable saleOwner, address admin) Access(admin) public {
        SALE_OWNER = saleOwner;
    }
    
    // Indicates how many tokens the address has bought
    mapping(address=>uint) private totalAmountByUser;
    mapping(address=>bool) private inWhiteList;
    mapping(address => bool) private isTokenExist;
    mapping(IERC20Metadata=>Token) public tokenByAddress;


    /* ======== EVENTS ======== */

    event Bought(address indexed user, uint amount, uint time, address indexed token);
    event WhitelistSet(address indexed dev, address indexed user, bool status);
    event WhitelistSetBulk(address indexed dev, address[] users);
    event TokenSet(address indexed dev, IERC20Metadata token, uint price, uint whiteListTime, uint allTime, uint tokenInSale, uint totalSold, bool status);
    event TokenStatusSet(address indexed admin, bool status);
    event TokenEtherPriceSet(address indexed dev, uint price);
    event TokenSaleWithEtherStartTimeForAllSet(address indexed dev, uint time);
    event TokenSaleWithEtherStartTimeForWhitelistSet(address indexed dev, uint time);
    event TokenInSaleWithEtherSet(address indexed admin, uint amount);
    event SaleOwnerSet(address indexed admin, address indexed newOwner);
    event MaxAmountSet(address indexed admin, uint amount);

    /* ======== VIEW FUNCTIONS ======== */

    function getUserTotalBoughtAmount(address user) public view returns(uint){
        require(user != address(0), "User can not be zero address");
        return totalAmountByUser[user];
    }

    function whitelistQuery(address user) public view returns(bool){
        require(user != address(0), "User can not be zero address");
        return inWhiteList[user];
    }

    function getTokenSaleWithEtherStartTimeForAll() public view returns(uint){
        return SALE_START_TIME_WITH_ETHER_FOR_ALL;
    }

    function setTokenSaleWithEtherStartTimeForWhitelist() public view returns(uint){
        return SALE_START_TIME_WITH_ETHER_FOR_WHITELIST;
    }
    function getMaxTokenAmountPerAddress() public view returns(uint){
        return MAX_AMOUNT_PER_ADDRESS;
    }

    /* ======== GOVERNANCE ======== */

    function setSaleOwner(address payable newOwner) external onlyAdmin{
        require(newOwner != address(0) && newOwner != SALE_OWNER);

        SALE_OWNER = newOwner;
        emit SaleOwnerSet(msg.sender, SALE_OWNER);
    }

    function setMaxTokenAmountPerAddress(uint amount) external onlyAdmin{
        MAX_AMOUNT_PER_ADDRESS = amount;
        emit MaxAmountSet(msg.sender, MAX_AMOUNT_PER_ADDRESS);
    }

    function setTokenEtherPrice(uint _price) external onlyAdmin{
        TOKEN_PRICE_FOR_ETHER = _price;
        emit TokenEtherPriceSet(msg.sender, _price);
    }

    function setTokenInSaleWithEther(uint _amount) external onlyAdmin{
        require(_amount >= maxTokenSaleWithEther, "_amount can not less than");
        maxTokenSale = maxTokenSale.sub(maxTokenSaleWithEther).add(_amount);
        maxTokenSaleWithEther = _amount;
        emit TokenInSaleWithEtherSet(msg.sender, _amount);
    }

    function setTokenSaleWithEtherStartTimeForAll(uint _time) external onlyAdmin{
        SALE_START_TIME_WITH_ETHER_FOR_ALL = _time;
        emit TokenSaleWithEtherStartTimeForAllSet(msg.sender, _time);
    }

    function setTokenSaleWithEtherStartTimeForWhitelist(uint _time) external onlyAdmin{
        SALE_START_TIME_WITH_ETHER_FOR_WHITELIST = _time;
        emit TokenSaleWithEtherStartTimeForWhitelistSet(msg.sender, _time);
    }

    function setWhitelist(address user, bool status) external onlyDev{
        inWhiteList[user] = status;
        emit WhitelistSet(msg.sender, user, status);
    }

    function setWhitelistBulk(address[] memory users) external onlyDev{
        for(uint i = 0; i < users.length; i++){
            inWhiteList[users[i]] = true;
        }
        emit WhitelistSetBulk(msg.sender, users);
    }

    function setToken(IERC20Metadata _token, uint _price, uint _whiteListTime, uint _allTime, uint _maxTokenSale, bool _status) external onlyAdmin{
        require(address(_token) != address(0), "Token address can not be zero address");
        uint _totalSold = isTokenExist[address(_token)] ? tokenByAddress[_token].totalSold : 0;
        if(isTokenExist[address(_token)]){
            isTokenExist[address(_token)] = true;
        }
        tokenByAddress[_token] = Token(_price, _whiteListTime, _allTime, _maxTokenSale, _totalSold, _status);
        maxTokenSale = maxTokenSale.add(_maxTokenSale);
        emit TokenSet(msg.sender, _token, _price, _whiteListTime, _allTime, _maxTokenSale, _totalSold, _status);
    }

    function setTokenStatus(IERC20Metadata _token, bool _status) external onlyDev {
        tokenByAddress[_token].status = _status;
        emit TokenStatusSet(msg.sender, _status);
    }

    /* ======== BUY FUNCTIONS ======== */

    function buyWithToken(IERC20Metadata _token, uint amount) external {

        Token storage token = tokenByAddress[_token];
        uint time = inWhiteList[msg.sender] ? token.whiteListTime : token.allTime;
        uint userTotalAmount = totalAmountByUser[msg.sender];
    
        require(token.totalSold.add(amount) <= token.maxTokenSale, "Amount is to high");
        require(block.timestamp >= time, "Sale did not start yet.");
        require(userTotalAmount.add(amount) <= MAX_AMOUNT_PER_ADDRESS, "Can not buy more.");
        require(_token.balanceOf(msg.sender) >= amount.mul(token.price).div(10**_token.decimals()), "You have enough money.");

        totalAmountByUser[msg.sender] = userTotalAmount.add(amount);

        _token.transferFrom(msg.sender, SALE_OWNER, amount.mul(token.price).div(10**_token.decimals()));

        totalSold = totalSold.add(amount);
        token.totalSold = token.totalSold.add(amount);

        emit Bought(msg.sender, amount, block.timestamp, address(_token));
    }

    function buyWithEther(uint amount) external payable {

        uint time = inWhiteList[msg.sender] ? SALE_START_TIME_WITH_ETHER_FOR_WHITELIST : SALE_START_TIME_WITH_ETHER_FOR_ALL;
        uint userTotalAmount = totalAmountByUser[msg.sender];

        require(totalSoldWithEther.add(amount) <= maxTokenSaleWithEther, "Amount is to high");
        require(block.timestamp >= time, "Sale did not start yet.");
        require(userTotalAmount.add(amount) <= MAX_AMOUNT_PER_ADDRESS, "Can not buy more.");
        require(msg.value >= amount.mul(TOKEN_PRICE_FOR_ETHER).div(1e18), "Do not have enough ethers");
        
        SALE_OWNER.transfer(amount.mul(TOKEN_PRICE_FOR_ETHER).div(1e18));

        totalAmountByUser[msg.sender] = userTotalAmount.add(amount);

        totalSold = totalSold.add(amount);
        totalSoldWithEther = totalSoldWithEther.add(amount);

        emit Bought(msg.sender, amount, block.timestamp, address(0));
    }
    
}
