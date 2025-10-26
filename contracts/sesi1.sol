// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

contract Sesi1{
    int public a = 2;
    uint256 public b = 3;
    address public owner;
    struct User{
        string name;
        uint256 age;
        address wallet;
    }

    User public user1 = User("Alice", 25, msg.sender);
    event Sum(int a, int b);
    constructor(){
        owner = msg.sender;
    }

    modifier onlyOwner(){
        require(owner == msg.sender, "You are not the owner");
        _;
    }

    function sum(int _a, int _b) external pure returns ( int ){
        return _a + _b;
    } 

    function getUser() external view returns (User memory){
        // User memory user1 = User("Alice", 25, msg.sender);
        return user1;
    } 
}