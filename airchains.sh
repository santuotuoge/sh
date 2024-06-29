#!/bin/bash


function install_all() {
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>安装环境<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  apt-get update
  if ! command -v git &> /dev/null
  then
      echo "Git is not installed. Installing Git..."
       apt-get install git -y
  else
      echo "Git is already installed."
  fi

  if ! command -v wget &> /dev/null
  then
      echo "wget is not installed. Installing wget..."
       apt-get install wget -y
  else
      echo "wget is already installed."
  fi

  if ! command -v go &> /dev/null
  then
      echo "Go is not installed. Installing Go..."
      wget https://dl.google.com/go/go1.22.4.linux-amd64.tar.gz
      tar -C /usr/local -xzf go1.22.4.linux-amd64.tar.gz
  else
      echo "Go is already installed."
  fi

  if ! command -v  jq &> /dev/null
  then
     echo "jq is not installed. Installing jq..."
     apt-get install jq build-essential -y
  else
      echo "jq is already installed."
  fi

  if ! command -v make &> /dev/null
  then
      apt-get install make -y
  else
      echo "make is already installed."
  fi

  if ! command -v curl &> /dev/null
  then
      apt-get install curl -y
  else
      echo "curl is already installed."
  fi
}

function env() {
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>配置go环境<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  # Configure Go environment variables
  if [ -f "$HOME/.profile" ]; then
      setup_go_env "$HOME/.profile"
  elif [ -f "$HOME/.bashrc" ]; then
      setup_go_env "$HOME/.bashrc"
  else
      echo "无法重新加载环境变量"
      exit 1
  fi
  source $HOME/.profile || source $HOME/.bashrc

  go version
}

function setup_go_env() {
    echo "export PATH=\$PATH:/usr/local/go/bin" >> "$1"
    echo "export GOPATH=\$HOME/go" >> "$1"
    echo "export GOBIN=\$GOPATH/bin" >> "$1"
    echo "export GOROOT=/usr/local/go" >> "$1"
}

function run_wasm() {
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>配置wasm<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  cd
  git clone https://github.com/airchains-network/wasm-station.git
  git clone https://github.com/airchains-network/tracks.git
  cd wasm-station
  go mod tidy
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>设置wasm-station<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  nohup /bin/bash ./scripts/local-setup.sh > /setup.log 2>&1 &
  sleep 300
  cat /setup.log
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>运行wasmstationd<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  nohup $HOME/wasm-station/build/wasmstationd start --api.enable > wasmstationd.log 2>&1 &
}

function run_station() {

  accountName="default-node"
  keyName="ttg"

  wget https://github.com/airchains-network/tracks/releases/download/v0.0.2/eigenlayer
  chmod +x eigenlayer
  mv eigenlayer /usr/local/bin/eigenlayer
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>输出Public Key hex<<<<<<<<<<<<<<<<<<<<<<<<<<<"

  public_key_hex=$(echo "password" | eigenlayer operator keys create -insecure --key-type ecdsa $keyName |grep 'Public Key hex')
  echo $public_key_hex

  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>配置Tracks<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  rm -rf ~/.tracks
  cd $HOME/tracks

  go mod tidy
  go run cmd/main.go init --daRpc "disperser-holesky.eigenda.xyz" --daKey "$public_key_hex" --daType "eigen" --moniker "$accountName" --stationRpc "http://127.0.0.1:26657" --stationAPI "http://127.0.0.1:1317" --stationType "wasm"

  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>创建airchains地址<<<<<<<<<<<<<<<<<<<<<<<<<<<"

  output=$(go run cmd/main.go keys junction --accountName $accountName --accountPath $HOME/.tracks/junction-accounts/keys)

  address=$(echo "$output" | grep -oP '(?<=Address: ).*')

  echo "领水地址: $address"

  echo "前往https://airchains.faucetme.pro领水"
  echo "领水后（输入 Y 或 y 确认，其他任意键取消），确认测试gas到账后执行下一步："

  read -r response

  if [[ "$response" == "Y" || "$response" == "y" ]]; then
      echo "继续执行..."
      # 在这里添加需要执行的操作
  else
      echo "脚本退出。"
      exit 1
  fi
  go run cmd/main.go prover v1WASM
  nodeid=$(grep "node_id" ~/.tracks/config/sequencer.toml | awk -F '"' '{print $2}')
  ip=$(curl -s4 ifconfig.me/ip)
  bootstrapNode=/ip4/$ip/tcp/2300/p2p/$nodeid
  echo $bootstrapNode
  go run cmd/main.go create-station --accountName $accountName  --accountPath $HOME/.tracks/junction-accounts/keys --jsonRPC "https://junction-testnet-rpc.synergynodes.com/" --info "WASM Track" --tracks $address --bootstrapNode "$bootstrapNode"

  nohup go run cmd/main.go start > logfile.log 2>&1 &

}

function system_start() {
   install_all
   env
   run_wasm
   run_station
}

system_start
