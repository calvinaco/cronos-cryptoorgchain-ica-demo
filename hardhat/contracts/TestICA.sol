// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TestICA {
    // sha256('cronos-evm')[:20]
    address constant moduleAddress = 0x89A7EF2F08B1c018D5Cc88836249b84Dd5392905;
    address constant icaContract = 0x0000000000000000000000000000000000000066;
    string constant connectionID = "connection-0";

    struct ICAResult {
        bool acknowledgement;
        string error;
        bool timeout;
    }

    mapping(uint256 => address) public icaPacketSequenceToSender;
    mapping(uint256 => ICAResult) public icaPacketSequenceToResult;

    function nativeRegister() public  {
        (bool result,) = icaContract.call(abi.encodeWithSignature(
            "registerAccount(string,address)",
            connectionID, msg.sender
        ));
        require(result, "native call failed");
    }

    function nativeQueryAccount(address addr) public returns (string memory) {
        (bool result, bytes memory data) = icaContract.call(abi.encodeWithSignature(
            "queryAccount(string,address)",
            connectionID, addr
        ));
        require(result, "native call failed");
        return abi.decode(data, (string));
    }

    function nativeSubmitMsgs() public returns (uint256) {
        (bool result, bytes memory data) = icaContract.call(abi.encodeWithSignature(
            "submitMsgs(string,address,string,uint256)",
            connectionID, msg.sender, '[{"@type":"/cosmos.bank.v1beta1.MsgSend","from_address":"tcro13jga8sxeuvp02nm2u2scvskfq7dxrcxjvk4epy0hmh94nznexchsrvjhlj","to_address":"tcro1yademsjml2m7zsjrn6hpwkug9eqv76k5dexhps","amount":[{"denom":"basetcro","amount":"1"}]}]', 300000000000
        ));
        require(result, "native call failed");
        icaPacketSequenceToSender[abi.decode(data, (uint256))] = msg.sender;
        return abi.decode(data, (uint256));
    }

    function onICAPacketResult(uint256 sequence) public {
        require(msg.sender == moduleAddress);
        icaPacketSequenceToResult[sequence] = ICAResult(true, "", false);
    }

    function onICAPacketError(uint256 sequence, string calldata error) public {
        require(msg.sender == moduleAddress);
        icaPacketSequenceToResult[sequence] = ICAResult(false, error, false);
    }

    function onICAPacketTimeout(uint256 sequence) public {
        require(msg.sender == moduleAddress);
        icaPacketSequenceToResult[sequence] = ICAResult(false, "", true);
    }
}