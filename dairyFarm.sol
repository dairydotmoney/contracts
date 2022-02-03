pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract dairyFarm is Ownable {
    // emit payment events
    event IERC20TransferEvent(IERC20 indexed token, address to, uint256 amount);
    event IERC20TransferFromEvent(IERC20 indexed token, address from, address to, uint256 amount);


    //variables
    IERC20 public milk;
    IERC20 public usdc;

    address public pair;
    address public treasury;
    address public dev;

    uint256 public dailyInterest;
    uint256 public nodeCost;
    uint256 public nodeBase;
    uint256 public bondDiscount;

    uint256 public claimTaxMilk = 3;
    uint256 public claimTaxBond = 8;
    uint256 public treasuryShare = 2;
    uint256 public devShare = 1;

    bool public isLive = false;
    uint256 totalNodes = 0;

    //Array
    address [] public farmersAddresses;

    //Farmers Struct
    struct Farmer {
        bool exists;
        uint256 milkNodes;
        uint256 bondNodes;
        uint256 claimsMilk;
        uint256 claimsBond;
        uint256 lastUpdate;
    }

    //mappings
    mapping(address => Farmer) public farmers;

    //constructor
    constructor (
        address _milk, //address of a standard erc20 to use in the platform
        address _usdc, //address of an erc20 stablecoin
        address _pair, //address of potential liquidity pool 
        address _treasury, //address of a trasury wallet to hold fees and taxes
        address _dev, //address of developer
        uint256 _dailyInterest,
        uint256 _nodeCost,
        uint256 _nodeBase,
        uint256 _bondDiscount
    ) {
        milk = IERC20(_milk);
        usdc = IERC20(_usdc);
        pair = _pair;
        treasury = _treasury;
        dev = _dev;
        dailyInterest = _dailyInterest;
        nodeCost = _nodeCost * 1e18;
        nodeBase = _nodeBase * 1e18;
        bondDiscount = _bondDiscount;
    }

    //Price Checking Functions
    function getMilkBalance() external view returns (uint256) {
	return milk.balanceOf(pair);
    }

    function getUSDCBalance() external view returns (uint256) {
	return usdc.balanceOf(pair);
    }

    function getPrice() public view returns (uint256) {
        uint256 milkBalance = milk.balanceOf(pair);
        uint256 usdcBalance = usdc.balanceOf(pair);
        require(milkBalance > 0, "divison by zero error");
        uint256 price = usdcBalance * 1e30 / milkBalance;
        return price;
    }

    //Bond Setup
    function setBondCost() public view returns (uint256) {
        uint256 tokenPrice = getPrice();
        uint256 basePrice = nodeCost / 1e18 * tokenPrice / 1e12;
        uint256 discount = 100 - bondDiscount;
        uint256 bondPrice = basePrice * discount / 100;
        return bondPrice;
    }

    function setBondDiscount(uint256 newDiscount) public onlyOwner {
        require(newDiscount <= 25, "Discount above limit");
        bondDiscount = newDiscount;
    }

    //Set Addresses
    function setTokenAddr(address tokenAddress) public {
        require(msg.sender == treasury, 'Can only be used by Dairy.Money Treasury');
        milk = IERC20(tokenAddress);
    }

    function setUSDCAddr(address tokenAddress) public {
        require(msg.sender == treasury, 'Can only be used by Dairy.Money Treasury');
        usdc = IERC20(tokenAddress);
    }

    function setPairAddr(address pairAddress) public {
        require(msg.sender == treasury, 'Can only be used by Dairy.Money Treasury');
        pair = pairAddress;
    }

    function setTreasuryAddr(address treasuryAddress) public {
        require(msg.sender == treasury, 'Can only be used by Dairy.Money Treasury');
        treasury = treasuryAddress;
    }

    //Platform Settings
    function setPlatformState(bool _isLive) public {
        require(msg.sender == treasury, 'Can only be used by Dairy.Money Treasury');
        isLive = _isLive;
    }

    function setTreasuryShare(uint256 _treasuryShare) public {
        require(msg.sender == treasury, 'Can only be used by Dairy.Money Treasury');
        treasuryShare = _treasuryShare;
    }

    function setDevShare(uint256 _devShare) public {
        require(msg.sender == treasury, 'Can only be used by Dairy.Money Treasury');
        devShare = _devShare;
    }

    function setMilkTax(uint256 _claimTaxMilk) public onlyOwner {
        claimTaxMilk = _claimTaxMilk;
    }

    function setBondTax(uint256 _claimTaxBond) public onlyOwner {
        claimTaxBond = _claimTaxBond;
    }

    function setDailyInterest(uint256 newInterest) public onlyOwner {
        updateAllClaims();
        dailyInterest = newInterest;
    }

    function updateAllClaims() internal {
        uint256 i;
        for(i=0; i<farmersAddresses.length; i++){
            address _address = farmersAddresses[i];
            updateClaims(_address);
        }
    }

    function setNodeCost(uint256 newNodeCost) public onlyOwner {
        nodeCost = newNodeCost;
    }

    function setNodeBase(uint256 newBase) public onlyOwner {
        nodeBase = newBase;
    }

    //Node management - Buy - Claim - Bond - User front
    function buyNode(uint256 _amount) external payable {  
        require(isLive, "Platform is offline");
        uint256 nodesOwned = farmers[msg.sender].milkNodes + farmers[msg.sender].bondNodes + _amount;
        require(nodesOwned < 101, "Max Cows Owned");
        Farmer memory farmer;
        if(farmers[msg.sender].exists){
            farmer = farmers[msg.sender];
        } else {
            farmer = Farmer(true, 0, 0, 0, 0, 0);
            farmersAddresses.push(msg.sender);
        }
        uint256 transactionTotal = nodeCost * _amount;
        uint256 toDev = transactionTotal / 10 * devShare;
        uint256 toTreasury = transactionTotal / 10 * treasuryShare;
        uint256 toPool = transactionTotal - toDev - toTreasury;
        _transferFrom(milk, msg.sender, address(this), toPool);
        _transferFrom(milk, msg.sender, address(treasury), toTreasury);
        _transferFrom(milk, msg.sender, address(dev), toDev);
        farmers[msg.sender] = farmer;
        updateClaims(msg.sender);
        farmers[msg.sender].milkNodes += _amount;
        totalNodes += _amount;
    }

    function bondNode(uint256 _amount) external payable {
        require(isLive, "Platform is offline");
        uint256 nodesOwned = farmers[msg.sender].milkNodes + farmers[msg.sender].bondNodes + _amount;
        require(nodesOwned < 101, "Max Cows Owned");
        Farmer memory farmer;
        if(farmers[msg.sender].exists){
            farmer = farmers[msg.sender];
        } else {
            farmer = Farmer(true, 0, 0, 0, 0, 0);
            farmersAddresses.push(msg.sender);
        }
        uint256 usdcAmount = setBondCost();
        uint256 transactionTotal = usdcAmount * _amount;
        uint256 toDev = transactionTotal / 10 * devShare;
        uint256 toTreasury = transactionTotal - toDev;
        _transferFrom(usdc, msg.sender, address(dev), toDev);
        _transferFrom(usdc, msg.sender, address(treasury), toTreasury);
        farmers[msg.sender] = farmer;
        updateClaims(msg.sender);
        farmers[msg.sender].bondNodes += _amount;
        totalNodes += _amount;
    }

    function awardNode(address _address, uint256 _amount) public onlyOwner {
        require(isLive, "Platform is offline");
        uint256 nodesOwned = farmers[_address].milkNodes + farmers[_address].bondNodes + _amount;
        require(nodesOwned < 101, "Max Cows Owned");
        Farmer memory farmer;
        if(farmers[_address].exists){
            farmer = farmers[_address];
        } else {
            farmer = Farmer(true, 0, 0, 0, 0, 0);
            farmersAddresses.push(_address);
        }
        farmers[_address] = farmer;
        updateClaims(_address);
        farmers[_address].bondNodes += _amount;
        totalNodes += _amount;
        farmers[_address].lastUpdate = block.timestamp;
    }

    function compoundNode() public {
        uint256 pendingClaims = getTotalClaimable();
        uint256 nodesOwned = farmers[msg.sender].milkNodes + farmers[msg.sender].bondNodes;
        require(pendingClaims>nodeCost, "Not enough pending MILK to compound");
        require(nodesOwned < 100, "Max Cows Owned");
        updateClaims(msg.sender);
        if (farmers[msg.sender].claimsMilk > nodeCost) {
            farmers[msg.sender].claimsMilk -= nodeCost;
            farmers[msg.sender].milkNodes++;
        } else {
            uint256 difference = nodeCost - farmers[msg.sender].claimsMilk;
            farmers[msg.sender].claimsMilk = 0;
            farmers[msg.sender].claimsBond -= difference;
            farmers[msg.sender].bondNodes++;
        }
        totalNodes++;
    }

    function updateClaims(address _address) internal {
        uint256 time = block.timestamp;
        uint256 timerFrom = farmers[_address].lastUpdate;
        if (timerFrom > 0)
            farmers[_address].claimsMilk += farmers[_address].milkNodes * nodeBase * dailyInterest * (time - timerFrom) / 8640000;
            farmers[_address].claimsBond += farmers[_address].bondNodes * nodeBase * dailyInterest * (time - timerFrom) / 8640000;
            farmers[_address].lastUpdate = time;
    }

    function getTotalClaimable() public view returns (uint256) {
        uint256 time = block.timestamp;
        uint256 pendingMilk = farmers[msg.sender].milkNodes * nodeBase * dailyInterest * (time - farmers[msg.sender].lastUpdate) / 8640000;
        uint256 pendingBond = farmers[msg.sender].bondNodes * nodeBase * dailyInterest * (time - farmers[msg.sender].lastUpdate) / 8640000;
        uint256 pending = pendingMilk + pendingBond;
        return farmers[msg.sender].claimsMilk + farmers[msg.sender].claimsBond + pending;
	}

    function getTaxEstimate() external view returns (uint256) {
        uint256 time = block.timestamp;
        uint256 pendingMilk = farmers[msg.sender].milkNodes * nodeBase * dailyInterest * (time - farmers[msg.sender].lastUpdate) / 8640000;
        uint256 pendingBond = farmers[msg.sender].bondNodes * nodeBase * dailyInterest * (time - farmers[msg.sender].lastUpdate) / 8640000;
        uint256 claimableMilk = pendingMilk + farmers[msg.sender].claimsMilk;
        uint256 claimableBond = pendingBond + farmers[msg.sender].claimsBond;
        uint256 taxMilk = claimableMilk / 100 * claimTaxMilk;
        uint256 taxBond = claimableBond / 100 * claimTaxBond;
        return taxMilk + taxBond;
	}

    function calculateTax() public returns (uint256) {
        updateClaims(msg.sender);
        uint256 taxMilk = farmers[msg.sender].claimsMilk / 100 * claimTaxMilk;
        uint256 taxBond = farmers[msg.sender].claimsBond / 100 * claimTaxBond;
        uint256 tax = taxMilk + taxBond;
        return tax;
    }


    function claim() external payable {
        // ensure msg.sender is sender
        require(farmers[msg.sender].exists, "sender must be registered farmer to claim yields");

        updateClaims(msg.sender);
        uint256 tax = calculateTax();
		uint256 reward = farmers[msg.sender].claimsMilk + farmers[msg.sender].claimsBond;
        uint256 toTreasury = tax;
        uint256 toFarmer = reward - tax;
		if (reward > 0) {
            farmers[msg.sender].claimsMilk = 0;		
            farmers[msg.sender].claimsBond = 0;
            _transfer(milk, msg.sender, toFarmer);
            _transfer(milk, address(treasury), toTreasury);
		}
	}

    //Platform Info
    function currentDailyRewards() external view returns (uint256) {
        uint256 dailyRewards = nodeBase * dailyInterest / 100;
        return dailyRewards;
    }

    function getOwnedNodes() external view returns (uint256) {
        uint256 ownedNodes = farmers[msg.sender].milkNodes + farmers[msg.sender].bondNodes;
        return ownedNodes;
    }

    function getTotalNodes() external view returns (uint256) {
        return totalNodes;
    }

    function getMilkClaimTax() external view returns (uint256) {
        return claimTaxMilk;
    }

    function getBondClaimTax() external view returns (uint256) {
        return claimTaxBond;
    }

    // SafeERC20 transfer
    function _transfer(IERC20 token, address account, uint256 amount) private {
        SafeERC20.safeTransfer(token, account, amount);
        // log transfer to blockchain
        emit IERC20TransferEvent(token, account, amount);
    }

    // SafeERC20 transferFrom 
    function _transferFrom(IERC20 token, address from, address to, uint256 amount) private {
        SafeERC20.safeTransferFrom(token, from, to, amount);
        // log transferFrom to blockchain
        emit IERC20TransferFromEvent(token, from, to, amount);
    }

}