pragma solidity ^ 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MilkToken is ERC20{

    //treasury address to be given on contract creation
	address public treasury;
	//rewards contract address
	address public dairyFarm;
	//lp address
	address public lp;
    //max allowed tokens transferable per transaction
	uint private transferLimit;
	//balance limit
	uint private balanceLimit;

    constructor(
		string memory name, 
		string memory symbol, 
		uint256 initialSupply, 
		address _treasury, 
		address _dairyFarm,
		address _lp,
		uint256 _balanceLimit,
		uint256 _transferLimit
	) ERC20(name, symbol) {
		treasury = _treasury;
		dairyFarm = _dairyFarm;
		lp = _lp;
        _mint(_treasury, initialSupply * 1e18);
		transferLimit = _transferLimit * 1e18;
		balanceLimit = _balanceLimit * 1e18;
    }

    //set a new transfer limit, allowed only to be sent from treasury address
	function setTranferLimit(uint _limit) public{
    	require(msg.sender == treasury, 'You must be the treasury to run this.');
    	transferLimit = _limit * 1e18;
  	}

	function setBalanceLimit(uint _limit) public{
    	require(msg.sender == treasury, 'You must be the treasury to run this.');
    	balanceLimit = _limit * 1e18;
  	}

	function setLpAddress(address _lp) public{
    	require(msg.sender == treasury, 'You must be the treasury to run this.');
    	lp = _lp;
  	}

    //transfer functions check if the amount we want to send is equal or below the limit
	function transferFrom(address sender, address recipient, uint256 amount) public override(ERC20) returns (bool) {
		if(msg.sender != treasury) {
			require(amount <= transferLimit, 'This transfer exceeds the allowed limit!');
		}
		if(msg.sender != treasury && recipient != dairyFarm && recipient != treasury && recipient != lp) {
			uint256 futureBalance = balanceOf(recipient) + amount;
			require(futureBalance <= balanceLimit);
		}
    	return super.transferFrom(sender, recipient, amount);
  	}

  	function transfer(address recipient, uint256 amount) public override(ERC20) returns (bool) {
		if(msg.sender != treasury) {
			require(amount <= transferLimit, 'This transfer exceeds the allowed limit!');
		}
		if(msg.sender != treasury && recipient != dairyFarm && recipient != treasury && recipient != lp) {
			uint256 futureBalance = balanceOf(recipient) + amount;
			require(futureBalance <= balanceLimit);
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
