// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ItamERC20 is ERC20, Ownable {
    constructor(string memory name, string memory symbol)
        public
        ERC20(name, symbol)
    {}

    mapping(address => bool) public blackLists;

    function transfer(address _to, uint256 _value) public override onlyNotBlackList returns (bool)  {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public override onlyNotBlackList returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

    function approve(address spender, uint256 value) public override onlyNotBlackList returns (bool) {
        return super.approve(spender, value);
    }

    function mint(address to, uint256 value) external onlyOwner {
        super._mint(to, value);
    }

    function burn(address to, uint256 value) external onlyOwner {
        super._burn(to, value);
    }

    function addToBlackList(address _to) public onlyOwner {
        require(!blackLists[_to], "Token: already blacklist");
        blackLists[_to] = true;
    }
    
    function removeFromBlackList(address _to) public onlyOwner {
        require(blackLists[_to], "Token: cannot found this address from blacklist");
        blackLists[_to] = false;
    }

    modifier onlyNotBlackList {
        require(!blackLists[msg.sender], "Token: sender cannot call this contract");
        _;
    }
}
