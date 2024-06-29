# Docker 运行 Airchains

docker 运行 ubuntu:22.04

```bash
docker pull ubuntu:22.04
//运行容器
docker run -it --name ubuntu-airchains ubuntu:22.04 /bin/bash
```
run

```bash
apt update 
apt install wget -y 
wget -O airchains.sh https://raw.githubusercontent.com/santuotuoge/sh/main/airchains.sh && chmod +x airchains.sh && ./airchains.sh
```
查看运行日志

```bash
tail -f $HOME/tracks/logfile.log -n200
```
刷tx

```bash
cd
addr=$($HOME/wasm-station/build/wasmstationd keys show node --keyring-backend test -a)
sudo tee spam.sh > /dev/null << EOF
#!/bin/bash

while true; do
  $HOME/wasm-station/build/wasmstationd tx bank send node ${addr} 1stake --from node --chain-id station-1 --keyring-backend test -y 
  sleep 6  # Add a sleep to avoid overwhelming the system or network
done
EOF

//后台运行
nohup bash spam.sh &
```
