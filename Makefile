#!/usr/bin/make -f

CARGO = $(which -v cargo)
GO = $(shell command -v go)

.PHONY: has-cargo
has-cargo:
ifeq (, $(GO))
	@echo "Cargo not found. Please install Rust and try again."
	@exit 1
endif

.PHONY: has-go
has-go:
ifeq (, $(GO))
	@echo "Golang not found. Please install Golang and try again."
	@exit 1
endif

.PHONY: install
install: has-cargo
	@make install-hermes

.PHONY: install-hermes
install-hermes:
	cargo install --version 0.15.0 ibc-relayer-cli --bin hermes --locked

.PHONY: uninstall-hermes
uninstall-hermes:
	cargo uninstall ibc-relayer-cli

.PHONY: init
init: install
	@if [ ! -d "./cronos/" ]; then \
		mkdir cronos; \
		git clone https://github.com/calvinaco/cronos.git ./cronos/src/; \
		pushd ./; cd ./cronos/src; git checkout ica-evm; popd; \
	fi
	@if [ ! -d "./cryptoorgchain/" ]; then \
		mkdir cryptoorgchain; \
		git clone https://github.com/crypto-org-chain/chain-main.git ./cryptoorgchain/src/; \
		pushd ./; cd ./cronos/src; git checkout v4.0.0-alpha5-croeseid; popd; \
	fi

.PHONY: build
build: init has-go
	pushd ./; cd ./cronos/src; NETWORK=testnet make build; popd; cp ./cronos/src/build/cronosd ./cronos/cronods
	pushd ./; cd ./cryptoorgchain/src; NETWORK=testnet make build; popd; cp ./cryptoorgchain/src/build/chain-maind ./cryptoorgchain/chain-maind

.PHONY: init-network
init-network: build 
	@echo "Initializing both blockchains..."
	./network/init.sh
	@echo "Initializing relayer..." 
	./network/hermes/restore-keys.sh

.PHONY: bootstrap
bootstrap:
	@echo "Starting both blockchains..."
	./network/start.sh
	@echo "Establishing ICA channels..."
	@sleep 10
	./network/hermes/create-conn.sh
	@echo "Starting relayer..." 
	./network/hermes/start.sh

.PHONY: start-all
start-all:
	@echo "Starting both blockchains..."
	./network/start.sh
	@echo "Starting relayer..." 
	@sleep 10
	./network/hermes/start.sh

.PHONY: stop-all
stop-all:
	@echo "Killing both blockchains and hermes processes"
	-@killall cronosd 2>/dev/null
	-@killall chain-maind 2>/dev/null
	-@killall hermes 2>/dev/null

.PHONY: trace-network
trace-network:
	tail -f ./data/cronosdevnet_1337-1.log ./data/cryptoorgchaindevnet-2.log ./data/hermes.log

.PHONY: unsafe-clean-all
unsafe-clean-all:
	@echo "Removing previous data"
	-@rm -rf ./data
	-@make stop-all