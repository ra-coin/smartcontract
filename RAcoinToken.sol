pragma solidity ^0.4.0;

contract ERC20Interface {
    function totalSupply() public view returns (uint256);
    function balanceOf(address _owner) public view returns (uint256 balance);
    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
    function allowance(address _owner, address _spender) public view returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract owned {
    address public owner;

    function owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }
}

contract RAcoinToken is owned, ERC20Interface {
    string public constant symbol = "RAC";
    string public constant name = "RAcoinToken";
    uint256 private _totalSupply;
    uint8 public constant decimals = 18;
    uint256 private _unmintedTokens = 20000000000*10^decimals;

    /* persentage for reserving on jackpot during tokens transfer*/
    uint8 reservingAmount = 1;
    
    /* persentage for reserving on jackpot during tokens transfer, 
        default vaule is 100,000 RAC */
    uint256 jackpotMinimumAmount = 100000 * 10^decimals;
    
    /* used for calculating how many times user will be added to jackpotParticipants list:
        transfer amount / reservingStep = times user add to jackpotParticipants list
        the more user transfer the more times he will be added and as result tje more chances to win jackpot */
    uint256 reservingStep;
    
    /* the first seed, will be changed every jackpot turn */
    uint seed = 1000; // Default seed
    
    /* the maximum allowed manual adding to jackpot participants list by owner */
    int maxAllowedManualAdding = 111;

    address[] jackpotParticipants;
    event SetReservingAmount(uint8 _value);
    event SetReservingStep(uint256 _value);
    event SetJackpotMinimumAmount(uint256 _value);
    event AddAddressToJacjpotParticipants(address indexed _sender, uint _times);
    
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) internal allowed;

    /* Jackpot implementation */
    
    function setReservingAmount(uint8 _value) public onlyOwner returns (bool success) {
        assert(_value > 0 && _value < 100);
        
        reservingAmount = _value;
        emit SetReservingAmount(_value);
        return true;
    }
    
    function setReservingStep(uint256 _value) public onlyOwner returns (bool success) {
        reservingStep = _value;
        emit SetReservingStep(_value);
        return true;
    }
    
    function setJackpotMinimumAmount(uint256 _value) public onlyOwner returns (bool success) {
        jackpotMinimumAmount = _value;
        emit SetJackpotMinimumAmount(_value);
        return true;
    }
    
    /* Empty jackpot participants list */
    function clearJackpotParticipants() public onlyOwner returns (bool success) {
        delete jackpotParticipants;
        return true;
    }
    
    /* User is participating in operating jackpot only if he/she transfers RAC tokens using this or transferFromWithReserving function  */
    function transferWithReserving(address _to, uint256 _value) public returns (bool success) {
        uint value = _value * (100 - reservingAmount) / 100; 
        if (transfer(_to, value) && (_value >= reservingStep))
        {
            uint timesToAdd = _value / reservingStep;
            
            for (uint i = 0; i < timesToAdd; i++)
                jackpotParticipants.push(msg.sender);
            
            uint jackpotDeposit = _value - value;
            balances[msg.sender] -= jackpotDeposit;
            //balances[0] is jackpot accumulating account
            balances[0] += jackpotDeposit;

            emit Transfer(msg.sender, _to, jackpotDeposit);
            emit AddAddressToJacjpotParticipants(msg.sender, timesToAdd);
        }
        return true;
    }

    /* User is participating in operating jackpot only if he/she transfers RAC tokens using this or transferWithReserving function  */
    function transferFromWithReserving(address _from, address _to, uint256 _value) public returns (bool success) {
        uint value = _value * (100 - reservingAmount) / 100; 
        if (transferFrom(_from, _to, value) && (_value >= reservingStep))
        {
            uint timesToAdd = _value / reservingStep;
            
            for (uint i = 0; i < timesToAdd; i++)
                jackpotParticipants.push(msg.sender);
            
            uint jackpotDeposit = _value - value;
            balances[msg.sender] -= jackpotDeposit;
            balances[0] += jackpotDeposit;

            emit Transfer(msg.sender, _to, jackpotDeposit);
            emit AddAddressToJacjpotParticipants(msg.sender, timesToAdd);
        }
        return true;
    }

    /* Only need for the token sale jackpot implementation */
    function addToJackpotParticipantsList(address _participant, uint256 _transactionAmount) onlyOwner {
            require (maxAllowedManualAdding > -1);
            uint timesToAdd = _transactionAmount / reservingStep;
            
            for (uint i = 0; i < timesToAdd; i++)
                jackpotParticipants.push(_participant);
            
            emit AddAddressToJacjpotParticipants(msg.sender, timesToAdd);
            maxAllowedManualAdding--;
    }
    
    /* This function may be fired by anyone, not only the owner of smartcontract */
    function distributeJackpot(uint nextSeed) public returns (bool success){
        //balances[0] is jackpot accumulating account
        assert(balances[0] >= jackpotMinimumAmount);
        assert(nextSeed) > 0;

        uint additionalSeed = uint256(block.blockhash(block.number - 1));
        uint totalSeed = 0;
        
        while(totalSeed < jackpotParticipants.length)
        {
            totalSeed += additionalSeed * seed;
        }
        
        uint winner = totalSeed % jackpotParticipants.length;
        balances[jackpotParticipants[winner]] += balances[0];
        Transfer(0, jackpotParticipants[winner], balances[0]);
        balances[0] = 0;
        seed = nextSeed;
        
        return true;
    }
    
    /* ERC20 implementation */
    
    function totalSupply() public view returns (uint256){
        return _totalSupply;
    }
    
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
  
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0));
        require(balances[msg.sender] >= _value);
        assert(balances[_to] + _value >= balances[_to]);
        
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);
        assert(balances[_to] + _value >= balances[_to]);
        
        balances[_from] = balances[_from] - _value;
        balances[_to] = balances[_to] + _value;
        allowed[_from][msg.sender] = allowed[_from][msg.sender] - _value;
        Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
    
    /* token minting implementation */

    function mintToken(address target, uint256 _mintedAmount) public onlyOwner returns (bool success){
        require(_mintedAmount <= _unmintedTokens);
        balances[target] += _mintedAmount;
        _unmintedTokens -= _mintedAmount;
        _totalSupply += _mintedAmount;
        
        emit Transfer(0, target, _mintedAmount); //TODO
        return true;
    }
    
    function stopTokenMinting() public onlyOwner returns (bool success){
        _unmintedTokens = 0;
        return true;
    }
