const { expect } = require("chai");

describe("ERC20 to BEP20", function() {
    it("Swap", async function() {
        const BSCBridge = await ethers.getContractFactory("BSCBridge");
        const bscBridge = await BSCBridge.deploy("");
    });
});