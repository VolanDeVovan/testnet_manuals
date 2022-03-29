if [[ -z "$ALCHEMY" ]]; then
    echo -e "\e[1m\e[31mMust provide ALCHEMY in environment\e[0m" 1>&2

    exit 1
fi

echo "=================================================="

echo -e "\e[1m\e[32m1. Updating dependencies... \e[0m" && sleep 1
sudo apt update
sudo apt -y upgrade

echo "=================================================="

echo -e "\e[1m\e[32m2. Installing required dependencies... \e[0m" && sleep 1
sudo apt -y install curl git
sudo apt -y install python3 python3-venv python3-dev
sudo apt -y install build-essential libgmp-dev pkg-config libssl-dev

curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable


echo "=================================================="

echo -e "\e[1m\e[32m3. Setting up Starknet fullnode ... \e[0m" && sleep 1
cd $HOME
rm -rf starknet

git clone --branch v0.1.6-alpha https://github.com/eqlabs/pathfinder.git

cd $HOME/pathfinder/py
python3 -m venv .venv

source .venv/bin/activate

PIP_REQUIRE_VIRTUALENV=true pip install --upgrade pip
PIP_REQUIRE_VIRTUALENV=true pip install -r requirements-dev.txt


source $HOME/.cargo/env
cargo build --release --bin pathfinder
cp $HOME/pathfinder/target/release/pathfinder /usr/local/bin/

echo "[Unit]
Description=StarkNet
After=network.target

[Service]
User=$USER
Type=simple
WorkingDirectory=$HOME/pathfinder/py
ExecStart=/bin/bash -c \"source $HOME/pathfinder/py/.venv/bin/activate && /usr/local/bin/pathfinder --http-rpc=\"0.0.0.0:9545\" --ethereum.url $ALCHEMY\"
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target" > $HOME/starknetd.service

mv $HOME/starknetd.service /etc/systemd/system/
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
sudo systemctl enable starknetd
sudo systemctl restart starknetd
