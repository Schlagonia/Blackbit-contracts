pragma solidity >=0.4.21 <0.7.4;

interface IDAI {
    function transfer(address _to, uint256 _value) external returns (bool success) ;
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success) ;
}

contract Aave {

    string name = 'AAVE';
    string symbol = 'aUSDC';
    uint supply = 0;
    IDAI public dai;

    address[] public stakers;


    mapping (address =>  uint) balanceOf;

    constructor(address _dai) public {
        dai = IDAI(_dai);
    }

    function reward() external {
        for( uint i=0; i < stakers.length; i++){
            address staker = stakers[i];
            uint bal = balanceOf[staker];
            balanceOf[staker] += (bal / 10 );
        }
    }

    function balance(address _address) external view returns (uint){
        uint bal = balanceOf[_address];
        return bal;
    }

    function deposit(uint _amount) external payable returns (bool success) {
        dai.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        stakers.push(msg.sender);
        supply = supply + _amount;
        return true;
    }

    function withdrawal(uint _amount) external {
       require(balanceOf[msg.sender] >= _amount);
       
       balanceOf[msg.sender] -= _amount;
       supply = supply - _amount;

       dai.transfer(msg.sender, _amount);
    }  


}