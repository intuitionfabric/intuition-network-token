pragma solidity ^0.4.11;

/*
    Copyright 2017, Jordi Baylina

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/// @title IntuitionContribution Contract
/// @author Jordi Baylina
/// @dev This contract will be the INT controller during the contribution period.
///  This contract will determine the rules during this period.
///  Final users will generally not interact directly with this contract. ETH will
///  be sent to the INT token contract. The ETH is sent to this contract and from here,
///  ETH is sent to the contribution walled and INTs are mined according to the defined
///  rules.


import "./Owned.sol";
import "./MiniMeToken.sol";
import "./DynamicCeiling.sol";
import "./SafeMath.sol";
import "./ERC20Token.sol";


contract IntuitionContribution is Owned, TokenController {
    using SafeMath for uint256;

    uint256 constant public failSafeLimit = 300000 ether;
    uint256 constant public maxGuaranteedLimit = 30000 ether;
    uint256 constant public exchangeRate = 10000;
    uint256 constant public maxGasPrice = 50000000000;
    uint256 constant public maxCallFrequency = 100;

    MiniMeToken public IGT;
    MiniMeToken public INT;
    uint256 public startBlock;
    uint256 public endBlock;

    address public destEthDevs;

    address public destTokensDevs;
    address public destTokensReserve;
    uint256 public maxIGTSupply;
    address public destTokensIgt;
    DynamicCeiling public dynamicCeiling;

    address public intController;

    mapping (address => uint256) public guaranteedBuyersLimit;
    mapping (address => uint256) public guaranteedBuyersBought;

    uint256 public totalGuaranteedCollected;
    uint256 public totalNormalCollected;

    uint256 public finalizedBlock;
    uint256 public finalizedTime;

    mapping (address => uint256) public lastCallBlock;

    bool public paused;

    modifier initialized() {
        require(address(INT) != 0x0);
        _;
    }

    modifier contributionOpen() {
        require(getBlockNumber() >= startBlock &&
                getBlockNumber() <= endBlock &&
                finalizedBlock == 0 &&
                address(INT) != 0x0);
        _;
    }

    modifier notPaused() {
        require(!paused);
        _;
    }

    function StatusContribution() {
        paused = false;
    }


    /// @notice This method should be called by the owner before the contribution
    ///  period starts This initializes most of the parameters
    /// @param _int Address of the INT token contract
    /// @param _intController Token controller for the INT that will be transferred after
    ///  the contribution finalizes.
    /// @param _startBlock Block when the contribution period starts
    /// @param _endBlock The last block that the contribution period is active
    /// @param _dynamicCeiling Address of the contract that controls the ceiling
    /// @param _destEthDevs Destination address where the contribution ether is sent
    /// @param _destTokensReserve Address where the tokens for the reserve are sent
    /// @param _destTokensIgt Address of the exchanger IGT-INT where the INT are sent
    ///  to be distributed to the IGT holders.
    /// @param _destTokensDevs Address where the tokens for the dev are sent
    /// @param _igt Address of the IGT token contract
    /// @param _maxIGTSupply Quantity of IGT tokens that would represent 10% of status.
    function initialize(
        address _int,
        address _intController,

        uint256 _startBlock,
        uint256 _endBlock,

        address _dynamicCeiling,

        address _destEthDevs,

        address _destTokensReserve,
        address _destTokensIgt,
        address _destTokensDevs,

        address _igt,
        uint256 _maxIGTSupply
    ) public onlyOwner {
        // Initialize only once
        require(address(INT) == 0x0);

        INT = MiniMeToken(_int);
        require(INT.totalSupply() == 0);
        require(INT.controller() == address(this));
        require(INT.decimals() == 18);  // Same amount of decimals as ETH

        require(_intController != 0x0);
        intController = _intController;

        require(_startBlock >= getBlockNumber());
        require(_startBlock < _endBlock);
        startBlock = _startBlock;
        endBlock = _endBlock;

        require(_dynamicCeiling != 0x0);
        dynamicCeiling = DynamicCeiling(_dynamicCeiling);

        require(_destEthDevs != 0x0);
        destEthDevs = _destEthDevs;

        require(_destTokensReserve != 0x0);
        destTokensReserve = _destTokensReserve;

        require(_destTokensIgt != 0x0);
        destTokensIgt = _destTokensIgt;

        require(_destTokensDevs != 0x0);
        destTokensDevs = _destTokensDevs;

        require(_igt != 0x0);
        INT = MiniMeToken(_igt);

        require(_maxIGTSupply >= MiniMeToken(IGT).totalSupply());
        maxIGTSupply = _maxIGTSupply;
    }

    /// @notice Sets the limit for a guaranteed address. All the guaranteed addresses
    ///  will be able to get INTs during the contribution period with his own
    ///  specific limit.
    ///  This method should be called by the owner after the initialization
    ///  and before the contribution starts.
    /// @param _th Guaranteed address
    /// @param _limit Limit for the guaranteed address.
    function setGuaranteedAddress(address _th, uint256 _limit) public initialized onlyOwner {
        require(getBlockNumber() < startBlock);
        require(_limit > 0 && _limit <= maxGuaranteedLimit);
        guaranteedBuyersLimit[_th] = _limit;
        GuaranteedAddress(_th, _limit);
    }

    /// @notice If anybody sends Ether directly to this contract, consider he is
    ///  getting INTs.
    function () public payable notPaused {
        proxyPayment(msg.sender);
    }


    //////////
    // MiniMe Controller functions
    //////////

    /// @notice This method will generally be called by the INT token contract to
    ///  acquire INTs. Or directly from third parties that want to acquire INTs in
    ///  behalf of a token holder.
    /// @param _th INT holder where the INTs will be minted.
    function proxyPayment(address _th) public payable notPaused initialized contributionOpen returns (bool) {
        require(_th != 0x0);
        if (guaranteedBuyersLimit[_th] > 0) {
            buyGuaranteed(_th);
        } else {
            buyNormal(_th);
        }
        return true;
    }

    function onTransfer(address, address, uint256) public returns (bool) {
        return false;
    }

    function onApprove(address, address, uint256) public returns (bool) {
        return false;
    }

    function buyNormal(address _th) internal {
        require(tx.gasprice <= maxGasPrice);

        // Antispam mechanism
        address caller;
        if (msg.sender == address(INT)) {
            caller = _th;
        } else {
            caller = msg.sender;
        }

        // Do not allow contracts to game the system
        require(!isContract(caller));

        require(getBlockNumber().sub(lastCallBlock[caller]) >= maxCallFrequency);
        lastCallBlock[caller] = getBlockNumber();

        uint256 toCollect = dynamicCeiling.toCollect(totalNormalCollected);

        uint256 toFund;
        if (msg.value <= toCollect) {
            toFund = msg.value;
        } else {
            toFund = toCollect;
        }

        totalNormalCollected = totalNormalCollected.add(toFund);
        doBuy(_th, toFund, false);
    }

    function buyGuaranteed(address _th) internal {
        uint256 toCollect = guaranteedBuyersLimit[_th];

        uint256 toFund;
        if (guaranteedBuyersBought[_th].add(msg.value) > toCollect) {
            toFund = toCollect.sub(guaranteedBuyersBought[_th]);
        } else {
            toFund = msg.value;
        }

        guaranteedBuyersBought[_th] = guaranteedBuyersBought[_th].add(toFund);
        totalGuaranteedCollected = totalGuaranteedCollected.add(toFund);
        doBuy(_th, toFund, true);
    }

    function doBuy(address _th, uint256 _toFund, bool _guaranteed) internal {
        assert(msg.value >= _toFund);  // Not needed, but double check.
        assert(totalCollected() <= failSafeLimit);

        if (_toFund > 0) {
            uint256 tokensGenerated = _toFund.mul(exchangeRate);
            assert(INT.generateTokens(_th, tokensGenerated));
            destEthDevs.transfer(_toFund);
            NewSale(_th, _toFund, tokensGenerated, _guaranteed);
        }

        uint256 toReturn = msg.value.sub(_toFund);
        if (toReturn > 0) {
            // If the call comes from the Token controller,
            // then we return it to the token Holder.
            // Otherwise we return to the sender.
            if (msg.sender == address(INT)) {
                _th.transfer(toReturn);
            } else {
                msg.sender.transfer(toReturn);
            }
        }
    }

    // NOTE on Percentage format
    // Right now, Solidity does not support decimal numbers. (This will change very soon)
    //  So in this contract we use a representation of a percentage that consist in
    //  expressing the percentage in "x per 10**18"
    // This format has a precision of 16 digits for a percent.
    // Examples:
    //  3%   =   3*(10**16)
    //  100% = 100*(10**16) = 10**18
    //
    // To get a percentage of a value we do it by first multiplying it by the percentage in  (x per 10^18)
    //  and then divide it by 10**18
    //
    //              Y * X(in x per 10**18)
    //  X% of Y = -------------------------
    //               100(in x per 10**18)
    //


    /// @notice This method will can be called by the owner before the contribution period
    ///  end or by anybody after the `endBlock`. This method finalizes the contribution period
    ///  by creating the remaining tokens and transferring the controller to the configured
    ///  controller.
    function finalize() public initialized {
        require(getBlockNumber() >= startBlock);
        require(msg.sender == owner || getBlockNumber() > endBlock);
        require(finalizedBlock == 0);

        // Do not allow termination until all curves revealed.
        require(dynamicCeiling.allRevealed());

        // Allow premature finalization if final limit is reached
        if (getBlockNumber() <= endBlock) {
            var (,lastLimit,,) = dynamicCeiling.curves(dynamicCeiling.revealedCurves().sub(1));
            require(totalNormalCollected >= lastLimit);
        }

        finalizedBlock = getBlockNumber();
        finalizedTime = now;

        uint256 percentageToIgt;
        if (IGT.totalSupply() >= maxIGTSupply) {
            percentageToIgt = percent(10);  // 10%
        } else {

            //
            //                           IGT.totalSupply()
            //  percentageToIgt = 10% * -------------------
            //                             maxIGTSupply
            //
            percentageToIgt = percent(10).mul(IGT.totalSupply()).div(maxIGTSupply);
        }

        uint256 percentageToDevs = percent(20);  // 20%


        //
        //  % To Contributors = 41% + (10% - % to IGT holders)
        //
        uint256 percentageToContributors = percent(41).add(percent(10).sub(percentageToIgt));

        uint256 percentageToReserve = percent(29);


        // INT.totalSupply() -> Tokens minted during the contribution
        //  totalTokens  -> Total tokens that should be after the allocation
        //                   of devTokens, igtTokens and reserve
        //  percentageToContributors -> Which percentage should go to the
        //                               contribution participants
        //                               (x per 10**18 format)
        //  percent(100) -> 100% in (x per 10**18 format)
        //
        //                       percentageToContributors
        //  INT.totalSupply() = -------------------------- * totalTokens  =>
        //                             percent(100)
        //
        //
        //                            percent(100)
        //  =>  totalTokens = ---------------------------- * INT.totalSupply()
        //                      percentageToContributors
        //
        uint256 totalTokens = INT.totalSupply().mul(percent(100)).div(percentageToContributors);


        // Generate tokens for IGT Holders.

        //
        //                    percentageToReserve
        //  reserveTokens = ----------------------- * totalTokens
        //                      percentage(100)
        //
        assert(INT.generateTokens(
            destTokensReserve,
            totalTokens.mul(percentageToReserve).div(percent(100))));

        //
        //                  percentageToIgt
        //  igtTokens = ----------------------- * totalTokens
        //                   percentage(100)
        //
        assert(INT.generateTokens(
            destTokensIgt,
            totalTokens.mul(percentageToIgt).div(percent(100))));


        //
        //                   percentageToDevs
        //  devTokens = ----------------------- * totalTokens
        //                   percentage(100)
        //
        assert(INT.generateTokens(
            destTokensDevs,
            totalTokens.mul(percentageToDevs).div(percent(100))));

        INT.changeController(intController);

        Finalized();
    }

    function percent(uint256 p) internal returns (uint256) {
        return p.mul(10**16);
    }

    /// @dev Internal function to determine if an address is a contract
    /// @param _addr The address being queried
    /// @return True if `_addr` is a contract
    function isContract(address _addr) constant internal returns (bool) {
        if (_addr == 0) return false;
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }


    //////////
    // Constant functions
    //////////

    /// @return Total tokens issued in weis.
    function tokensIssued() public constant returns (uint256) {
        return INT.totalSupply();
    }

    /// @return Total Ether collected.
    function totalCollected() public constant returns (uint256) {
        return totalNormalCollected.add(totalGuaranteedCollected);
    }


    //////////
    // Testing specific methods
    //////////

    /// @notice This function is overridden by the test Mocks.
    function getBlockNumber() internal constant returns (uint256) {
        return block.number;
    }


    //////////
    // Safety Methods
    //////////

    /// @notice This method can be used by the controller to extract mistakenly
    ///  sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
    function claimTokens(address _token) public onlyOwner {
        if (INT.controller() == address(this)) {
            INT.claimTokens(_token);
        }
        if (_token == 0x0) {
            owner.transfer(this.balance);
            return;
        }

        ERC20Token token = ERC20Token(_token);
        uint256 balance = token.balanceOf(this);
        token.transfer(owner, balance);
        ClaimedTokens(_token, owner, balance);
    }


    /// @notice Pauses the contribution if there is any issue
    function pauseContribution() onlyOwner {
        paused = true;
    }

    /// @notice Resumes the contribution
    function resumeContribution() onlyOwner {
        paused = false;
    }

    event ClaimedTokens(address indexed _token, address indexed _controller, uint256 _amount);
    event NewSale(address indexed _th, uint256 _amount, uint256 _tokens, bool _guaranteed);
    event GuaranteedAddress(address indexed _th, uint256 _limit);
    event Finalized();
}
