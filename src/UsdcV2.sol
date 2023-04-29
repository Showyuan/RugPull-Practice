// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import "./Ownable.sol";
import { SafeMath } from "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

contract Whitelistable is Ownable {
    address public whitelister;
    mapping(address => bool) internal whitelist;

    event Whitelisted(address indexed _account);
    event UnWhitelisted(address indexed _account);
    event WhitelisterChanged(address indexed newWhitelister);

    // 確認是否為whitelister
    modifier onlyWhitelister() {
        require(
            msg.sender == whitelister,
            "Whitelistable: caller is not the whitelister"
        );
        _;
    }

    // 確認是否已存在白名單
    modifier whitelisted(address _account) {
        require(
            whitelist[_account],
            "Whitelistable: account isn't whitelisted"
        );
        _;
    }

    // 確認是否存在白名單
    function isWhitelisted(address _account) external view returns (bool) {
        return whitelist[_account];
    }

    // 新增地址至白名單
    function addWhitelist(address _account) external onlyWhitelister {
        whitelist[_account] = true;
        emit Whitelisted(_account);
    }

    // 新增地址至白名單
    function _addWhitelist(address _account) internal {
        whitelist[_account] = true;
        emit Whitelisted(_account);
    }

    // 將地址從白名單移除
    function unWhitelist(address _account) external onlyWhitelister {
        whitelist[_account] = false;
        emit UnWhitelisted(_account);
    }

    // 更換whitelister
    function updateWhitelister(address _newWhitelister) external onlyOwner {
        require(
            _newWhitelister != address(0),
            "Whitelistable: new whitelister is the zero address"
        );
        whitelister = _newWhitelister;
        emit WhitelisterChanged(whitelister);
    }
}

contract UsdcV2 is Whitelistable {
    using SafeMath for uint256;

    string public name;
    string public symbol;
    uint8 public decimals;
    string public currency;
    bool internal initialized;

    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal allowed;
    uint256 internal totalSupply_ = 0;

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed burner, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    function initialize(
        string memory tokenName,
        string memory tokenSymbol,
        string memory tokenCurrency,
        uint8 tokenDecimals
    ) public {
        require(!initialized, "FiatToken: contract is already initialized");
        name = tokenName;
        symbol = tokenSymbol;
        currency = tokenCurrency;
        decimals = tokenDecimals;
        whitelister = msg.sender;
        _addWhitelist(msg.sender);
        setOwner(msg.sender);
        initialized = true;
    }

    // 白名單內的地址可以無限 mint token
    function mint(uint256 _amount)
        external
        whitelisted(msg.sender)
        returns (bool)
    {
        require(_amount > 0, "FiatToken: mint amount not greater than 0");

        totalSupply_ = totalSupply_.add(_amount);
        balances[msg.sender] = balances[msg.sender].add(_amount);

        emit Mint(msg.sender, _amount);
        emit Transfer(address(0), msg.sender, _amount);

        return true;
    }

    // 取得帳戶餘額
    function balanceOf(address account)
        external
        view
        returns (uint256)
    {
        return balances[account];
    }

    // burn token
    function burn(uint256 _amount)
        external
        whitelisted(msg.sender)
    {
        uint256 balance = balances[msg.sender];
        require(_amount > 0, "FiatToken: burn amount not greater than 0");
        require(balance >= _amount, "FiatToken: burn amount exceeds balance");

        totalSupply_ = totalSupply_.sub(_amount);
        balances[msg.sender] = balance.sub(_amount);
        emit Burn(msg.sender, _amount);
        emit Transfer(msg.sender, address(0), _amount);
    }
}
