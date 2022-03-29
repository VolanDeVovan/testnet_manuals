# starknet node setup
For starknet node you have to create account on alchemy.com and create application 

1. Register on alchemy.com
2. Create application (chain: ethereum, network: mainnet/goeril)
3. Copy http link 
Example: https://eth-goerli.alchemyapi.io/v2/...


## installation binary
Installation can take more than 10 minutes, it is recommended to run in a screen session:
```
screen -S starknet
```

Use script below for a quick installation:
Before running the script, you must execute this command, replacing the link with the one you received from alchemy.com
```
export ALCHEMY="https://eth-goerli.alchemyapi.io/v2/YOUR_UNIQUE_TOKEN"

wget -O starknet.sh https://raw.githubusercontent.com/VolanDeVovan/testnet_manuals/main/starknet/starknet.sh && chmod +x starknet.sh && ./starknet.sh
```