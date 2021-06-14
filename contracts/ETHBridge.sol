pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./TransferHelper.sol";

contract ETHBridge is Ownable {
    using SafeMath for uint256;
    address public signer;
    mapping(string => bool) public executed;

    event Transit(
        address indexed ercToken,
        address indexed to,
        uint256 indexed amount
    );
    event Withdraw(
        address indexed ercToken,
        address indexed to,
        uint256 indexed amount,
        string withdrawId
    );

    constructor(address _signer) public {
        signer = _signer;
    }

    function transit(address _ercToken, uint256 _amount) external {
        require(_amount > 0, "amount must be greater than 0");
        TransferHelper.safeTransferFrom(
            _ercToken,
            msg.sender,
            address(this),
            _amount
        );
        emit Transit(_ercToken, msg.sender, _amount);
    }

    function withdraw(
        bytes calldata _signature,
        string memory _withdrawId,
        address _ercToken,
        uint256 _amount
    ) external {
        require(!executed[_withdrawId], "already withdraw");
        require(_amount > 0, "amount must be greater than 0");

        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        bytes32 message =
            keccak256(
                abi.encodePacked(
                    chainId,
                    address(this),
                    _ercToken,
                    _amount,
                    msg.sender,
                    _withdrawId
                )
            );
        bytes32 signature =
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
            );

        require(
            ECDSA.recover(signature, _signature) == signer,
            "invalid signature"
        );

        TransferHelper.safeTransfer(_ercToken, msg.sender, _amount);
        executed[_withdrawId] = true;
        emit Withdraw(_ercToken, msg.sender, _amount, _withdrawId);
    }

    function changeSigner(address _signer) external onlyOwner {
        signer = _signer;
    }
}
