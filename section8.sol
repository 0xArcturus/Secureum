pragma solidity 0.8.0;

interface ERC721TokenReceiver {
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external returns (bytes4);
}

// Assume that all strictly required ERC721 functionality (not shown) is implemented correctly
// Assume that any other required functionality (not shown) is implemented correctly
contract InSecureumNFT {
    bytes4 internal constant MAGIC_ERC721_RECEIVED = 0x150b7a02;
    uint public constant TOKEN_LIMIT = 10; // 10 for testing, 13337 for production
    uint public constant SALE_LIMIT = 5; // 5 for testing, 1337 for production

    mapping(uint256 => address) internal idToOwner;

    uint internal numTokens = 0;
    uint internal numSales = 0;

    address payable internal deployer;
    address payable internal beneficiary;

    bool public publicSale = false;

    uint private price;

    uint public saleStartTime;

    uint public constant saleDuration = 13 * 13337; // 13337 blocks assuming 13s block times

    uint internal nonce = 0;

    uint[TOKEN_LIMIT] internal indices;

    constructor(address payable _beneficiary) {
        deployer = payable(msg.sender);
        beneficiary = _beneficiary;
    }

    function startSale(uint _price) external {
        require(
            msg.sender == deployer || _price != 0,
            "Only deployer and price cannot be zero"
        ); //deployer or price be 0, error
        price = _price;
        saleStartTime = block.timestamp;
        publicSale = true;
    }

    function isContract(
        address _addr
    ) internal view returns (bool addressCheck) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        addressCheck = size > 0; //true if size > 0
        //view? does it change state? no
    }

    //no queda claro lo que hace esta funcion por el nombre
    function randomIndex() internal returns (uint) {
        uint totalSize = TOKEN_LIMIT - numTokens; //remaining size
        uint index = uint(
            keccak256(
                abi.encodePacked(
                    nonce,
                    msg.sender,
                    block.difficulty,
                    block.timestamp
                )
            )
        ) % totalSize; //block diff, and timestamp arent random
        uint value = 0;
        //si valor del array de indices en la posicion random ya existe
        //el valor es copiado en value
        if (indices[index] != 0) {
            value = indices[index];
        } else {
            //sino, el valor random es el value
            value = index;
        }
        //chequea si es el ultimo token que se mintea
        if (indices[totalSize - 1] == 0) {
            indices[index] = totalSize - 1; //guarda en el array el valor 0
        } else {
            indices[index] = indices[totalSize - 1]; //copia posicion en memoria?
            //
        }
        nonce += 1;
        return (value + 1);
    }

    // Calculate the mint price

    //price is lower the more time passes
    function getPrice() public view returns (uint) {
        require(publicSale, "Sale not started.");
        uint elapsed = block.timestamp - saleStartTime;
        if (elapsed > saleDuration) {
            return 0;
        } else {
            return ((saleDuration - elapsed) * price) / saleDuration;
        }
    }

    // SALE_LIMIT is 1337
    // Rest i.e. (TOKEN_LIMIT - SALE_LIMIT) are reserved for community distribution (not shown)
    function mint() external payable returns (uint) {
        require(publicSale, "Sale not started.");
        require(numSales < SALE_LIMIT, "Sale limit reached.");
        //checks ok
        numSales++;

        uint salePrice = getPrice();

        //address this to check against?
        require(
            (address(this)).balance >= salePrice,
            "Insufficient funds to purchase."
        );
        //redundant
        if ((address(this)).balance >= salePrice) {
            //le pasa el balance entero menos el precio de venta?
            //asume que le ha enviado una cantidad al contrato por encima de lo estipulado y le devuelve el sobrante.

            payable(msg.sender).transfer((address(this)).balance - salePrice); //vulnerable a reentrancy?
            //se envia 4, sale price es 1
            //nos devuelve 4-1, 3,
            //chequea de nuevo 1=1 mintea solo 1 pero quita la posibilidad de tener otros por ir x2 en el sale limit.
        }
        return _mint(msg.sender);
        //returns id
    }

    // TOKEN_LIMIT is 13337
    function _mint(address _to) internal returns (uint) {
        require(numTokens < TOKEN_LIMIT, "Token limit reached.");
        // Lower indexed/numbered NFTs have rare traits and may be considered
        // as more valuable by buyers => Therefore randomize
        uint id = randomIndex();
        //checks if it can recieve erc721 with function onERC721Recieved hook
        if (isContract(_to)) {
            bytes4 retval = ERC721TokenReceiver(_to).onERC721Received(
                msg.sender,
                address(0),
                id,
                ""
            );
            require(retval == MAGIC_ERC721_RECEIVED);
        }
        require(idToOwner[id] == address(0), "Cannot add, already owned.");

        idToOwner[id] = _to; //update mapping
        numTokens = numTokens + 1; //update the number of tokens
        beneficiary.transfer((address(this)).balance); //transfers value to beneficiary
        return id;
    }
}
