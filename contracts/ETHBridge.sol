pragma solidity 0.7.3;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './TransferHelper.sol';

contract ETHBridge is Ownable {
    using SafeMath for uint;
    address public signer;
    mapping(string => bool) public executed;

    event Transit(address indexed ercToken, address indexed to, uint256 indexed amount);
    event Withdraw(address indexed ercToken, address indexed to, uint256 indexed amount, string withdrawId);

    constructor(address _signer) public {
        signer = _signer;
    }

    function transit(address _ercToken, uint256 _amount) external {
        require(_amount > 0, "amount must be greater than 0");
        TransferHelper.safeTransferFrom(_ercToken, msg.sender, address(this), _amount);
        emit Transit(_ercToken, msg.sender, _amount);
    }

    function withdraw(bytes calldata _signature, string memory _withdrawId, address _ercToken, uint _amount) external {
        require(!executed[_withdrawId], "already withdraw");
        require(_amount > 0, "amount must be greater than 0");

        uint chainId;
        assembly {
            chainId := chainid()
        }
        bytes32 message = keccak256(abi.encodePacked(chainId, address(this), _ercToken, _amount, msg.sender, _withdrawId));
        bytes32 signature = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        require(_recoverAddress(signature, _signature) == signer, "invalid signature");

        TransferHelper.safeTransfer(_ercToken, msg.sender, _amount);
        executed[_withdrawId] = true;
        emit Withdraw(_ercToken, msg.sender, _amount, _withdrawId);
    }

    function changeSigner(address _signer) onlyOwner external {
        signer = _signer;
    }

    function _recoverAddress(bytes32 _hash, bytes memory _signatures) pure public returns(address) {
        uint8 v;
        bytes32 r;
        bytes32 s;
        
        uint offset = 0 * 65;
        assembly {
            r := mload(add(_signatures, add(32, offset)))
            s := mload(add(_signatures, add(64, offset)))
            v := and(mload(add(_signatures, add(65, offset))), 0xff)
        }
        if (v < 27) v += 27;
        require(v == 27 || v == 28);
        
        return ecrecover(_hash, v, r, s);
    }
}