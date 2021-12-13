// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.4;


contract BBMM {

  uint totalSupply = 0;
  string name = 'tokens n shit';
  string symbol = 'BBMM';
  address owner;
  address fund;

  event Deposit (
    address from,
    uint amount
  );
  
  event Minted (
    address to,
    uint amount
  );

  event Transfer (
    address from,
    address to,
    uint amount
  );

  event Burned (
    uint amount
  );

  event Withdrawal (
    address to,
    uint amount
  );

  mapping(address => uint) public balanceOf;

  mapping(address => mapping(address => uint)) allowance;

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
  
  modifier onlyFund() {
    require(msg.sender == fund);
    _;
  }

  constructor() public {
    owner = msg.sender;
  }

  function setFund(address _fund) public onlyOwner {
    fund = _fund;
  }
  
  function balance(address _address) public view returns (uint){
    return balanceOf[_address];
  }

  function supply() public view returns(uint) {
    return totalSupply;
  }

  function _mint(address _to, uint _amount) private {
    balanceOf[_to] += _amount;
    totalSupply = totalSupply + _amount;

    emit Minted(_to, _amount);
  }

  function _burn(address _from, uint _amount) private {
    balanceOf[_from] -= _amount;
    totalSupply = totalSupply - _amount;
    emit Burned(_amount);
  }

  function approve(address _spender, uint _amount) external returns (bool success){
    allowance[msg.sender][_spender] = _amount;

    return true;
  }

  function transfer(address _to, uint _amount) external {
    require(balanceOf[msg.sender] >= _amount);
    balanceOf[msg.sender] -= _amount;
    balanceOf[_to] += _amount;

    emit Transfer(msg.sender, _to, _amount);
  }

  function transferFrom(address _from, address _to, uint _amount) external {
    
    require(balanceOf[_from] >= _amount, 'not enough funds');
    require(allowance[_from][msg.sender] >= _amount, 'not enought allowance');

    balanceOf[_from] -= _amount;
    balanceOf[_to] += _amount;

    allowance[_from][_to] -= _amount;

    emit Transfer(_from, _to, _amount);

  }

  function deposited(address _depositer, uint _amount) external onlyFund {
    emit Deposit(_depositer, _amount);
    _mint(_depositer, _amount);
  }

  function withdrew(address _to, uint _amount) external  onlyFund {
    require(balanceOf[_to] >= _amount);
    _burn(_to, _amount);

    emit Withdrawal(_to, _amount);
  }


}
