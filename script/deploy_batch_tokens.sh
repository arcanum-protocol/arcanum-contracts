#!/bin/bash
#
#deploy token
 forge create --rpc-url  https://sepolia-rollup.arbitrum.io/rpc --privat
e-key 0xf0449a9e98fd9e88a908e9eac799afc5cc904f0c1417f29f8bacd66d3cd86c18 --constructor-args "GMX" "GMX" 1000000000000000000000 --verifier-u
rl 'https://sepolia-explorer.arbitrum.io/api?' --verify ./src/mocks/erc20.sol:MockERC20 --verifier blockscout


# Sample array of JSON objects
json_array='[
  {
    "name": "GMX", 
    "symbol": "GMX",
    "decimals": 18,
    "share": 10
  },
  {
    "name": "Curve DEX", 
    "symbol": "CRV",
    "decimals": 18,
    "share": 10
  },
  {
    "name": "Gains network", 
    "symbol": "GNS",
    "decimals": 18,
    "share": 10
  },
  {
    "name": "Level finance", 
    "symbol": "LVL",
    "decimals": 18,
    "share": 10
  },
  {
    "name": "MUX protocol", 
    "symbol": "MCB",
    "decimals": 18,
    "share": 10
  }
]'

# Iterate over the array of JSON objects
length=$(echo "$json_array" | jq '. | length')
for (( i = 0; i < $length; i++ )); do
    name=$(echo "$json_array" | jq -r ".[$i].name")
    symbol=$(echo "$json_array" | jq -r ".[$i].symbol")
    echo $name 
    echo $symbol 
   # decimals=$(echo "$json_array" | jq -r ".[$i].decimals")
   # share=$(echo "$json_array" | jq -r ".[$i].share")
   # address=$(echo "$json_array" | jq -r ".[$i].address")
   # echo "Name: $name, Age: $age"
    forge create --rpc-url  https://sepolia-rollup.arbitrum.io/rpc --private-key 0xf0449a9e98fd9e88a908e9eac799afc5cc904f0c1417f29f8bacd66d3cd86c18 --constructor-args \"$name\" \"$symbol\" 1000000000000000000000 --verifier-url \'sepolia-explorer.arbitrum.io/api?\' --verify ./src/mocks/erc20.sol:MockERC20 --verifier blockscout
done
