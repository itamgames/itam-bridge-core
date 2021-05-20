pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import './WrappedERC20.sol';
import './TransferHelper.sol';

contract MATBridge is Ownable {
    using SafeMath for uint;

    address public signer;
    uint256 public defaultTransitFee;

    mapping(address => uint256) public transitFee;
    mapping(string => bool) public executed;
    mapping(address => address) public ercToMat;
    mapping(address => address) public MatToErc;

    event Transit(address indexed ercToken, address indexed to, uint256 indexed amount, string transitId);
    event Payback(address indexed ercToken, address indexed to, uint256 amount);
    event CreateToken(address indexed matToken, string indexed name, string indexed symbol);

    constructor(address _signer, uint256 _defaultTransitFee) public {
        signer = _signer;
        defaultTransitFee = _defaultTransitFee;
    }

    function changeTransitFee(address ercToken, uint256 _transitFee) onlyOwner external {
        transitFee[ercToken] = _transitFee;
    }

    function changeSigner(address _signer) onlyOwner external {
        signer = _signer;
    }

    function withdrawFee(address _to, uint256 _amount) onlyOwner external {
        require(_to != address(0), "invalid address");
        require(_amount > 0, "amount must be greater than 0");
        TransferHelper.safeTransferETH(_to, _amount);
    }

    function transit(address _ercToken, string memory _name, string memory _symbol, uint256 _amount, string memory _transitId, uint256 feeAmount, bytes calldata _signature) external payable {
        require(!executed[_transitId], "already transit");
        require(_amount > 0, "amount must be greater than 0");

        uint chainId;
        assembly {
            chainId := chainid()
        }
        bytes32 message = keccak256(abi.encodePacked(chainId, address(this), _ercToken, _amount, msg.sender, _transitId, feeAmount));
        bytes32 signature = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        require(ECDSA.recover(signature, _signature) == signer, "invalid signature");

        if (ercToMat[_ercToken] == address(0)) {
            transitFee[_ercToken] = defaultTransitFee;

            bytes memory bytecode = abi.encodePacked(type(WrappedERC20).creationCode, abi.encode(_name, _symbol));
            bytes32 salt = keccak256(abi.encodePacked(_ercToken, _name, _symbol));
            address newToken;
            assembly {
                newToken := create2(0, add(bytecode, 32), mload(bytecode), salt)
            }
            ercToMat[_ercToken] = newToken;
            MatToErc[newToken] = _ercToken;

            emit CreateToken(newToken, _name, _symbol);
        }
        require(transitFee[_ercToken] == msg.value, "invalid transit fee");

        WrappedERC20(ercToMat[_ercToken]).mint(msg.sender, _amount);
        executed[_transitId] = true;
        emit Transit(_ercToken, msg.sender, _amount, _transitId);
    }

    function payback(address _matToken, uint256 _amount) external payable {
        address ercToken = MatToErc[_matToken];

        require(ercToken != address(0), "invalid token");
        require(_amount > 0, "amount must be greater than 0");
        require(transitFee[ercToken] == msg.value, "invalid transit fee");

        WrappedERC20(_matToken).burn(msg.sender, _amount);
        emit Payback(ercToken, msg.sender, _amount);
    }

    function transferTokenOwnership(address _matToken, address _to) onlyOwner external {
        address ercToken = MatToErc[_matToken];
        require(MatToErc[_matToken] != address(0), "invalid token");

        WrappedERC20(_matToken).transferOwnership(_to);
        ercToMat[ercToken] = address(0);
        MatToErc[_matToken] = address(0);
        transitFee[ercToken] = 0;
    }
}
