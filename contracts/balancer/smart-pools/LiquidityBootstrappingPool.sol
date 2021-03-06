// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is disstributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.5.12;

import "./IBFactory.sol";
import "./PCToken.sol";

contract LiquidityBootstrappingPool is PCToken {

    event LOG_CALL(
        bytes4  indexed sig,
        address indexed caller,
        bytes           data
    ) anonymous;

    event LOG_JOIN(
        address indexed caller,
        address indexed tokenIn,
        uint256         tokenAmountIn
    );

    event LOG_EXIT(
        address indexed caller,
        address indexed tokenOut,
        uint256         tokenAmountOut
    );

    modifier _logs_() {
        emit LOG_CALL(msg.sig, msg.sender, msg.data);
        _;
    }

    modifier _lock_() {
        require(!_mutex, "ERR_REENTRY");
        _mutex = true;
        _;
        _mutex = false;
    }

    modifier _viewlock_() {
        require(!_mutex, "ERR_REENTRY");
        _;
    }

    uint public constant BONE             = 10**18;
    uint public constant INIT_POOL_SUPPLY = BONE * 100;

    bool private _mutex;
    bool private _created;
    uint internal _swapFee;
    address internal _controller;

    address[] private _tokens;
    uint256[] private _startBalances;
    uint256[] private _startWeights;
    uint256[] private _endWeights;
    uint256 private _startBlock;
    uint256 private _endBlock;

    IBFactory public _bFactory;
    IBPool public _bPool;


    constructor(
        address bPool,
        address[] memory tokens,
        uint256[] memory startBalances,
        uint256[] memory startWeights,
        uint256[] memory endWeights,
        uint256[3] memory params // startBlock, endBlock, swapFee
    )
        public
    {
        _controller = msg.sender;
        _bPool = IBPool(bPool);
        _tokens = tokens;
        _startBalances = startBalances;
        _startWeights = startWeights;
        _endWeights = endWeights;
        _startBlock = params[0];
        _endBlock = params[1];
        _swapFee = params[2];
    }

    function setController(address manager)
        public
        _logs_
        _lock_
    {
        require(msg.sender == _controller, "ERR_NOT_CONTROLLER");
        _controller = manager;
    }

    function createPool(uint initialSupply)
        public
        _logs_
        _lock_
        returns (LiquidityBootstrappingPool)
    {
        require(block.number >= _startBlock, "ERR_START_BLOCK");
        require(!_created, "ERR_IS_CREATED");

        _bPool.setSwapFee(_swapFee);
        _bPool.setPublicSwap(true);

        for (uint i = 0; i < _tokens.length; i++) {
            address t = _tokens[i];
            uint bal = _startBalances[i];
            uint denorm = _startWeights[i];

            bool xfer = IERC20(t).transferFrom(msg.sender, address(this), bal);
            require(xfer, "ERR_ERC20_FALSE");

            IERC20(t).approve(address(_bPool), uint(-1));
            _bPool.bind(t, bal, denorm);
        }

        _created = true;

        _mintPoolShare(initialSupply);
        _pushPoolShare(msg.sender, initialSupply);
    }

    function pokeWeights()
        external
        _logs_
        _lock_
    {
        require(_created, "ERR_NOT_CREATED");

        for (uint i = 0; i < _tokens.length; i++) {
            uint oldRange = bsub(_endBlock, _startBlock);
            uint newRange = 0;
            uint newMin = 0;
            if (_startWeights[i] >= _endWeights[i]) {
                newRange = bsub(_startWeights[i], _endWeights[i]);
                newMin = _endWeights[i];
            } else {
                newRange = bsub(_endWeights[i], _startWeights[i]);
                newMin = _startWeights[i];
            }

            uint newWeight = badd(bmul(bdiv(bsub(block.number, _startBlock), oldRange), newRange), newMin);
            _bPool.rebind(_tokens[i], _bPool.getBalance(_tokens[i]), newWeight);
        }
    }

    // Pull tokens from address and rebind BPool
    function _pullUnderlying(address erc20, address from, uint amount)
        internal
    {
        // Gets current Balance of token i, Bi, and weight of token i, Wi, from BPool.
        uint tokenBalance = _bPool.getBalance(erc20);
        uint tokenWeight = _bPool.getDenormalizedWeight(erc20);

        bool xfer = IERC20(erc20).transferFrom(from, address(this), amount);
        require(xfer, "ERR_ERC20_FALSE");
        _bPool.rebind(erc20, badd(tokenBalance, amount), tokenWeight);
    }

    // Rebind BPool and push tokens to address
    function _pushUnderlying(address erc20, address to, uint amount)
        internal
    {
        if (amount == 0) return;
        // Gets current Balance of token i, Bi, and weight of token i, Wi, from BPool.
        uint tokenBalance = _bPool.getBalance(erc20);
        uint tokenWeight = _bPool.getDenormalizedWeight(erc20);
        _bPool.rebind(erc20, bsub(tokenBalance, amount), tokenWeight);
        bool xfer = IERC20(erc20).transfer(to, amount);
        require(xfer, "ERR_ERC20_FALSE");
    }

    function joinPool(uint poolAmountOut)
         external
        _logs_
        _lock_
    {
        require(_created, "ERR_NOT_CREATED");

        uint poolTotal = totalSupply();

        uint ratio = bdiv(poolAmountOut, poolTotal);
        require(ratio != 0);

        for (uint i = 0; i < _tokens.length; i++) {
            address t = _tokens[i];
            uint bal = _bPool.getBalance(t);
            uint tokenAmountIn = bmul(ratio, bal);
            emit LOG_JOIN(msg.sender, t, tokenAmountIn);
            _pullUnderlying(t, msg.sender, tokenAmountIn);
        }
        _mintPoolShare(poolAmountOut);
        _pushPoolShare(msg.sender, poolAmountOut);
    }

    function exitPool(uint poolAmountIn)
        external
        _logs_
        _lock_
    {
        require(_created, "ERR_NOT_CREATED");

        uint poolTotal = totalSupply();
        uint ratio = bdiv(poolAmountIn, poolTotal);
        require(ratio != 0);

        _pullPoolShare(msg.sender, poolAmountIn);
        _burnPoolShare(poolAmountIn);

        for (uint i = 0; i < _tokens.length; i++) {
            address t = _tokens[i];
            uint bal = _bPool.getBalance(t);
            uint tAo = bmul(ratio, bal);
            emit LOG_EXIT(msg.sender, t, tAo);
            _pushUnderlying(t, msg.sender, tAo);
        }
    }

    function joinswapExternAmountIn(address tokenIn, uint256 tokenAmountIn)
        external
        _logs_
        _lock_
        returns (uint poolAmountOut)
    {
        require(_bPool.isBound(tokenIn), "ERR_NOT_BOUND");
        require(_created, "ERR_NOT_CREATED");

        poolAmountOut = _bPool.calcPoolOutGivenSingleIn(
                            _bPool.getBalance(tokenIn),
                            _bPool.getDenormalizedWeight(tokenIn),
                            _totalSupply,
                            _bPool.getTotalDenormalizedWeight(),
                            tokenAmountIn,
                            _swapFee
                        );

        emit LOG_JOIN(msg.sender, tokenIn, tokenAmountIn);

        _mintPoolShare(poolAmountOut);
        _pushPoolShare(msg.sender, poolAmountOut);
        _pullUnderlying(tokenIn, msg.sender, tokenAmountIn);

        return poolAmountOut;
    }

    function joinswapPoolAmountOut(uint poolAmountOut, address tokenIn)
        external
        _logs_
        _lock_
        returns (uint tokenAmountIn)
    {
        require(_bPool.isBound(tokenIn), "ERR_NOT_BOUND");
        require(_created, "ERR_NOT_CREATED");

        tokenAmountIn = _bPool.calcSingleInGivenPoolOut(
                            _bPool.getBalance(tokenIn),
                            _bPool.getDenormalizedWeight(tokenIn),
                            _totalSupply,
                            _bPool.getTotalDenormalizedWeight(),
                            poolAmountOut,
                            _swapFee
                        );

        emit LOG_JOIN(msg.sender, tokenIn, tokenAmountIn);

        _mintPoolShare(poolAmountOut);
        _pushPoolShare(msg.sender, poolAmountOut);
        _pullUnderlying(tokenIn, msg.sender, tokenAmountIn);

        return tokenAmountIn;
    }

    function exitswapPoolAmountIn(uint poolAmountIn, address tokenOut)
        external
        _logs_
        _lock_
        returns (uint tokenAmountOut)
    {
        require(_bPool.isBound(tokenOut), "ERR_NOT_BOUND");
        require(_created, "ERR_NOT_CREATED");

        tokenAmountOut = _bPool.calcSingleOutGivenPoolIn(
                            _bPool.getBalance(tokenOut),
                            _bPool.getDenormalizedWeight(tokenOut),
                            _totalSupply,
                            _bPool.getTotalDenormalizedWeight(),
                            poolAmountIn,
                            _swapFee
                        );

        emit LOG_EXIT(msg.sender, tokenOut, tokenAmountOut);

        _pullPoolShare(msg.sender, poolAmountIn);
        _burnPoolShare(poolAmountIn);
        _pushUnderlying(tokenOut, msg.sender, tokenAmountOut);        // This will do an EXIT_FEE because of BP rebind

        return tokenAmountOut;
    }

    function exitswapExternAmountOut(address tokenOut, uint tokenAmountOut)
        external
        _logs_
        _lock_
        returns (uint poolAmountIn)
    {
        require(_bPool.isBound(tokenOut), "ERR_NOT_BOUND");
        require(_created, "ERR_NOT_CREATED");

        poolAmountIn = _bPool.calcPoolInGivenSingleOut(
                            _bPool.getBalance(tokenOut),
                            _bPool.getDenormalizedWeight(tokenOut),
                            _totalSupply,
                            _bPool.getTotalDenormalizedWeight(),
                            tokenAmountOut,
                            _swapFee
                        );

        emit LOG_EXIT(msg.sender, tokenOut, tokenAmountOut);

        _pullPoolShare(msg.sender, poolAmountIn);
        _burnPoolShare(poolAmountIn);
        _pushUnderlying(tokenOut, msg.sender, tokenAmountOut);

        return poolAmountIn;
    }

    function _mintPoolShare(uint amount)
        internal
    {
        _mint(amount);
    }

    function _pushPoolShare(address to, uint amount)
        internal
    {
        _push(to, amount);
    }

    function _pullPoolShare(address from, uint amount)
        internal
    {
        _pull(from, amount);
    }

    function _burnPoolShare(uint amount)
        internal
    {
        _burn(amount);
    }

}
