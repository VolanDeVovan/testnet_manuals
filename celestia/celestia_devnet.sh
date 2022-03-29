#!/bin/bash

exists()
{
  command -v "$1" >/dev/null 2>&1
}
if exists curl; then
	echo ''
else
  sudo apt install curl -y < "/dev/null"
fi
bash_profile=$HOME/.bash_profile
if [ -f "$bash_profile" ]; then
    . $HOME/.bash_profile
fi

# devnet configuration
CELESTIA_APP_VERSION=$(curl -s "https://raw.githubusercontent.com/VolanDeVovan/testnet_manuals/main/celestia/latest_app.txt")
CELESTIA_NODE_VERSION=$(curl -s "https://raw.githubusercontent.com/VolanDeVovan/testnet_manuals/main/celestia/latest_node.txt")
if [[ ! $CELESTIA_CHAIN ]]; then
echo 'export CELESTIA_CHAIN=devnet-2' >> $HOME/.bash_profile
fi
. $HOME/.bash_profile
echo '==================================='
echo -e "Your chain id: \e[32m$CELESTIA_CHAIN\e[39m"
echo -e "Your app version: \e[32m$CELESTIA_APP_VERSION\e[39m"
echo -e "Your node version: \e[32m$CELESTIA_NODE_VERSION\e[39m"
echo '==================================='


function setupVarsApp {
if [[ ! $CELESTIA_NODENAME ]]; then
	read -p "Enter your node name: " CELESTIA_NODENAME
	echo 'export CELESTIA_NODENAME='${CELESTIA_NODENAME} >> $HOME/.bash_profile
fi
. $HOME/.bash_profile
echo -e '\e[32mYour node name:' $CELESTIA_NODENAME '\e[39m'
sleep 5
}


function setupVarsValidator {
if [[ ! $CELESTIA_WALLET ]]; then
	read -p "Enter wallet name: " CELESTIA_WALLET
	echo 'export CELESTIA_WALLET='${CELESTIA_WALLET} >> $HOME/.bash_profile
fi
if [[ ! $CELESTIA_PASSWORD ]]; then
	read -p "Enter wallet password: " CELESTIA_PASSWORD
	echo 'export CELESTIA_PASSWORD='${CELESTIA_PASSWORD} >> $HOME/.bash_profile
fi
. $HOME/.bash_profile
echo -e '\e[32mYour wallet name:' $CELESTIA_WALLET '\e[39m'
echo -e '\e[32mYour wallet password:' $CELESTIA_PASSWORD '\e[39m'
sleep 5
}


function setupVarsNodeBridge {
if [ ! $CELESTIA_RPC_IP ]; then
	read -p 'Enter your RPC IP or press enter use default [localhost]: ' CELESTIA_RPC_IP
	CELESTIA_RPC_IP=${CELESTIA_RPC_IP:-localhost}
	echo 'export CELESTIA_RPC_IP='$CELESTIA_RPC_IP >> $HOME/.bash_profile
	. $HOME/.bash_profile
fi
CELESTIA_RPC_ENDPOINT="http://$CELESTIA_RPC_IP:26657"
echo 'export CELESTIA_RPC_ENDPOINT='${CELESTIA_RPC_ENDPOINT} >> $HOME/.bash_profile
. $HOME/.bash_profile
echo -e '\e[32mYour RPC endpoint:' $CELESTIA_RPC_ENDPOINT '\e[39m'
# check response from rpc
if [ $(curl -LI $CELESTIA_RPC_ENDPOINT -o /dev/null -w '%{http_code}\n' -s) != '200' ]; then
	echo -e '\n\e[31mEndpoint' $CELESTIA_RPC_ENDPOINT 'is unreachable! Aborting setup!\e[39m'
	unset CELESTIA_RPC_IP
	exit 1
fi
sleep 5
}


function installDeps {
echo -e '\e[32m...INSTALLING/UPDATING DEPENDENCIES...\e[39m' && sleep 1
cd $HOME
sudo apt update
sudo apt install make clang pkg-config libssl-dev build-essential git jq expect -y < "/dev/null"
# install go
if [ -f "/usr/bin/go" ]; then
	echo 'go is already installed'
	go version
else
	curl https://dl.google.com/go/go1.17.2.linux-amd64.tar.gz | sudo tar -C/usr/local -zxvf -
	cat <<'EOF' >> $HOME/.bash_profile
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GO111MODULE=on
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
EOF
	. $HOME/.bash_profile
	cp /usr/local/go/bin/go /usr/bin
fi
}


function installApp {
echo -e '\e[32m...INSTALLING/UPDATING APP...\e[39m' && sleep 1
# install celestia app
rm -rf celestia-app
cd $HOME
git clone https://github.com/celestiaorg/celestia-app.git
cd celestia-app
git checkout $CELESTIA_APP_VERSION
make install
}


function installNode {
echo -e '\e[32m....INSTALLING/UPDATING NODE...\e[39m' && sleep 1
# install celestia node
cd $HOME
rm -rf celestia-node
git clone https://github.com/celestiaorg/celestia-node.git
cd celestia-node/
git checkout $CELESTIA_NODE_VERSION
make install
}


function initApp {
if [ -d $HOME/.celestia-app ]; then
	echo -e '\n\e[31mCelestia app is already initialized! Skipping!\e[39m' && sleep 1
	return 1
fi
# init celestia app
celestia-appd init $CELESTIA_NODENAME --chain-id $CELESTIA_CHAIN

# install celestia networks
cd $HOME
git clone https://github.com/celestiaorg/networks.git

# set network configs
cp $HOME/networks/$CELESTIA_CHAIN/genesis.json  $HOME/.celestia-app/config/

# update seeds
seeds='"74c0c793db07edd9b9ec17b076cea1a02dca511f@46.101.28.34:26656"'
echo $seeds
sed -i.bak -e "s/^seeds *=.*/seeds = $seeds/" $HOME/.celestia-app/config/config.toml

# open rpc
sed -i 's#"tcp://127.0.0.1:26657"#"tcp://0.0.0.0:26657"#g' $HOME/.celestia-app/config/config.toml

# set proper defaults
sed -i 's/timeout_commit = "5s"/timeout_commit = "15s"/g' $HOME/.celestia-app/config/config.toml
sed -i 's/index_all_keys = false/index_all_keys = true/g' $HOME/.celestia-app/config/config.toml

# config pruning
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="5000"
pruning_interval="10"

sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.celestia-app/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.celestia-app/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.celestia-app/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.celestia-app/config/app.toml

# reset
celestia-appd unsafe-reset-all

# download address book
wget -O $HOME/.celestia-app/config/addrbook.json "https://raw.githubusercontent.com/VolanDeVovan/testnet_manuals/main/celestia/addrbook.json"

# set client config
celestia-appd config chain-id $CELESTIA_CHAIN
celestia-appd config keyring-backend test

# install service
echo -e '\e[32m...CREATING SERVICE...\e[39m' && sleep 1
echo "[Unit]
Description=celestia-appd Cosmos daemon
After=network-online.target
[Service]
User=$USER
ExecStart=$HOME/go/bin/celestia-appd start
Restart=on-failure
RestartSec=3
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
" > $HOME/celestia-appd.service
sudo mv $HOME/celestia-appd.service /etc/systemd/system

sudo systemctl daemon-reload
sudo systemctl enable celestia-appd
sudo systemctl restart celestia-appd
echo -e '\e[32m...CHECKING NODE STATUS...\e[39m' && sleep 1
if [[ `service celestia-appd status | grep active` =~ "running" ]]; then
  echo -e "Your Celestia node \e[32minstalled successfully\e[39m!"
  echo -e 'To check app sync status: \e[32mcurl -s localhost:26657/status | jq .result | jq .sync_info\e[39m'
  
else
  echo -e "Your Celestia node \e[31mwas not installed correctly\e[39m, please reinstall."
fi
. $HOME/.bash_profile
}


function initNodeBridge {
if [ -d $HOME/.celestia-bridge ]; then
	echo -e '\n\e[31mCelestia bridge node is already initialized! Skipping!\e[39m' && sleep 1
	return 1
fi
echo -e '\e[32m....INITIALIZING BRIDGE NODE...\e[39m' && sleep 1
# do init
rm -rf $HOME/.celestia-bridge
celestia bridge init --core.remote $CELESTIA_RPC_ENDPOINT

# configure p2p
sed -i.bak -e 's/PeerExchange = false/PeerExchange = true/g' $HOME/.celestia-bridge/config.toml
BootstrapPeers="[\"/dns4/andromeda.celestia-devops.dev/tcp/2121/p2p/12D3KooWKvPXtV1yaQ6e3BRNUHa5Phh8daBwBi3KkGaSSkUPys6D\", \"/dns4/libra.celestia-devops.dev/tcp/2121/p2p/12D3KooWK5aDotDcLsabBmWDazehQLMsDkRyARm1k7f1zGAXqbt4\", \"/dns4/norma.celestia-devops.dev/tcp/2121/p2p/12D3KooWHYczJDVNfYVkLcNHPTDKCeiVvRhg8Q9JU3bE3m9eEVyY\"]"
sed -i -e "s|BootstrapPeers *=.*|BootstrapPeers = $BootstrapPeers|" $HOME/.celestia-bridge/config.toml

# install service
echo -e '\e[32m...CREATING SERVICE...\e[39m' && sleep 1
echo "[Unit]
Description=celestia-bridge node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which celestia) bridge start
Restart=on-failures
RestartSec=10
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
" > $HOME/celestia-bridge.service
sudo mv $HOME/celestia-bridge.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable celestia-bridge
sudo systemctl restart celestia-bridge
echo -e '\e[32m...CHECKING NODE STATUS...\e[39m' && sleep 1
if [[ `service celestia-bridge status | grep active` =~ "running" ]]; then
  echo -e "Your Celestia node \e[32minstalled successfully\e[39m!"
else
  echo -e "Your Celestia node \e[31mwas not installed correctly\e[39m, please reinstall."
fi
. $HOME/.bash_profile
echo -e 'To check app logs: \e[32mjournalctl -fu celestia-bridge -o cat\e[39m'
}

function initNodeLight {
if [ -d $HOME/.celestia-light ]; then
	echo -e '\n\e[31mCelestia light node is already initialized! Skipping!\e[39m' && sleep 1
	return 1
fi
echo -e '\e[32m....INITIALIZING LIGHT NODE...\e[39m' && sleep 1

# do init
rm -rf $HOME/.celestia-light
celestia light init

# configure p2p
BootstrapPeers="[\"/dns4/andromeda.celestia-devops.dev/tcp/2121/p2p/12D3KooWKvPXtV1yaQ6e3BRNUHa5Phh8daBwBi3KkGaSSkUPys6D\", \"/dns4/libra.celestia-devops.dev/tcp/2121/p2p/12D3KooWK5aDotDcLsabBmWDazehQLMsDkRyARm1k7f1zGAXqbt4\", \"/dns4/norma.celestia-devops.dev/tcp/2121/p2p/12D3KooWHYczJDVNfYVkLcNHPTDKCeiVvRhg8Q9JU3bE3m9eEVyY\"]"
sed -i -e "s|BootstrapPeers *=.*|BootstrapPeers = $BootstrapPeers|" $HOME/.celestia-light/config.toml

# install service
echo -e '\e[32m...CREATING SERVICE...\e[39m' && sleep 1
echo "[Unit]
Description=celestia-light node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which celestia) light start
Restart=on-failure
RestartSec=10
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
" > $HOME/celestia-light.service
sudo mv $HOME/celestia-light.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable celestia-light
sudo systemctl restart celestia-light
echo -e '\e[32m...CHECKING NODE STATUS...\e[39m' && sleep 1
if [[ `service celestia-light status | grep active` =~ "running" ]]; then
  echo -e "Your Celestia node \e[32minstalled successfully\e[39m!"
else
  echo -e "Your Celestia node \e[31mwas not installed correctly\e[39m, please reinstall."
fi
. $HOME/.bash_profile
echo -e 'To check app logs: \e[32mjournalctl -fu celestia-light -o cat\e[39m'
}


function createKey {
cd $HOME/celestia-app
echo -e "\e[32mWait some time before creating key...\e[39m"
sleep 20
sudo tee <<EOF >/dev/null $HOME/celestia-app/celestia_add_key.sh
#!/usr/bin/expect -f
EOF
echo "set timeout -1
spawn celestia-appd keys add $CELESTIA_WALLET --home $HOME/celestia-appd
match_max 100000
expect -exact \"Enter keyring passphrase:\"
send -- \"$CELESTIA_PASSWORD\r\"
expect -exact \"\r
Re-enter keyring passphrase:\"
send -- \"$CELESTIA_PASSWORD\r\"
expect eof" >> $HOME/celestia-app/celestia_add_key.sh
sudo chmod +x $HOME/celestia-app/celestia_add_key.sh
$HOME/celestia-app/celestia_add_key.sh &>> $HOME/celestia-app/$CELESTIA_WALLET.txt
echo -e "You can find your mnemonic by the following command:"
echo -e "\e[32mcat $HOME/celestia-app/$CELESTIA_WALLET.txt\e[39m"
export CELESTIA_WALLET_ADDRESS=`cat $HOME/celestia-app/$CELESTIA_WALLET.txt | grep address | awk '{split($0,addr," "); print addr[2]}' | sed 's/.$//'`
echo 'export CELESTIA_WALLET_ADDRESS='${CELESTIA_WALLET_ADDRESS} >> $HOME/.bash_profile
. $HOME/.bash_profile
echo -e '\e[32mYour wallet address:' $CELESTIA_WALLET_ADDRESS '\e[39m'
}


function syncCheck {
. $HOME/.bash_profile
while sleep 3; do
sync_info=`curl -s localhost:26657/status | jq .result.sync_info`
latest_block_height=`echo $sync_info | jq -r .latest_block_height`
echo -en "\r\rCurrent block: \e[32m$latest_block_height\e[39m"
if test `echo "$sync_info" | jq -r .catching_up` == false; then
echo -e "\nYour node was \e[32msynced\e[39m!"
break
else
echo -n ", syncing..."
fi
done
}


function deleteCelestia {
systemctl disable celestia-appd.service
systemctl disable celestia-bridge.service
systemctl disable celestia-light.service
systemctl stop celestia-appd.service
systemctl stop celestia-bridge.service
systemctl stop celestia-light.service
rm /etc/systemd/system/celestia-appd.service
rm /etc/systemd/system/celestia-bridge.service
rm /etc/systemd/system/celestia-light.service
systemctl daemon-reload
systemctl reset-failed
rm .celestia* -rf
rm celestia* -rf
rm networks -rf
rm $HOME/.bash_profile
rm /usr/bin/go -rf
}


PS3='Please enter your choice (input your option number and press enter): '
options=("Install/Update App" "Install/Update Node" "Initialize Bridge" "Initialize Light" "Sync Status" "Erase all" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Install/Update App")
            echo -e '\n\e[31mYou choose Install/Update app...\e[39m' && sleep 1
			setupVarsApp
			installDeps
			installApp
			initApp
			syncCheck
			break
            ;;
		"Install/Update Node")
            echo -e '\n\e[31mYou choose Install/Update bridge...\e[39m' && sleep 1
			if [ -d $HOME/.celestia-light ]; then
				echo -e '\n\e[31mPlease avoid installing both types of nodes (bridge, light) on the same instance! Aborting!\e[39m' && sleep 1
				exit 1
			fi
			installDeps
			installNode
			break
            ;;
		"Initialize Bridge")
            echo -e '\n\e[31mYou choose Initialize Bridge node...\e[39m' && sleep 1
			if [ -d $HOME/.celestia-light ]; then
				echo -e '\n\e[31mPlease avoid installing both types of nodes (bridge, light) on the same instance! Aborting!\e[39m' && sleep 1
				exit 1
			fi
			if [ ! -d $HOME/celestia-node ]; then
				installDeps
				installNode
			fi
			setupVarsNodeBridge
			initNodeBridge
			break
            ;;
		"Initialize Light")
            echo -e '\n\e[31mYou choose Initialize Light node...\e[39m' && sleep 1
			if [ -d $HOME/.celestia-bridge ]; then
				echo -e '\n\e[31mPlease avoid installing both types of nodes (bridge, light) on the same instance! Aborting!\e[39m' && sleep 1
				exit 1
			fi
			if [ ! -d $HOME/celestia-node ]; then
				installDeps
				installNode
			fi
			initNodeLight
			break
            ;;
		"Sync Status")
            echo -e '\n\e[31mYou choose Sync Status...\e[39m' && sleep 1
			syncCheck
			break
            ;;
		"Erase all")
            echo -e '\n\e[31mYou choose Erase all...\e[39m' && sleep 1
			deleteCelestia
			echo -e '\e[32mCelestia was successfully erased!\e[39m' && sleep 1
			break
            ;;
        "Quit")
            break
            ;;
        *) echo -e "\e[91minvalid option $REPLY\e[0m";;
    esac
done
