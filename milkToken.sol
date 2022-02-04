pragma solidity ^ 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MilkToken is ERC20{

    //treasury address to be given on contract creation
	address public treasury;
    //max allowed tokens transferable per transaction
	uint private limit;

    constructor(
		string memory name, 
		string memory symbol, 
		uint256 initialSupply, 
		address _treasury, 
		uint256 _limit
	) ERC20(name, symbol) {
		treasury = _treasury;
        _mint(_treasury, initialSupply * 1e18);
		limit = _limit * 1e18;
    }

    //set a new transfer limit, allowed only to be sent from treasury address
	function setTranferLimit(uint _limit) public{
    	require(msg.sender == treasury, 'You must be the treasury to run this.');
    	limit = _limit * 1e18;
  	}

    //transfer functions check if the amount we want to send is equal or below the limit
	function transferFrom(address sender, address recipient, uint256 amount) public override(ERC20) returns (bool) {
		if(msg.sender != treasury) {
			require(amount <= limit, 'This transfer exceeds the allowed limit!');
		}
    	return super.transferFrom(sender, recipient, amount);
  	}

  	function transfer(address recipient, uint256 amount) public override(ERC20) returns (bool) {
		if(msg.sender != treasury) {
			require(amount <= limit, 'This transfer exceeds the allowed limit!');
		}
    	return super.transfer(recipient, amount);
  	}

    //mint allowed to be sent only from treasury address, and mints to treasury address
  	function mint(uint256 _amount) public {
    	require(msg.sender == treasury, 'Can only be used by Dairy.Money Treasury');
    	_mint(msg.sender, _amount * 1e18);
  	}

    //burn tokens from treasury address, can be sent only from treasury address
  	function burn(uint256 _amount) public {
    	require(msg.sender == treasury, 'Can only be used by Dairy.Money Treasury');
    	_burn(msg.sender, _amount * 1e18);
  	}

}