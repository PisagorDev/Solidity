// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Access{

    address public ADMIN;

    constructor(address admin) {
        ADMIN = admin;
    }

    mapping(address=>bool) public isDev;

    event AdminSet(address indexed previousAdmin, address indexed newAdmin);
    event DevSet(address indexed admin, address indexed dev, bool status);

    modifier onlyAdmin(){
        require(msg.sender == ADMIN, "message sender is not admin");
        _;
    }

    modifier onlyDev(){
        require(isDev[msg.sender] || msg.sender == ADMIN, "message sender is not developer or admin");
        _;
    }

    function setAdmin(address admin) external onlyAdmin{
        require(admin != address(0));
        ADMIN = admin;
        emit AdminSet(msg.sender, admin);
    }

    function setDev(address dev, bool status) external onlyAdmin{
        require(dev != address(0));
        isDev[dev] = status;
        emit DevSet(msg.sender, dev, status);
    }
}
