pragma solidity >=0.4.21 <0.7.0;
import "./UsingTellor.sol";

contract Oracle is UsingTellor {
  uint public ethusdtellorID;
  uint[] public restellorIDs = [8,24];
  uint public qualifiedValue;
  uint256 public currentValue;
  uint256 public ethcurrentValue;
  uint public granularity = 1;

  constructor(address payable _tellorAddress) UsingTellor(_tellorAddress) public {
    ethusdtellorID = 1;
  }

  function updateValues(uint _limit,uint _offset) external {
    bool _didGet;
    uint _timestamp;
    uint _value;

    (_didGet,_value,_timestamp) = getDataBefore(ethusdtellorID, now - 1 hours,_limit, _offset);
    if(_didGet){
      qualifiedValue = _value/granularity;
    }

    (_didGet,currentValue,_timestamp) = getCurrentValue(ethusdtellorID);
    currentValue = currentValue / granularity;
  }
  
  function getethprice() internal returns(uint256){
    bool _didGet;
    uint _timestamp;
    (_didGet,currentValue,_timestamp) = getCurrentValue(ethusdtellorID);
      ethcurrentValue = currentValue / granularity;
	  return ethcurrentValue;
  }
  
  function getresprice(uint tempID) internal returns(uint256){
    bool _didGet;
    uint _timestamp;
    (_didGet,currentValue,_timestamp) = getCurrentValue(tempID);
      currentValue = currentValue / granularity;
	  return currentValue;
  }
  
  function getPriceFeed() public returns(uint256[] memory feed) {
    uint ethUsdRate = getethprice();
    feed = new uint256[](restellorIDs.length);
    for(uint8 i = 0; i < restellorIDs.length; i++) {
      feed[i] = (getresprice(restellorIDs[i]) * ethUsdRate) / 100000000;
    }
    return feed;
  }
  
}