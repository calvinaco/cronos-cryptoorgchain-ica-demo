#!/bin/bash

CRONOS_BINARY=./cronos/cronosd
CRYPTOORGCHAIN_BINARY=./cryptoorgchain/chain-maind
CHAIN_DIR=./data
CHAINID_1=cronosdevnet_1337-1
CHAINID_2=cryptoorgchaindevnet-2
GRPCPORT_1=8090
GRPCPORT_2=9090
GRPCWEB_1=8091
GRPCWEB_2=9091


echo "Starting $CHAINID_1 in $CHAIN_DIR..."
echo "Creating log file at $CHAIN_DIR/$CHAINID_1.log"
$CRONOS_BINARY start --log_level trace --log_format json --home $CHAIN_DIR/$CHAINID_1 --pruning=nothing --grpc.address="0.0.0.0:$GRPCPORT_1" --grpc-web.address="0.0.0.0:$GRPCWEB_1" > $CHAIN_DIR/$CHAINID_1.log 2>&1 &

echo "Starting $CHAINID_2 in $CHAIN_DIR..."
echo "Creating log file at $CHAIN_DIR/$CHAINID_2.log"
$CRYPTOORGCHAIN_BINARY start --log_level trace --log_format json --home $CHAIN_DIR/$CHAINID_2 --pruning=nothing --grpc.address="0.0.0.0:$GRPCPORT_2" --grpc-web.address="0.0.0.0:$GRPCWEB_2" > $CHAIN_DIR/$CHAINID_2.log 2>&1 &
