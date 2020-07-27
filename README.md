# SuperStable

## Super USD Stablecoin backed by basket of other volatile stablecoin like DAI,USDC,USDT.

## Problem

There is currently none exact USD fiat stablecoin on ethereum since most of times such stablecoins fluctuate in value with dai going from 0.90 to 1.10 sometimes
althought non collateral coins like USDT and USDC are stable but they are custodial in nature and even fluctuate in value
This is a problem since if we want mass adoption on ethereum we need a stablecoin which represents exact value of US dollar and won't fluctuate
sadly Libra a similar ambitious project is not getting built on ethereum due to compliance issues and so we need a libra alternative which is compomising of near stable and doesnt warys much

## Solution

Introducing SuperStable Dollar

A ERC20 representation of US dollar but comprising of composite of staablecoins USDC,USDT currently 

The composite is actually making up of AAVE interest bering atokens like aUSDC,aUSDT

This way user can earn interest on their locked coins and also this additional interest helps Super stablecoin stay much stable

## Contract Flow

1. first User approves any coins he wants to spend
2. then using tellor oracles we fetch rate of his assets he wants to lock against ETH and then use ETH/USD rate feed to convert this to USD
3. after this we mint equivalent amount of SuperStable coin ERC20 Token which has essentially average rate of all coins in pool(USDT,USDC)

for example if pool has aalready say 250 USDC worth 1.05 each and 250 USDT worth 0.95 each so average of pool assets total value divided by total supply of superstablecoin minted will be 1.

4. this protects users from having invested in one stablecoin and decreases risk of holding superstablecoin since its backed by part custodial and part non custodial assets

5. also users can earn interest on locked coins from aave protocol since we use atokens 

Note:atoken is just Aave token representation of asset with 1:1 backing so 1 USDC is always 1 aUSDC.

## How to run

since I could get time to complete frontend on time so I worked only on contracts
you can 
1. git clone
2. truffle compile
3. truffle deploy to test them

a live version will be up soon

