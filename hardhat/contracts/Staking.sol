//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Staking {
    using SafeMath for uint256;

    // sha256('cronos-evm')[:20]
    address constant _moduleAddress =
        0x89A7EF2F08B1c018D5Cc88836249b84Dd5392905;
    address constant _icaContract = 0x0000000000000000000000000000000000000066;
    uint256 constant _ibcTimeout = 300000000000;

    struct PendingStakeRecord {
        address payable staker;
        uint256 amount;
    }

    struct StakeRecord {
        uint256 amount;
        uint256 height;
        uint256 outstandingReward;
    }

    address private _owner;

    string private _interchainAccount;

    string private _connectionID;

    string private _validatorAddress;

    uint256 private _basecroRewardRate; // in percentage

    uint256 private _totalStake;

    uint256 private _pendingUnstake;

    mapping(string => PendingStakeRecord) private _pendingStakes;
    mapping(address => StakeRecord) private _stakes;

    constructor(
        string memory connectionID_,
        string memory validatorAddress_,
        uint256 basecroRewardRate_
    ) {
        _connectionID = connectionID_;
        _validatorAddress = validatorAddress_;
        _basecroRewardRate = basecroRewardRate_;
        _owner = msg.sender;

        registerInterchainAccoutOf(address(this));
    }

    receive() external payable {}

    modifier onlyOwner() {
        require(msg.sender == _owner);
        _;
    }

    modifier onlyModuleAddress() {
        require(msg.sender == _moduleAddress);
        _;
    }

    modifier requireContractReady() {
        require(!isStringsEqual(_interchainAccount, ""));
        _;
    }

    function setup() public onlyOwner {
        require(
            isStringsEqual(_interchainAccount, ""),
            "contract already setup"
        );

        string memory interchainAccount = this.queryInterhainAccount(
            address(this)
        );
        require(!isStringsEqual(interchainAccount, ""), "contract Interchain Account is not ready yet");
        _interchainAccount = interchainAccount;
    }

    function stake() external payable requireContractReady {
        require(msg.value > 0, "must stake at least 1basecro");

        uint256 cocbasecro = msg.value.div(10000000000);
        // TODO: refund rounded basecro
        (bool result, bytes memory data) = _icaContract.call(
            abi.encodeWithSignature(
                "submitMsgs(string,address,string,uint256)",
                _connectionID,
                address(this),
                string(
                    abi.encodePacked(
                        '[{"@type":"/cosmos.staking.v1beta1.MsgDelegate","delegator_address":"',
                        _interchainAccount,
                        '","validator_address":"',
                        _validatorAddress,
                        '","amount":{"denom":"basetcro","amount":"',
                        Strings.toString(cocbasecro),
                        '"}}]'
                    )
                ),
                _ibcTimeout
            )
        );
        require(result, "native call submitMsgs failed");
        (string memory channelID, uint256 sequence) = abi.decode(
            data,
            (string, uint256)
        );

        uint256 basecro = cocbasecro.mul(10000000000);
        _totalStake = _totalStake.add(basecro);
        _pendingStakes[
            pendingStakeKey(channelID, sequence)
        ] = PendingStakeRecord(payable(msg.sender), basecro);
    }

    function unstake(uint256 amount) external {
        require(_stakes[msg.sender].amount >= amount, "insufficient stake");

        StakeRecord memory stakeRecord = _stakes[msg.sender];
        // updates the StakeRecord state to avoid reentrancy attack
        _stakes[msg.sender].amount = stakeRecord.amount.sub(amount);
        _stakes[msg.sender].height = block.number;
        (bool sent, ) = payable(msg.sender).call{
            value: amount.add(calculateReward(stakeRecord))
        }("");
        require(sent, "failed to send unstake amount and reward");

        if (_stakes[msg.sender].amount == 0) {
            delete _stakes[msg.sender];
        }
        _totalStake = _totalStake.sub(amount);
        _pendingUnstake = _pendingUnstake.add(amount);
    }

    function estimateReward() public view returns (uint256) {
        StakeRecord memory stakeRecord = _stakes[msg.sender];
        return calculateReward(stakeRecord);
    }

    function calculateReward(StakeRecord memory stakeRecord)
        internal
        view
        returns (uint256)
    {
        return
            stakeRecord.outstandingReward.add(
                stakeRecord.amount.mul(
                    _basecroRewardRate.mul(
                        block.number.sub(stakeRecord.height)
                    )
                ).div(100)
            );
    }

    function registerInterchainAccout() public {
        registerInterchainAccoutOf(msg.sender);
    }

    function registerInterchainAccoutOf(address account) internal {
        (bool result, ) = _icaContract.call(
            abi.encodeWithSignature(
                "registerAccount(string,address)",
                _connectionID,
                account
            )
        );
        require(result, "native call registerAccount failed");
    }

    function setConnectionID(string calldata connectionID_) public onlyOwner {
        _connectionID = connectionID_;
    }

    function setValidatorAddress(string calldata validatorAddress_)
        public
        onlyOwner
    {
        _validatorAddress = validatorAddress_;
    }

    function setValidatorAddress(uint256 basecroRewardRate_) public onlyOwner {
        _basecroRewardRate = basecroRewardRate_;
    }

    function getOwner() public view returns (address) {
        return _owner;
    }

    function getInterchainAccount() public view returns (string memory) {
        return _interchainAccount;
    }

    function getConnectionID() public view returns (string memory) {
        return _connectionID;
    }

    function getValidatorAddress() public view returns (string memory) {
        return _validatorAddress;
    }

    function getBasecroRewardRate() public view returns (uint256) {
        return _basecroRewardRate;
    }

    function totalStake() public view returns (uint256) {
        return _totalStake;
    }

    function pendingUnstake() public view returns (uint256) {
        return _pendingUnstake;
    }

    function getPendingStake(string calldata channelID, uint256 sequence)
        public
        view
        returns (address, uint256)
    {
        PendingStakeRecord memory pendingStakeRecord = _pendingStakes[
            pendingStakeKey(channelID, sequence)
        ];
        return (pendingStakeRecord.staker, pendingStakeRecord.amount);
    }

    function stakeOf(address account) public view returns (uint256, uint256) {
        StakeRecord memory stakeRecord = _stakes[account];
        return (stakeRecord.amount, stakeRecord.height);
    }

    function queryInterhainAccount(address account)
        public
        returns (string memory)
    {
        (bool result, bytes memory data) = _icaContract.call(
            abi.encodeWithSignature(
                "queryAccount(string,address)",
                _connectionID,
                account
            )
        );
        require(result, "native call queryAccount failed");
        return abi.decode(data, (string));
    }

    function balance() public view returns (uint256) {
        return address(this).balance;
    }

    // ICA Callbacks
    function onICAPacketResult(string calldata channelID, uint256 sequence)
        external
        onlyModuleAddress
    {
        require(isPendingStakeExist(channelID, sequence));
        PendingStakeRecord memory pendingStakeRecord = _pendingStakes[
            pendingStakeKey(channelID, sequence)
        ];
        StakeRecord memory stakeRecord = _stakes[pendingStakeRecord.staker];
        _stakes[pendingStakeRecord.staker] = StakeRecord(
            stakeRecord.amount.add(pendingStakeRecord.amount),
            block.number,
            calculateReward(stakeRecord)
        );
        deletePendingStake(channelID, sequence);
    }

    function isPendingStakeExist(string calldata channelID, uint256 sequence)
        internal
        view
        returns (bool)
    {
        return
            _pendingStakes[pendingStakeKey(channelID, sequence)].staker !=
            address(0);
    }

    function onICAPacketError(
        string calldata channelID,
        uint256 sequence,
        string calldata _error
    ) external onlyModuleAddress {
        require(isPendingStakeExist(channelID, sequence));
        PendingStakeRecord memory pendingStakeRecord = _pendingStakes[
            pendingStakeKey(channelID, sequence)
        ];

        _totalStake = _totalStake.sub(pendingStakeRecord.amount);
        refundPendingStake(pendingStakeRecord);
        deletePendingStake(channelID, sequence);
    }

    function onICAPacketTimeout(string calldata channelID, uint256 sequence)
        external
        onlyModuleAddress
    {
        require(isPendingStakeExist(channelID, sequence));
        PendingStakeRecord memory pendingStakeRecord = _pendingStakes[
            pendingStakeKey(channelID, sequence)
        ];

        _totalStake = _totalStake.sub(pendingStakeRecord.amount);
        refundPendingStake(pendingStakeRecord);
        deletePendingStake(channelID, sequence);
    }

    function refundPendingStake(PendingStakeRecord memory pendingStakeRecord)
        internal
    {
        (bool sent, ) = pendingStakeRecord.staker.call{
            value: pendingStakeRecord.amount
        }("");
        require(sent, "failed to refund stake amount back to staker");
    }

    function deletePendingStake(string calldata channelID, uint256 sequence)
        internal
    {
        delete _pendingStakes[pendingStakeKey(channelID, sequence)];
    }

    function pendingStakeKey(string memory channelID, uint256 sequence)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(channelID, Strings.toString(sequence)));
    }

    function isStringsEqual(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }
}
