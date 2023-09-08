# deploy multipool contract
forge create --rpc-url  https://sepolia-rollup.arbitrum.io/rpc --private-key 0xf0449a9e98fd9e88a908e9eac799afc5cc904f0c1417f29f8bacd66d3cd86c18 --constructor-args "Arbitrum altcoin index" "ARBI" --verifier-url sepolia-explorer.arbitrum.io/api --verify ./src/multipool/Multipool.sol:Multipool --verifier blockscout --json

# multipool verification 
forge verify-contract 0x936154414520a1d925f15a2ee88a1ce31ae24c1e ./src/multipool/multipool.sol:multipool --verifier blockscout --verifier-url 'https://sepolia-explorer.arbitrum.io/api?' --chain 421614 --watch --constructor-args $(cast abi-encode "constructor(string,string)" "arbitrum altcoin index" "arbi") --num-of-optimizations 20000 --retries 1

# transfer tokens
cast send --rpc-url  https://sepolia-rollup.arbitrum.io/rpc --private-key 0
xf0449a9e98fd9e88a908e9eac799afc5cc904f0c1417f29f8bacd66d3cd86c18 0x167b876620dd8531c7a47da89ea32a1a37680407 "transfer(address,uint)" 0x936
154414520a1d925F15a2EE88A1cE31AE24C1E 10000000000000000000

# set share 
cast send --rpc-url  https://sepolia-rollup.arbitrum.io/rpc --private-key 0
xf0449a9e98fd9e88a908e9eac799afc5cc904f0c1417f29f8bacd66d3cd86c18 0x936154414520a1d925F15a2EE88A1cE31AE24C1E "updateTargetShares(address[],
uint[])" "[0x167b876620dd8531c7a47da89ea32a1a37680407,0xc2e9c976cacfc317431c0856d5ff879c84cd6dd8,0xA54Fe9d87Dc7ab521Ce0D868eaE5678F7A37E489
,0x58c1cE9632a3303EC1529c1Ebd55E0B9b97Db62A,0xa6d918bee60067228ceb1ef8cdf2438ec33be6c9]" "[10000000000000000000,10000000000000000000,100000
00000000000000,10000000000000000000,10000000000000000000]"

# set deviation limit
cast send --rpc-url  https://sepolia-rollup.arbitrum.io/rpc --private-key 0
xf0449a9e98fd9e88a908e9eac799afc5cc904f0c1417f29f8bacd66d3cd86c18 0x936154414520a1d925F15a2EE88A1cE31AE24C1E "setDeviationLimit(uint)" 1000
00000000000000

# set half deviation fee 
cast send --rpc-url  https://sepolia-rollup.arbitrum.io/rpc --private-key 0
xf0449a9e98fd9e88a908e9eac799afc5cc904f0c1417f29f8bacd66d3cd86c18 0x936154414520a1d925F15a2EE88A1cE31AE24C1E "setHalfDeviationFee(uint)" 300000000000000


#mint
cast send --rpc-url  https://sepolia-rollup.arbitrum.io/rpc --private-key 0
xf0449a9e98fd9e88a908e9eac799afc5cc904f0c1417f29f8bacd66d3cd86c18 0x936154414520a1d925F15a2EE88A1cE31AE24C1E "mint(address,uint, address)" 
0x167b876620dd8531c7a47da89ea32a1a37680407 10000000000000000000 0x588F899FeFf77CD4f34D05eC435ed435A31DecCd

token_symbols=("ETH" "BTC" "" "value4")

# Iterate over the array and output its values
for symbol in "${token_symbols[@]}"; do
    echo "$value"
    `forge create --rpc-url  https://sepolia-rollup.arbitrum.io/rpc --private-key \
        0xf0449a9e98fd9e88a908e9eac799afc5cc904f0c1417f29f8bacd66d3cd86c18 --constructor-args \
        "Arbitrum altcoin index" "ARBI" --verifier-url 'sepolia-explorer.arbitrum.io/api?' --verify\
        ./src/micks/erc20.sol:MockERC20 --verifier blockscout`
done
