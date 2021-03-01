pragma solidity 0.7.3;

import '@openzeppelin/contracts/access/Ownable.sol';
import './BEP20.sol';
import './TransferHelper.sol';

contract BSCBridge is Ownable {
    using SafeMath for uint;
    
    address signer;
    uint256 defaultTransitFee;

    mapping(address => uint256) transitFee;
    mapping(string => bool) executed;
    mapping(address => address) ercToBep;
    mapping(address => address) bepToErc;

    event Transit(address indexed ercToken, address indexed to, uint256 indexed amount, string transitId);
    event Payback(address indexed ercToken, address indexed to, uint256 amount);
    event CreateToken(address indexed bepToken, string indexed name, string indexed symbol);

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

    function transit(address _ercToken, string memory _name, string memory _symbol, uint256 _amount, string memory _transitId, bytes calldata _signature) external payable {
        require(!executed[_transitId], "already transit");
        require(_amount > 0, "amount must be greater than 0");

        bytes32 message = keccak256(abi.encodePacked(_ercToken, _amount, msg.sender, _transitId));
        bytes32 signature = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        address recoveredAddress = _recoverAddress(signature, _signature);
        require(recoveredAddress == signer, "invalid signature");

        if (ercToBep[_ercToken] == address(0)) {
            transitFee[_ercToken] = defaultTransitFee;
            
            bytes memory bytecode = abi.encodePacked(type(ItamERC20).creationCode, abi.encode(_name, _symbol));
            bytes32 salt = keccak256(abi.encodePacked(_ercToken, _name, _symbol));
            address newToken;
            assembly {
                newToken := create2(0, add(bytecode, 32), mload(bytecode), salt)
            }
            ercToBep[_ercToken] = newToken;
            bepToErc[newToken] = _ercToken;

            emit CreateToken(newToken, _name, _symbol);
        }
        require(transitFee[_ercToken] == msg.value, "invalid transit fee");

        ItamERC20(ercToBep[_ercToken]).mint(msg.sender, _amount);
        executed[_transitId] = true;
        emit Transit(_ercToken, msg.sender, _amount, _transitId);
    }

    function payback(address _bepToken, uint256 _amount) external payable {
        address ercToken = bepToErc[_bepToken];
        
        require(ercToken != address(0), "invalid token");
        require(_amount > 0, "amount must be greater than 0");
        require(transitFee[ercToken] == msg.value, "invalid transit fee");
        
        ItamERC20(_bepToken).burn(msg.sender, _amount);
        emit Payback(ercToken, msg.sender, _amount);
    }

    function transferTokenOwnership(address _bepToken, address _to) onlyOwner external {
        address ercToken = bepToErc[_bepToken];
        require(bepToErc[_bepToken] != address(0), "invalid token");

        ItamERC20(_bepToken).transferOwnership(_to);
        ercToBep[ercToken] = address(0);
        bepToErc[_bepToken] = address(0);
        transitFee[ercToken] = 0;
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