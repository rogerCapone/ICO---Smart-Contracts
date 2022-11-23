// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface ERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

// This library could be removed, as Solidit versions > ^0.8.0 already control UnderFlows & OverFlows
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }
}

contract ILO {
    // Used for the seek of testing Smart Contract creation with libraries
    using SafeMath for uint256;
    ERC20 public token;

    uint256 public startTime;

    uint256 public weiRaised;
    uint256 public tokensSold;
    uint256 public tokensUnsold = SafeMath.mul(150000000, 10**(18)); // 150,000,000

    uint256 public phaseOneSupply;
    uint256 public phaseTwoSupply;
    uint256 public phaseThreeSupply;

    uint256 public phaseOneTimeLock;
    uint256 public phaseTwoTimeLock;
    uint256 public phaseThreeTimeLock;

    uint256 public idleTime;

    uint256 public vestingPhase1;
    uint256 public vestingPhase2;
    uint256 public vestingPhase3;

    // Rates can be modified per Phases or just set them equal
    uint256 public phase1Rate = 100;
    uint256 public phase2Rate = 100;
    uint256 public phase3Rate = 100;

    uint256 public purchaseCount = 0;

    struct Purchase {
        address buyer;
        uint256 weiInvested;
        uint256 tokensBuyed;
    }

    Purchase[] public latestPurchases;

    struct Investors {
        address payable buyer;
        uint256 tokensAmount;
        uint256 weiAmountPhase1;
        uint256 tokensAmountPhase1;
        uint256 weiAmountPhase2;
        uint256 tokensAmountPhase2;
        uint256 weiAmountPhase3;
        uint256 tokensAmountPhase3;
    }

    mapping(address => Investors) public investors;

    address payable public governance;

    event TokenPurchase(
        address indexed purchaser,
        uint256 value,
        uint256 amount
    );

    constructor(
        address payable _governance,
        ERC20 _token,
        uint256 _startTime
    ) {
        governance = _governance;
        token = _token;

        startTime = _startTime; //1647298800; // Tue Mar 15 2022 00:00:00 GMT+0100 (Central Europe Standard Time)
        idleTime = SafeMath.add(idleTime, 1 minutes);

        phaseOneTimeLock = SafeMath.add(startTime, 3 minutes); //4 + 2 (idle) == 8640 minutes
        phaseTwoTimeLock = SafeMath.add(phaseOneTimeLock, 3 minutes); //4 + 2 (idle) == 8640 minutes
        phaseThreeTimeLock = SafeMath.add(phaseTwoTimeLock, 2 minutes); //8 == 11520 minutes

        // ATTENTION !!! Now is hard-coded for localhost testing purposes

        // vestingPhase1 = SafeMath.add(phaseThreeTimeLock, 1 minutes); 2 weeks
        // vestingPhase2 = SafeMath.add(phaseThreeTimeLock, 2 minutes); 1 month
        // vestingPhase3 = SafeMath.add(phaseThreeTimeLock, 3 minutes); 2 months

        vestingPhase1 = SafeMath.add(phaseThreeTimeLock, 3 minutes);
        vestingPhase2 = SafeMath.add(phaseThreeTimeLock, 2 minutes);
        vestingPhase3 = SafeMath.add(phaseThreeTimeLock, 1 minutes);

        phaseOneSupply = SafeMath.mul(40000000, 10**(18)); // 40,000,000
        phaseTwoSupply = SafeMath.mul(50000000, 10**(18)); // 50,000,000
        phaseThreeSupply = SafeMath.mul(60000000, 10**(18)); // 60,000,000
    }

    receive() external payable {
        buyTokens();
    }

    function _getTokensBasedOnPhase(uint256 _weiAmount)
        internal
        returns (uint256 _tokens)
    {
        uint256 _now = block.timestamp;
        uint256 _tokensAmount = 0;

        _tokens = SafeMath.add(_tokensAmount, _weiAmount.mul(getCurrentRate()));

        if (_now <= (phaseOneTimeLock - (idleTime))) {
            if ((phaseOneSupply - _tokens) >= 0) {
                require(
                    (phaseOneSupply - _tokens) >= 0,
                    "Phase One Supply Ended !"
                );
                phaseOneSupply = phaseOneSupply.sub(_tokens);
            } else {
                _tokens = 0;
            }
        } else if (
            _now > (phaseOneTimeLock - (idleTime)) && _now < phaseOneTimeLock
        ) {
            _tokens = 0;
            require(0 != 0, "IDLE TIME 1 !");
            phaseTwoSupply = phaseTwoSupply.sub(_tokens);
        } else if (
            _now > phaseOneTimeLock && _now < (phaseTwoTimeLock - (idleTime))
        ) {
            if ((phaseTwoSupply - _tokens) >= 0) {
                require(
                    (phaseTwoSupply - _tokens) >= 0,
                    "Phase Two Supply Ended !"
                );
                phaseTwoSupply = phaseTwoSupply.sub(_tokens);
            } else {
                _tokens = 0;
            }
        } else if (
            _now > (phaseTwoTimeLock - (idleTime)) && _now < phaseTwoTimeLock
        ) {
            _tokens = 0;
            require(0 != 0, "IDLE TIME 2 !");
            phaseTwoSupply = phaseTwoSupply - _tokens;
        } else if (_now > phaseTwoTimeLock && _now < (phaseThreeTimeLock)) {
            if (phaseThreeSupply - _tokens >= 0) {
                require(
                    (phaseThreeSupply - _tokens) >= 0,
                    "Phase Three Supply Ended !"
                );
                phaseThreeSupply = phaseThreeSupply.sub(_tokens);
            } else {
                _tokens = 0;
            }
        }
        return _tokens;
    }

    function buyTokens() public payable {
        uint256 weiAmount = msg.value;

        require(
            weiAmount >= 0.0000000000001 ether,
            "investment should be more than 0.0000000000001 EWT"
        );
        require(block.timestamp <= phaseThreeTimeLock, " ILO is Closed !");
        require(block.timestamp >= startTime, " ILO is not open yet!");
        Investors storage investor = investors[msg.sender];

        uint256 tokens = 0;

        tokens = _getTokensBasedOnPhase(weiAmount);
        require(tokens > 0, "NOT POSSIBLE TO PURCHASE ERC-20");
        weiRaised = weiRaised.add(weiAmount);

        investor.buyer = payable(msg.sender);

        latestPurchases.push(Purchase(msg.sender, weiAmount, tokens));
        purchaseCount = purchaseCount + 1;

        if (block.timestamp < (phaseOneTimeLock - idleTime)) {
            investor.weiAmountPhase1 = investor.weiAmountPhase1 + weiAmount;
            investor.tokensAmountPhase1 = investor.tokensAmountPhase1 + tokens;
        } else if (
            block.timestamp > phaseOneTimeLock &&
            block.timestamp < (phaseTwoTimeLock - idleTime)
        ) {
            investor.weiAmountPhase2 = investor.weiAmountPhase2 + weiAmount;
            investor.tokensAmountPhase2 = investor.tokensAmountPhase2 + tokens;
        } else if (
            block.timestamp > phaseTwoTimeLock &&
            block.timestamp < phaseThreeTimeLock
        ) {
            investor.weiAmountPhase3 = investor.weiAmountPhase3 + weiAmount;
            investor.tokensAmountPhase3 = investor.tokensAmountPhase3 + tokens;
        }

        investor.tokensAmount = investor.tokensAmount + tokens;

        tokensSold = tokensSold.add(tokens);
        tokensUnsold = tokensUnsold.sub(tokens);

        governance.transfer(weiAmount);

        emit TokenPurchase(msg.sender, weiAmount, tokens);
    }

    function withdrawTokens() public returns (bool success) {
        Investors storage investor = investors[msg.sender];
        address buyer = investor.buyer;

        require(msg.sender == buyer, "Not valid investor to withdraw !");
        require(block.timestamp >= vestingPhase3, " still locked");

        if (
            investor.tokensAmountPhase3 > 0 && block.timestamp >= vestingPhase3
        ) {
            require(block.timestamp >= vestingPhase3, "Still in Vesting PH3");
            require(
                token.transfer(buyer, investor.tokensAmountPhase3),
                "Can NOT transfer ERC-20 from Phase 3"
            );
            investor.tokensAmount = SafeMath.sub(
                investor.tokensAmount,
                investor.tokensAmountPhase3
            );
            investor.tokensAmountPhase3 = 0;
        }

        if (
            investor.tokensAmountPhase2 > 0 && block.timestamp >= vestingPhase2
        ) {
            require(block.timestamp >= vestingPhase2, "Still in Vesting PH2");
            require(
                token.transfer(buyer, investor.tokensAmountPhase2),
                "Can NOT transfer ERC-20 from Phase 2"
            );
            investor.tokensAmount = SafeMath.sub(
                investor.tokensAmount,
                investor.tokensAmountPhase2
            );
            investor.tokensAmountPhase2 = 0;
        }

        if (
            investor.tokensAmountPhase1 > 0 && block.timestamp >= vestingPhase1
        ) {
            require(block.timestamp >= vestingPhase1, "Still in Vesting PH1");

            require(
                token.transfer(buyer, investor.tokensAmountPhase1),
                "Can NOT transfer ERC-20 from Phase 1"
            );

            investor.tokensAmount = SafeMath.sub(
                investor.tokensAmount,
                investor.tokensAmountPhase1
            );
            investor.tokensAmountPhase1 = 0;
        }

        return true;
    }

    function getTokenCount() public view returns (uint256) {
        Investors storage investor = investors[msg.sender];

        uint256 _totalTokens = investor.tokensAmountPhase1 +
            investor.tokensAmountPhase2 +
            investor.tokensAmountPhase3;

        return _totalTokens;
    }

    function withdrawUnsoldTokens() public returns (bool success) {
        require(msg.sender == governance, "!governance");
        require(block.timestamp > phaseThreeTimeLock, "ILO is not finished");

        require(
            token.transfer(governance, tokensUnsold),
            "Transfer not successful"
        );

        return true;
    }

    function setGovernance(address payable _governance)
        public
        returns (bool success)
    {
        require(msg.sender == governance, "!governance");
        governance = _governance;

        return true;
    }

    function withdrawEthers(uint256 _weiAmount) public returns (bool success) {
        require(msg.sender == governance, "!governance");
        governance.transfer(_weiAmount);

        return true;
    }

    function getCurrentRate() public view returns (uint256) {
        if (block.timestamp < phaseOneTimeLock) {
            return phase1Rate;
        } else if (
            block.timestamp < phaseTwoTimeLock &&
            block.timestamp >= phaseOneTimeLock
        ) {
            return phase2Rate;
        } else if (
            block.timestamp < phaseThreeTimeLock ||
            block.timestamp > phaseThreeTimeLock
        ) {
            return phase3Rate;
        }

        return 0;
    }
}
