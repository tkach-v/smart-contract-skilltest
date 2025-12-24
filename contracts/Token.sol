pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  mapping(address => mapping(address => uint256)) private _allowances;
  
  address[] private holders;
  mapping(address => uint256) private holderToIndex;
  mapping(address => uint256) private _withdrawableDividends;

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    _transfer(msg.sender, to, value);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    _allowances[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
    _transfer(from, to, value);
    return true;
  }

  function _transfer(address from, address to, uint256 value) internal {
    require(balanceOf[from] >= value, "Insufficient balance");
    
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    
    if (balanceOf[from] == 0) {
        _removeHolder(from);
    }
    if (balanceOf[to] > 0) {
        if (holderToIndex[to] == 0 && balanceOf[to] > 0) {
            _addHolder(to);
        }
    }
    
    emit Transfer(from, to, value);
  }

  function _addHolder(address account) internal {
      if (holderToIndex[account] == 0) {
          holders.push(account);
          holderToIndex[account] = holders.length;
      }
  }

  function _removeHolder(address account) internal {
      uint256 index = holderToIndex[account];
      if (index != 0) {
          uint256 lastIndex = holders.length;
          if (index != lastIndex) {
              address lastHolder = holders[lastIndex - 1];
              holders[index - 1] = lastHolder;
              holderToIndex[lastHolder] = index;
          }
          holders.pop();
          delete holderToIndex[account];
      }
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "Must mint > 0");
    totalSupply = totalSupply.add(msg.value);
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    
    if (balanceOf[msg.sender] > 0 && holderToIndex[msg.sender] == 0) {
        _addHolder(msg.sender);
    }
    
    emit Transfer(address(0), msg.sender, msg.value);
  }

  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];
    require(amount > 0, "No tokens to burn");
    
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    
    _removeHolder(msg.sender);
    
    emit Transfer(msg.sender, address(0), amount);
    
    dest.transfer(amount);
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    require(index > 0 && index <= holders.length, "Index out of bounds");
    return holders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "Dividend must be > 0");
    require(totalSupply > 0, "No tokens");
    
    for (uint256 i = 0; i < holders.length; i++) {
        address holder = holders[i];
        uint256 bal = balanceOf[holder];
        if (bal > 0) {
            uint256 share = msg.value.mul(bal).div(totalSupply);
            _withdrawableDividends[holder] = _withdrawableDividends[holder].add(share);
        }
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return _withdrawableDividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = _withdrawableDividends[msg.sender];
    require(amount > 0, "No dividend to withdraw");
    
    _withdrawableDividends[msg.sender] = 0;
    dest.transfer(amount);
  }
}