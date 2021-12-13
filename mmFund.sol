pragma solidity >=0.4.21 <0.7.4;

import './BBMM.sol';

interface IAave {
    function deposit(uint _amount) external payable returns (bool success);
    function balance(address _address) external view returns (uint);
    function withdrawal(uint _amount) external ;
}   

interface IYearn {
    function deposit(uint _amount) external payable returns (bool success);
    function balance(address _address) external view returns (uint);
    function withdrawal(uint _amount) external ;
}

interface Idai {
    function transfer(address _to, uint256 _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function balance(address _address) external returns (uint);
}

contract Fund {

    string public name = 'BlackBit Money Market';
    BBMM public bbmm;
    address payable public owner;
    
    uint public aaveBalance = 0;
    uint public yearnBalance = 0;
    
    Idai public dai;
    IAave public aave;
    IYearn public yearn;
    uint public managementFee;
    uint public performanceFee;
    uint public fundBalance;
    uint public ethBalance;
    uint public daiBalance = 0;
    uint public pps;
    uint public toCharge = 0;
    uint public lastPerfomancePPS = 1000;
    bool public isAllowed = true;
    uint public fundOwns = 0;

    string[] public funds;
    uint[] public allocations;

    //@dev 
    //
    // create an interface contract that is imported and editable 

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier allowed {
        require(isAllowed == true);
        _;
    }

    event deposited (
        address _address,
        uint256 amount
    );
    
    event withdrew (
        address _address,
        uint256 amount
    );

    constructor(BBMM _bbmm, address _dai, address _aave, address _yearn) public {
        owner = msg.sender;
        bbmm = _bbmm;
        dai = Idai(_dai);
        aave = IAave(_aave);
        yearn = IYearn(_yearn);
        
    }

    function () external payable {}

    function createAllocation(string calldata _fund, uint _allocation) external onlyOwner returns(bool success) {
        funds.push(_fund);
        allocations.push(_allocation);

        return true;
    }

    // _fee where 1/_fee = % t0 charge/ 1% == 100
    function setManagementFee(uint _fee) external onlyOwner returns (uint ) {
        managementFee = _fee;
        return managementFee;
    }

    // _fee where 1/_fee = % to charge / 10% = 10
    function setPerformanceFee(uint _fee) external onlyOwner returns (uint) {
        performanceFee = _fee;
        return performanceFee;
    }

    function getBalance() public returns (uint){
        aaveBalance = aave.balance(address(this));
        yearnBalance = yearn.balance(address(this));
        daiBalance = dai.balance(address(this));
        fundBalance = aaveBalance + daiBalance + yearnBalance - fundOwns;
        return fundBalance;
    }

    //price numerator and denominator 2/1 would be a 100% ror
    // tokensToWithdrawal * num ) / den

    function PPS() public returns (uint) {
        //pps = getalance() / bbmm.supply();
        uint supply = bbmm.supply();
        if( supply > 0){
            pps = ((getBalance() * 1000) / supply);
        } else {
            pps = 1000;
        }
        return pps;
    }

    function payOwner() external onlyOwner returns (uint) {
        getBalance();
        uint pay = fundOwns;
        if(daiBalance < pay){

            uint diff = pay - daiBalance;
            _pullFunds(diff);
        }

        dai.transfer(address(owner), pay);
    
        fundOwns = 0;

        return pay;

    }


    //@dev
    //on harvest of reward tokens fundOwns is taken out and sent to owner
    function chargeManagementFee() external onlyOwner returns (uint) {
        uint charge = (getBalance() / managementFee);
        
        fundOwns = fundOwns + charge;
        
        return charge;

    }

    function chargePerformanceFee() external onlyOwner returns (uint) {
        uint newPPS = PPS();
        if(newPPS > lastPerfomancePPS) {
            uint percentGrowth = (newPPS - lastPerfomancePPS);
            uint growth = ((percentGrowth * bbmm.supply()) / 1000);
            uint charge = (growth / performanceFee);

            fundOwns = fundOwns + charge;
            lastPerfomancePPS = newPPS;

            return charge;
        }
    }

    function _invest(uint _amount) internal returns (bool success){
      
        uint each = _amount / 2;

        dai.approve(address(aave), each);
        dai.approve(address(yearn), each);

        aave.deposit(each);
        yearn.deposit(each);

        return true;
    }

/*
    function rebalance() external onlyOwner returns (bool success) {
        isAllowed = false;
        
        uint balance = getBalance();
        string[] memory above;
        string[] memory below;
        uint[] memory aboveDiff;
        uint[] memory belowDiff;
        for(uint i=0; i < funds.length; i++) {
            string memory fund = funds[i];
            uint currentBalance = fund.balance(address(this));
            uint allocation = ((balance * allocations[i]) / 100 );
        
            if(currentBalance > allocation) {
                uint diff = currentBalance - allocation;
                above.push(funds[i]);
                aboveDiff.push(diff);
            } else if (allocation > currentBalance) {
                uint diff = allocation - currentBalance;
                below.push(funds[i]);
                belowDiff.push(diff);
            }
        }
        for(uint i=0; i < above.length; i++) {
            string memory n = above[i];
            n.withdrawal(aboveDiff[i]);
        }
        for( uint i=0; i < below.length; i ++) {
            string memory n = below[i];
            n.deposit(belowDiff[i]);
        }


        isAllowed = true;
    }
    */

    function _checkBalance() internal {
        getBalance();
        if(daiBalance > (fundBalance / 5 )){
            uint diff = daiBalance - (fundBalance / 5);
            _invest(diff);
        }
    }

    function _pullFunds(uint _diff) internal returns (bool success) {
        uint diff = _diff;
        uint orNot = diff / 2; 
        aaveBalance = aave.balance(address(this));
        yearnBalance = yearn.balance(address(this));

        if( aaveBalance == yearnBalance) {
            aave.withdrawal(orNot);
            yearn.withdrawal(orNot);
            
            return true;
            
        } else if (aaveBalance > yearnBalance){
            uint protDiff = aaveBalance - yearnBalance; 
            if(protDiff >= diff){ 
                aave.withdrawal(diff);

                return true;

            } else {
                
                uint toBe = protDiff / 2 ; 
                uint higher = orNot + toBe; 
                uint lower = orNot - toBe; 

                aave.withdrawal(higher);
                yearn.withdrawal(lower);

                return true;

            }
        } else if(yearnBalance > aaveBalance){
            uint protDiff = aaveBalance - yearnBalance;
            if(protDiff >= diff){ 
                yearn.withdrawal(diff);

                return true;

            } else {
                uint toBe = protDiff / 2 ;
                uint higher = orNot + toBe;
                uint lower = orNot - toBe;

                yearn.withdrawal(higher);
                aave.withdrawal(lower);

                return true;

            }
        } 

    }
    
    function deposit(uint _amount) external payable allowed returns (bool success) {
        require(msg.value >= _amount, 'value does not equal amount');

        bbmm.deposited(msg.sender, _amount);

        _checkBalance();
        emit deposited(msg.sender, _amount);
        
        return true;

    }

    // deposit _amount in dollars
    function depositDai(uint _amount) external allowed {
        
        uint shares = ((_amount * 1000) / PPS());

        dai.transferFrom(msg.sender, address(this), _amount);

        bbmm.deposited(msg.sender, shares);

        _checkBalance();
        emit deposited(msg.sender, _amount);
    }


    //send amount in bbmm
    function withdrawal(uint _amount) external allowed returns(bool success) {
        uint shares = ((_amount * 1000) / PPS());
        require(bbmm.balanceOf(msg.sender) >= shares, 'your balance of bbmm is not enough');
        bbmm.withdrew(msg.sender, shares); 
        if(_amount > daiBalance) {
            uint diff = _amount - daiBalance;
            _pullFunds(diff);
        }


        dai.transfer(msg.sender, _amount);
        emit withdrew(msg.sender, _amount);

        return true;
    }


}