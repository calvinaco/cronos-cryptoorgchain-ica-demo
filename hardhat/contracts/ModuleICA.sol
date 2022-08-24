//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract ModuleICA {
    function onICAPacketResult(string calldata channelID, uint256 sequence) public {}
    function onICAPacketError(string calldata channelID, uint256 sequence, string calldata error) public {}
    function onICAPacketTimeout(string calldata channelID, uint256 sequence) public {}
}
