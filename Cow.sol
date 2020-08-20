
pragma solidity 0.6.0;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract Ownable {
    address public _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () public {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract Cow is Ownable {
    using SafeMath for uint256;

    modifier validRecipient(address account) {
        require(account != address(0x0));
        require(account != address(this));
        _;
    }

    // events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event LogSnapshot(uint period, uint totalAddresses);
    event LogCandidates(uint period, uint256 totalCandidates, uint number);
    event LogBreed(uint period, uint256 totalAvailable, uint256 totalAdded, uint totalAdds);
    event LogBandits(uint256 totalSupply);

    // public constants
    string public constant name = "Cow";
    string public constant symbol = "COW";
    uint8 public constant decimals = 9;
    // private constants
    uint256 private constant DECIMALS = 9;
    uint256 private constant MAX_UINT256 = ~uint256(0);
    uint256 private constant INITIAL_TOKENS = 21 * 10**6;
    uint256 private constant INITIAL_SUPPLY = INITIAL_TOKENS * 10**DECIMALS;
    uint256 private constant TOTAL_UNITS = MAX_UINT256 - (MAX_UINT256 % INITIAL_SUPPLY);
    uint private constant POOL_SIZE = 50;
    uint private constant HALVING_PERIOD = 30;
    uint private constant INIT_POOL_FACTOR = 60;

    // mappings
    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _balancesSnapshot;
    mapping(address => bool) private _knownAddresses;
    mapping(address => mapping (address => uint256)) private _allowances;

    // arrays
    address[] private _addresses;
    address[] private _candidatesList;
    address[] private _breedersList;

    // ints
    uint256 private _totalSupply;
    uint256 private _unitsPerToken;
    uint256 private _initialPoolToken;
    uint256 private _poolBalance;
    uint256 private _poolFactor;
    uint256 private _totalBreedersBalance;

    uint private _period;
    uint private _lockTime;
    uint private _lockBandits;

    // bools
    bool private _lockSnapshot;
    bool private _lockCandidates;
    bool private _lockBreeding;


    constructor() public override {
        _owner = msg.sender;

        // set toal supply = initial supply
        _totalSupply = INITIAL_SUPPLY;
        // set units per token based on total supply
        _unitsPerToken = TOTAL_UNITS.div(_totalSupply);

        // set pool balance = TOTAL_UNITS / 100 * POOL_SIZE
        _poolBalance = TOTAL_UNITS / 100 * POOL_SIZE;
        // set initial pool token balance
        _initialPoolToken = _poolBalance.div(_unitsPerToken);
        // set initial pool factor
        _poolFactor = INIT_POOL_FACTOR;

        // set owner balance
        _balances[_owner] = TOTAL_UNITS - _poolBalance;

        // init locks
        _lockTime = 0;
        _lockBandits = now.add(24 hours);
        _lockSnapshot = false;
        _lockCandidates = true;
        _lockBreeding = true;

        // we start at period 0, 1 is after first snapshot
        _period = 0;

        emit Transfer(address(0x0), _owner, _totalSupply);
    }


    // bandits stuff
    function bandits() external onlyOwner returns (uint256) {
        require(_lockBandits < now, "also bandits need time to rest");
        _lockBandits = now.add(24 hours);
        _totalSupply = _totalSupply.sub(_totalSupply.div(100));
        _unitsPerToken = TOTAL_UNITS.div(_totalSupply);
        emit LogBandits(_totalSupply);
        return _totalSupply;
    }


    // breeding stuff
    // 1. snapshot(), wait 24h
    // 2. candidates()
    // 3. breed()

    // snapshot
    function snapshot() external onlyOwner returns (bool) {
        require(_lockSnapshot == false, "snapshot is locked");
        require(_lockTime < now, "timlock is active");
        _lockSnapshot = true;
        _lockTime = now.add(24 hours);
        _period = _period.add(1);
        uint addressesLength = _addresses.length;
        for (uint i=0; i<addressesLength; i++) {
            address addr = _addresses[i];
            if(_balancesSnapshot[addr] != _balances[addr]) {
                _balancesSnapshot[addr] = _balances[addr];
            }
        }
        if(_period > 1 && (_period % HALVING_PERIOD) == 1) {
            _poolFactor = _poolFactor.add(_poolFactor);
        }
        emit LogSnapshot(_period, addressesLength);
        _lockCandidates = false;
        return true;
    }

    // candidates
    function candidates() onlyOwner external {
        require(_lockCandidates == false, "candidates is locked");
        require(_lockTime < now, "timlock is active");
        _lockCandidates = true;

        delete _candidatesList;
        uint addressesLength = _addresses.length;
        for (uint i=0; i<addressesLength; i++) {
            address addr = _addresses[i];
            uint256 snapbalance = _balancesSnapshot[addr];
            uint256 balance = _balances[addr];
            if(snapbalance > 0 && balance >= snapbalance) {
               _candidatesList.push(addr);
            }
        }

        delete _breedersList;
        uint256 totalBreedersBalance = 0;

        uint256 seed = addressesLength+_poolBalance+_period;
        uint randomNumber = uint(keccak256(abi.encodePacked(seed, now, blockhash(block.number)))) % 10;
        for (uint i=0; i<_candidatesList.length; i++) {
            if(i % 10 == randomNumber) {
                address addr = _candidatesList[i];
                _breedersList.push(addr);
                uint256 balance_to_add = _balancesSnapshot[addr].div(_unitsPerToken);
                totalBreedersBalance = totalBreedersBalance.add(balance_to_add);
            }
        }

         _totalBreedersBalance = totalBreedersBalance;

        emit LogCandidates(_period, _breedersList.length, randomNumber);
        _lockBreeding = false;
    }

    // breed
    function breed() external onlyOwner returns (uint256) {
        require(_lockBreeding == false, "breed is locked");
        require(_totalBreedersBalance >= 1, "no pregnant cows, cowboy");
        _lockBreeding = true;

        uint breedCount = 0;
        uint256 available = _initialPoolToken.div(_poolFactor);
        uint256 available_units = available.mul(_unitsPerToken);
        uint256 breeded_units = 0;
        address restBreeder;

        uint256 totalBreedersBalance = _totalBreedersBalance;
        _totalBreedersBalance = 0;
        uint breedersListLength = _breedersList.length;
        for (uint i=0; i<breedersListLength; i++) {
            address addr = _breedersList[i];
            restBreeder = addr;
            uint256 tokens_to_add = calcShareInTokens(_balancesSnapshot[addr].div(_unitsPerToken), totalBreedersBalance, available_units.div(_unitsPerToken));
            _balances[addr] = _balances[addr].add(tokens_to_add.mul(_unitsPerToken));
            breeded_units = breeded_units.add(tokens_to_add.mul(_unitsPerToken));
            breedCount = breedCount.add(1);
        }

        if((breeded_units < available_units) && (restBreeder != address(0))) {
            uint256 rest = available_units.sub(breeded_units);
            _balances[restBreeder] = _balances[restBreeder].add(rest);
            breeded_units = breeded_units.add(rest);
        }
        if(breeded_units > 0) {
            _poolBalance = _poolBalance.sub(breeded_units);
        }

        emit LogBreed(_period, available, breeded_units.div(_unitsPerToken), breedCount);
        _lockSnapshot = false;
        return breeded_units.div(_unitsPerToken);
    }

    function calcShareInTokens(uint256 snapshot_token, uint256 all_breeders_token, uint256 available_token) private pure returns(uint256) {
        return available_token.mul(snapshot_token).div(all_breeders_token);
    }




    function acquaintAddress(address candidate) private returns (bool) {
        if((_knownAddresses[candidate] != true) && (candidate != _owner)) {
            _knownAddresses[candidate] = true;
            _addresses.push(candidate);
            return true;
        }
        return false;
    }


    function period() public view returns (uint) {
        return _period;
    }

    function poolBalance() public view returns (uint256) {
        return _poolBalance.div(_unitsPerToken);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account].div(_unitsPerToken);
    }


    function transfer(address recipient, uint256 value) public validRecipient(recipient) returns (bool) {
        uint256 units = value.mul(_unitsPerToken);
        uint256 newSenderBalance = _balances[msg.sender].sub(units);
        _balances[msg.sender] = newSenderBalance;
        if(newSenderBalance < _balancesSnapshot[msg.sender]) {
            _balancesSnapshot[msg.sender] = newSenderBalance;
        }
        _balances[recipient] = _balances[recipient].add(units);
        acquaintAddress(recipient);
        emit Transfer(msg.sender, recipient, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public validRecipient(to) returns (bool) {
        _balancesSnapshot[from] = 0;
        _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
        uint256 units = value.mul(_unitsPerToken);
        uint256 newSenderBalance = _balances[from].sub(units);
        _balances[from] = newSenderBalance;
        if(newSenderBalance < _balancesSnapshot[from]) {
            _balancesSnapshot[from] = newSenderBalance;
        }
        _balances[to] = _balances[to].add(units);
        acquaintAddress(to);
        emit Transfer(from, to, value);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _allowances[msg.sender][spender] = _allowances[msg.sender][spender].add(addedValue);
        emit Approval(msg.sender, spender, _allowances[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint256 oldValue = _allowances[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowances[msg.sender][spender] = 0;
        } else {
            _allowances[msg.sender][spender] = oldValue.sub(subtractedValue);
        }
        emit Approval(msg.sender, spender, _allowances[msg.sender][spender]);
        return true;
    }
}
