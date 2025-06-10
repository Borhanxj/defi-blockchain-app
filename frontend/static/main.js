// Global vars
let web3;
let userAccount;

// Contract addresses (update as needed)
const defiCoreAddress = "0x3A41542c477daE9829D70FA27a5dd5c999FcEd30";
const lendingCoreAddress = "0x49419A89e61Cf32120614315757BaaF48Cf05847"; // Replace with actual address
const arbitrAddress = "0xE9CC5564a25c1839720a111589081b9ED36153E9"

// Pools & Tokens in memory
const pools = [];
const poolTokens = [];

// Token label map (all lowercase)
const tokenMap = {
  "0x8c7c15e95d4cbf07386973bcc596328e64886623": "TokenA",
  "0x92572c68e39e19ce505c1ca3e46190bb8c3a53a8": "TokenB",
  "0x7213536212d2dd4f92d74a5eec1cd07abc234480": "TokenC",
  "0x5012be72b96b12377521fbdca2fefb38cd25ed75": "TokenD"
};


// Load pools from localStorage (if exists)
function loadPools() {
    const storedPools = localStorage.getItem('pools');
    const storedTokens = localStorage.getItem('poolTokens');
    if (storedPools && storedTokens) {
      try {
        pools.length = 0;
        poolTokens.length = 0;
        const p = JSON.parse(storedPools);
        const t = JSON.parse(storedTokens);
        p.forEach(pool => pools.push(pool));
        t.forEach(tok => poolTokens.push(tok));
      } catch {
        console.warn("Failed to parse stored pools");
      }
    }
  }
  
  // Save pools to localStorage
  function savePools() {
    localStorage.setItem('pools', JSON.stringify(pools));
    localStorage.setItem('poolTokens', JSON.stringify(poolTokens));
  }

  function updateTokenAddress(selectId, inputId) {
    const select = document.getElementById(selectId);
    const input = document.getElementById(inputId);
    if (select && input) {
      input.value = select.value || "";
    }
  }
  

window.onload = () => {
    loadPools();
  // Connect wallet
  const connectBtn = document.getElementById("connectWalletBtn");
  if (connectBtn) connectBtn.onclick = connectWallet;

  // Pool Generation Part
  const createPoolBtn = document.getElementById("createPoolBtn");
  if (createPoolBtn) createPoolBtn.onclick = createPool;

  const checkLiquidityBtn = document.getElementById("checkLiquidityButton");
  if (checkLiquidityBtn) checkLiquidityBtn.onclick = checkLiquidity;

  const checkPoolTokenBtn = document.getElementById("checkPoolTokenButton");
  if (checkPoolTokenBtn) checkPoolTokenBtn.onclick = checkPoolTokens;

  const mintBtn = document.getElementById("mintButton");
  if (mintBtn) mintBtn.onclick = mintTokens;

  // Approve tokens buttons
  const approvePoolBtn = document.getElementById("approveTokensBtn");
  if (approvePoolBtn) approvePoolBtn.onclick = approveTokensForPool;

  const approveLendingBtn = document.getElementById("approveLendingBtn");
  if (approveLendingBtn) approveLendingBtn.onclick = approveTokensForLendingCore;

  // AMM operation buttons (amm.html)
  const addLiquidityBtn = document.getElementById("addLiquidityButton");
  if (addLiquidityBtn) addLiquidityBtn.onclick = addLiquidity;  // Implement addLiquidity()

  const addLiquidityOneBtn = document.getElementById("addLiquidityOneButton");
  if (addLiquidityOneBtn) addLiquidityOneBtn.onclick = addLiquidityOneToken; // Implement addLiquidityOneToken()

  const removeLiquidityBtn = document.getElementById("removeLiquidityBtn");
  if (removeLiquidityBtn) removeLiquidityBtn.onclick = removeLiquidity; // Implement removeLiquidity()

  const swapBtn = document.getElementById("swapBtn");
  if (swapBtn) swapBtn.onclick = swapTokens; // Implement swapTokens()

  const mySharesBtn = document.getElementById("mySharesPoolBtn");
  if (mySharesBtn) mySharesBtn.onclick = readMyShares; // Implement readMyShares()

  const checkShareInfoBtn = document.getElementById("checkShareInfoBtn");
  if (checkShareInfoBtn) checkShareInfoBtn.onclick = readShares; // Implement readShares()

  const readTotalSharesBtn = document.getElementById("readTotalSharesBtn");
  if (readTotalSharesBtn) readTotalSharesBtn.onclick = readTotalShares; // Implement readTotalShares()

  // Token selects with address auto-update
  const tokenSelects = [
    { selectId: 'token-add-one-select', inputId: 'token-add-oned' },
    { selectId: 'token-select-swap', inputId: 'token-swap' },
    { selectId: 'tokenAlend', inputId: 'token-lend-a' },
    { selectId: 'tokenBlend', inputId: 'token-lend-b' }
  ];
  tokenSelects.forEach(({selectId, inputId}) => {
    const sel = document.getElementById(selectId);
    if (sel) {
      sel.onchange = () => updateTokenAddress(selectId, inputId);
    }
  });

  const lendAButton = document.getElementById("lendAButton");
  if (lendAButton) lendAButton.onclick = lendTokenA;

  const lendBButton = document.getElementById("lendBButton");
  if (lendBButton) lendBButton.onclick = lendTokenB;

  const borrowTokenAButton = document.getElementById("borrowTokenAButton");
  if (borrowTokenAButton) borrowTokenAButton.onclick =  borrowTokenA;

  const borrowTokenBButton = document.getElementById("borrowTokenBButton");
  if (borrowTokenBButton) borrowTokenBButton.onclick = borrowTokenB;

  const repayLoanButton = document.getElementById("repayLoanButton");
  if (repayLoanButton) repayLoanButton.onclick = repayLoanHandler;

  const withdrawTokenAButton = document.getElementById("withdrawTokenAButton");
  if (withdrawTokenAButton) withdrawTokenAButton.onclick = withdrawTokenAHandler;

  const withdrawTokenBButton = document.getElementById("withdrawTokenBButton");
  if (withdrawTokenBButton) withdrawTokenBButton.onclick = withdrawTokenBHandler;

  const liquidateUserButton = document.getElementById("liquidateUserButton");
  if (liquidateUserButton) liquidateUserButton.onclick = liquidateUser;

  const checkLoanBtn = document.getElementById("checkLoanBtn");
  if (checkLoanBtn) checkLoanBtn.onclick = readLoanForUser;

  const readPoolInfoButton = document.getElementById("readPoolInfoButton");
  if (readPoolInfoButton) readPoolInfoButton.onclick = readPoolStats;

  const checkHealthButton = document.getElementById("checkHealthButton");
  if (checkHealthButton) checkHealthButton.onclick = readHealthFactor;

  // Update UI on page load if pools already known
  updatePoolsUI();
};

// Connect wallet
async function connectWallet() {
  const output = document.getElementById("walletDisplay");
  if (!window.ethereum) {
    alert("🦊 MetaMask not detected. Please install it!");
    return;
  }
  try {
    await window.ethereum.request({ method: "eth_requestAccounts" });
    web3 = new Web3(window.ethereum);
    const accounts = await web3.eth.getAccounts();
    userAccount = accounts[0];
    if(output) output.textContent = `✅ Connected: ${userAccount}`;
  } catch (err) {
    if(output) output.textContent = `❌ Connection failed: ${err.message}`;
  }
}

// Create Pool Functionality
async function createPool() {
  const output = document.getElementById("output");
  const tokenA = document.getElementById("tokenA")?.value;
  const tokenB = document.getElementById("tokenB")?.value;
  const amountA = document.getElementById("amountA")?.value;
  const amountB = document.getElementById("amountB")?.value;

  if (!web3 || !userAccount) {
    if(output) output.textContent = "❌ Connect wallet first.";
    return;
  }
  if (!tokenA || !tokenB || !amountA || !amountB) {
    if(output) output.textContent = "❌ Fill all fields.";
    return;
  }
  if (tokenA === tokenB) {
    if(output) output.textContent = "❌ Token A and Token B must be different.";
    return;
  }

  if(output) output.textContent = "⏳ Creating pool...";

  try {
    const selector = web3.utils.sha3("createPool(address,address,uint256,uint256)").substring(0, 10);
    const params = web3.eth.abi.encodeParameters(
      ["address", "address", "uint256", "uint256"],
      [tokenA, tokenB, amountA, amountB]
    ).substring(2);
    const data = selector + params;

    const tx = {
      from: userAccount,
      to: defiCoreAddress,
      data
    };

    const receipt = await web3.eth.sendTransaction(tx);

    const eventSig = web3.utils.sha3("PoolCreated(address,address,address,address,uint256,uint256,uint256)");
    let poolAddress = null;
    let creator = null;

    for (const log of receipt.logs) {
      if (log.topics[0] === eventSig) {
        creator = web3.utils.toChecksumAddress("0x" + log.topics[1].slice(26));
        poolAddress = web3.eth.abi.decodeParameter("address", log.data.slice(0, 66));
        break;
      }
    }

    if (!poolAddress) {
      if (output) output.textContent = "❌ Pool created but address not found in logs.";
      return;
    }

    pools.push({ address: poolAddress, creator });
    poolTokens.push([tokenA.toLowerCase(), tokenB.toLowerCase()]);
    savePools();   // save to localStorage
    updatePoolsUI();

    if (output) output.textContent = `✅ Pool created at: ${poolAddress}\n⏳ Approving tokens...`;

    await approveToken(tokenA, poolAddress);
    await approveToken(tokenB, poolAddress);

    if (output) output.textContent += "\n✅ Approvals completed.";

  } catch (err) {
    if (output) output.textContent = "❌ Error: " + (err.message || err);
  }
}

// Approve tokens helper
async function approveToken(token, spender) {
  const selector = web3.utils.sha3("approve(address,uint256)").substring(0, 10);
  const params = web3.eth.abi.encodeParameters(["address", "uint256"], [spender, web3.utils.toWei("10000", "ether")]).substring(2);

  const tx = {
    from: userAccount,
    to: token,
    data: selector + params
  };

  await web3.eth.sendTransaction(tx);
}

// Approve tokens for Pool by Pool ID
async function approveTokensForPool() {
  const poolId = document.getElementById("approvePoolInput")?.value.trim();
  const output = document.getElementById("approveLog");
  if (output) output.textContent = "";

  if (!poolId || !poolId.startsWith("pool")) {
    if(output) output.textContent = "❌ Invalid Pool ID format.";
    return;
  }

  const idx = parseInt(poolId.replace("pool", ""));
  if (isNaN(idx) || !pools[idx]) {
    if(output) output.textContent = "❌ Pool not found.";
    return;
  }

  if (!web3 || !userAccount) {
    if(output) output.textContent = "❌ Connect wallet first.";
    return;
  }

  try {
    const pool = pools[idx];
    const tokens = poolTokens[idx];

    await approveToken(tokens[0], pool.address);
    await approveToken(tokens[1], pool.address);

    if(output) output.textContent = "✅ Tokens approved for pool.";
  } catch (err) {
    if(output) output.textContent = "❌ Error: " + err.message;
  }
}


// Approve tokens for DefiCore
async function approveTokensForDefiCore() {
  const tokenAddressA = document.getElementById("tokenAlend")?.value.trim();
  const tokenAddressB = document.getElementById("tokenBlend")?.value.trim();
  const output = document.getElementById("approveDefiLog");
  if (output) output.textContent = "";

  console.log("🔍 Approve DefiCore - Token A:", tokenAddressA);
  console.log("🔍 Approve DefiCore - Token B:", tokenAddressB);

  if (!web3 || !userAccount) {
    if (output) output.textContent = "❌ Connect wallet first.";
    console.log("❌ Web3 or userAccount not available");
    return;
  }

  try {
    await approveToken(tokenAddressA, defiCoreAddress);
    await approveToken(tokenAddressB, defiCoreAddress);

    console.log("✅ Tokens approved for DefiCore");
    if (output) output.textContent = "✅ Tokens approved for DefiCore.";
  } catch (err) {
    console.error("❌ Error approving for DefiCore:", err);
    if (output) output.textContent = "❌ Error: " + err.message;
  }
}


// Approve tokens for DefiCore
async function approveTokensForArbitr() {
  const tokenAddressA = document.getElementById("tokenAarbitr")?.value.trim();
  const tokenAddressB = document.getElementById("tokenBarbitr")?.value.trim();
  const output = document.getElementById("approveArbitrLog");
  if (output) output.textContent = "";

  console.log("🔍 Approve Arbitrageur - Token A:", tokenAddressA);
  console.log("🔍 Approve Arbitrageur - Token B:", tokenAddressB);

  if (!web3 || !userAccount) {
    if (output) output.textContent = "❌ Connect wallet first.";
    console.log("❌ Web3 or userAccount not available");
    return;
  }

  try {
    await approveToken(tokenAddressA, defiCoreAddress);
    await approveToken(tokenAddressB, defiCoreAddress);

    console.log("✅ Tokens approved for DefiCore");
    if (output) output.textContent = "✅ Tokens approved for Arbitraguer.";
  } catch (err) {
    console.error("❌ Error approving for Arbitrauger:", err);
    if (output) output.textContent = "❌ Error: " + err.message;
  }
}

// Approve tokens for LendingCore by Pool ID
async function approveTokensForLendingCore() {
  const poolId = document.getElementById("approveLendingInput")?.value.trim();
  const output = document.getElementById("approveLendingLog");
  if (output) output.textContent = "";

  if (!poolId || !poolId.startsWith("pool")) {
    if(output) output.textContent = "❌ Invalid Pool ID format.";
    return;
  }

  const idx = parseInt(poolId.replace("pool", ""));
  if (isNaN(idx) || !pools[idx]) {
    if(output) output.textContent = "❌ Pool not found.";
    return;
  }

  if (!web3 || !userAccount) {
    if(output) output.textContent = "❌ Connect wallet first.";
    return;
  }

  try {
    const pool = pools[idx];
    const tokens = poolTokens[idx];

    await approveToken(tokens[0], lendingCoreAddress);
    await approveToken(tokens[1], lendingCoreAddress);

    if(output) output.textContent = "✅ Tokens approved for LendingCore.";
  } catch (err) {
    if(output) output.textContent = "❌ Error: " + err.message;
  }
}

// Update the pool list UI
function updatePoolsUI() {
  const poolList = document.getElementById("poolsList");
  if (!poolList) return;
  poolList.innerHTML = "";

  const table = document.createElement("table");
  table.classList.add("styled-table");

  const thead = document.createElement("thead");
  thead.innerHTML = `
    <tr>
      <th>Pool ID</th>
      <th>Address</th>
      <th>Token A</th>
      <th>Token B</th>
      <th>Creator</th>
    </tr>
  `;
  table.appendChild(thead);

  const tbody = document.createElement("tbody");

  pools.forEach((pool, idx) => {
    const [tokenA, tokenB] = poolTokens[idx];
    const row = document.createElement("tr");
    row.innerHTML = `
      <td>Pool${idx}</td>
      <td><code>${pool.address}</code></td>
      <td>${tokenMap[tokenA.toLowerCase()] || tokenA}</td>
      <td>${tokenMap[tokenB.toLowerCase()] || tokenB}</td>
      <td>${pool.creator}</td>
    `;
    tbody.appendChild(row);
  });

  table.appendChild(tbody);
  poolList.appendChild(table);
}

// Check liquidity function
async function checkLiquidity() {
  const poolId = document.getElementById("liquidityPoolIdInput")?.value.trim();
  const output = document.getElementById("checkLiqOut");
  if (output) output.textContent = "";

  if (!poolId || !poolId.startsWith("pool")) {
    if(output) output.textContent = "❌ Invalid Pool ID format.";
    return;
  }

  const idx = parseInt(poolId.replace("pool", ""));
  if (isNaN(idx) || !pools[idx]) {
    if(output) output.textContent = "❌ Pool not found.";
    return;
  }

  if (!web3) {
    if(output) output.textContent = "❌ Connect wallet first.";
    return;
  }

  try {
    const poolAddress = pools[idx].address;

    if (!poolAddress) {
      if(output) output.textContent = "❌ Pool address not found.";
      return;
    }

    // Adjust these function signatures as per your contract ABI
    const liquidityASelector = web3.utils.sha3("liquidity0()").substring(0, 10);
    const liquidityBSelector = web3.utils.sha3("liquidity1()").substring(0, 10);

    const liquidityAResult = await web3.eth.call({ to: poolAddress, data: liquidityASelector });
    const liquidityBResult = await web3.eth.call({ to: poolAddress, data: liquidityBSelector });

    const decodedLiquidityA = web3.eth.abi.decodeParameter("uint256", liquidityAResult);
    const decodedLiquidityB = web3.eth.abi.decodeParameter("uint256", liquidityBResult);

    if(output) output.textContent = `📊 Liquidity for ${poolId} at ${poolAddress}:\n💧 liquidityA: ${decodedLiquidityA}\n💧 liquidityB: ${decodedLiquidityB}`;
  } catch (err) {
    if(output) output.textContent = "❌ Error reading liquidity: " + (err.message || err);
  }
}

// Check pool tokens function
async function checkPoolTokens() {
  const poolId = document.getElementById("addressPoolIdInput")?.value.trim();
  const output = document.getElementById("poolTokenNumOutAddr");
  if (output) output.textContent = "";

  if (!poolId || !poolId.startsWith("pool")) {
    if(output) output.textContent = "❌ Invalid Pool ID format.";
    return;
  }

  const idx = parseInt(poolId.replace("pool", ""));
  if (isNaN(idx) || !pools[idx]) {
    if(output) output.textContent = "❌ Pool not found.";
    return;
  }

  if (!web3) {
    if(output) output.textContent = "❌ Connect wallet first.";
    return;
  }

  try {
    const poolAddress = pools[idx].address;

    // Use ABI to call token0() and token1()
    const poolContractABI = [
      {
        constant: true,
        inputs: [],
        name: "token0",
        outputs: [{ name: "", type: "address" }],
        type: "function"
      },
      {
        constant: true,
        inputs: [],
        name: "token1",
        outputs: [{ name: "", type: "address" }],
        type: "function"
      }
    ];

    const contract = new web3.eth.Contract(poolContractABI, poolAddress);
    const tokenA = await contract.methods.token0().call();
    const tokenB = await contract.methods.token1().call();

    if(output) output.textContent = `Token A: ${tokenA || tokenA}\nToken B: ${tokenB|| tokenB}`;
  } catch (err) {
    if(output) output.textContent = "❌ Error: " + err.message;
  }
}

// Mint tokens function
async function mintTokens() {
  const tokenAddress = document.getElementById("mintTokenAddress")?.value.trim();
  const recipient = document.getElementById("spenderAddress")?.value.trim();
  const amount = document.getElementById("mintAmount")?.value.trim();
  const output = document.getElementById("mintOutput");
  if (output) output.textContent = "";

  console.log("🔍 Input Check");
  console.log("📦 Token Address:", tokenAddress);
  console.log("👤 Recipient:", recipient);
  console.log("💰 Amount:", amount);
  console.log("🔑 User Account:", userAccount);

  if (!web3 || !userAccount) {
    console.error("❌ Web3 or wallet not connected.");
    if (output) output.textContent = "❌ Connect wallet first.";
    return;
  }

  if (!tokenAddress || !recipient || !amount) {
    console.warn("⚠️ Missing input fields.");
    if (output) output.textContent = "❌ Fill all mint fields.";
    return;
  }

  try {
    const mintSelector = web3.utils.sha3("mint(address,uint256)").substring(0, 10);
    console.log("🧾 Mint Function Selector:", mintSelector);

    const mintParams = web3.eth.abi.encodeParameters(
      ["address", "uint256"],
      [recipient, amount]
    ).substring(2);
    console.log("📦 Encoded Parameters:", mintParams);

    const tx = {
      from: userAccount,
      to: tokenAddress,
      data: mintSelector + mintParams,
    };
    console.log("🚀 Transaction Object:", tx);

    const receipt = await web3.eth.sendTransaction(tx);
    console.log("✅ Mint Tx Receipt:", receipt);

    if (output) output.textContent = `✅ Minted successfully.\nTx Hash: ${receipt.transactionHash}`;

    try {
  
      await approveToken(tokenAddress, recipient);
  
      if(output) output.textContent = "✅ Tokens approved for pool.";
    } catch (err) {
      if(output) output.textContent = "❌ Error: " + err.message;
    }

    
  } catch (err) {
    console.error("❌ Minting Error:", err);
    if (output) output.textContent = "❌ Error: " + err.message;
  }
}


// Helper: get pool address by poolId string "poolX"
async function getPoolAddressFromId(poolId) {
  if (!poolId || !poolId.startsWith("pool")) return null;
  const idx = parseInt(poolId.replace("pool", ""));
  if (isNaN(idx)) return null;
  if (!pools[idx]) return null;
  return pools[idx].address;
}

// Add Liquidity to Pool
async function addLiquidity() {
    const output = document.getElementById("liquidityOutput");
    if (output) output.textContent = "";
  
    const poolId = document.getElementById("addLiqInput")?.value.trim();
    const amountA = document.getElementById("liquidityAmountA")?.value.trim();
    const amountB = document.getElementById("liquidityAmountB")?.value.trim();
  
    if (!poolId || !poolId.startsWith("pool")) {
      if (output) output.textContent = "❌ Invalid Pool ID format.";
      return;
    }
    const idx = parseInt(poolId.replace("pool", ""));
    if (isNaN(idx) || !pools[idx]) {
      if (output) output.textContent = "❌ Pool not found.";
      return;
    }
    if (!amountA || !amountB) {
      if (output) output.textContent = "❌ Please enter amounts for both tokens.";
      return;
    }
    if (!web3 || !userAccount) {
      if (output) output.textContent = "❌ Connect wallet first.";
      return;
    }
  
    try {
      const poolAddress = pools[idx].address;
  
      // Assuming your pool contract has a function 'addLiquidity(uint256,uint256)'
      const selector = web3.utils.sha3("addLiquidity(uint256,uint256)").substring(0, 10);
      const params = web3.eth.abi.encodeParameters(["uint256", "uint256"], [amountA, amountB]).substring(2);
      const data = selector + params;
  
      const tx = {
        from: userAccount,
        to: poolAddress,
        data
      };
  
      if (output) output.textContent = "⏳ Sending addLiquidity transaction...";
  
      const receipt = await web3.eth.sendTransaction(tx);
  
      if (output) output.textContent = `✅ Liquidity added successfully.\nTx Hash: ${receipt.transactionHash}`;
    } catch (err) {
      if (output) output.textContent = "❌ Error adding liquidity: " + (err.message || err);
    }
  }
  
  // Add One Token Liquidity to Pool
  async function addLiquidityOneToken() {
    const output = document.getElementById("addLiqOneOutput");
    if (output) output.textContent = "";
  
    const poolId = document.getElementById("addLiqOneInput")?.value.trim();
    const tokenAddress = document.getElementById("token-add-oned")?.value.trim();
    const amount = document.getElementById("liquidityAmountOneA")?.value.trim();
  
    if (!poolId || !poolId.startsWith("pool")) {
      if (output) output.textContent = "❌ Invalid Pool ID format.";
      return;
    }
    const idx = parseInt(poolId.replace("pool", ""));
    if (isNaN(idx) || !pools[idx]) {
      if (output) output.textContent = "❌ Pool not found.";
      return;
    }
    if (!tokenAddress) {
      if (output) output.textContent = "❌ Select a token to add.";
      return;
    }
    if (!amount) {
      if (output) output.textContent = "❌ Enter amount.";
      return;
    }
    if (!web3 || !userAccount) {
      if (output) output.textContent = "❌ Connect wallet first.";
      return;
    }
  
    try {
      const poolAddress = pools[idx].address;
  
      // Assuming pool contract has 'addLiquidityOneToken(address,uint256)'
      const selector = web3.utils.sha3("addLiquidityWithOneToken(address,uint256)").substring(0, 10);
      const params = web3.eth.abi.encodeParameters(["address", "uint256"], [tokenAddress, amount]).substring(2);
      const data = selector + params;
  
      const tx = {
        from: userAccount,
        to: poolAddress,
        data
      };
  
      if (output) output.textContent = "⏳ Sending addLiquidityOneToken transaction...";
  
      const receipt = await web3.eth.sendTransaction(tx);
  
      if (output) output.textContent = `✅ Liquidity (one token) added successfully.\nTx Hash: ${receipt.transactionHash}`;
    } catch (err) {
      if (output) output.textContent = "❌ Error adding liquidity (one token): " + (err.message || err);
    }
  }
  
  // Remove Liquidity from Pool
  async function removeLiquidity() {
    const output = document.getElementById("remLiqOut");
    if (output) output.textContent = "";
  
    const poolId = document.getElementById("liquidityRemovePoolIdInput")?.value.trim();
    const shareAmount = document.getElementById("shareInput")?.value.trim();
  
    if (!poolId || !poolId.startsWith("pool")) {
      if (output) output.textContent = "❌ Invalid Pool ID format.";
      return;
    }
    const idx = parseInt(poolId.replace("pool", ""));
    if (isNaN(idx) || !pools[idx]) {
      if (output) output.textContent = "❌ Pool not found.";
      return;
    }
    if (!shareAmount) {
      if (output) output.textContent = "❌ Enter share amount to remove.";
      return;
    }
    if (!web3 || !userAccount) {
      if (output) output.textContent = "❌ Connect wallet first.";
      return;
    }
  
    try {
      const poolAddress = pools[idx].address;
  
      // Assuming pool contract has 'removeLiquidity(uint256)'
      const selector = web3.utils.sha3("removeLiquidity(uint256)").substring(0, 10);
      const params = web3.eth.abi.encodeParameters(["uint256"], [shareAmount]).substring(2);
      const data = selector + params;
  
      const tx = {
        from: userAccount,
        to: poolAddress,
        data
      };
  
      if (output) output.textContent = "⏳ Sending removeLiquidity transaction...";
  
      const receipt = await web3.eth.sendTransaction(tx);
  
      if (output) output.textContent = `✅ Liquidity removed successfully.\nTx Hash: ${receipt.transactionHash}`;
    } catch (err) {
      if (output) output.textContent = "❌ Error removing liquidity: " + (err.message || err);
    }
  }
  
  // Swap Tokens in Pool
  async function swapTokens() {
    const output = document.getElementById("swapOutput");
    if (output) output.textContent = "";
  
    const tokenAddress = document.getElementById("token-swap")?.value.trim();
    const amountIn = document.getElementById("amountInInput")?.value.trim();
    const poolId = document.getElementById("swapPoolIdInput")?.value.trim();
  
    if (!tokenAddress) {
      if (output) output.textContent = "❌ Select token to swap.";
      return;
    }
    if (!amountIn) {
      if (output) output.textContent = "❌ Enter amount to swap.";
      return;
    }
    if (!poolId || !poolId.startsWith("pool")) {
      if (output) output.textContent = "❌ Invalid Pool ID format.";
      return;
    }
    const idx = parseInt(poolId.replace("pool", ""));
    if (isNaN(idx) || !pools[idx]) {
      if (output) output.textContent = "❌ Pool not found.";
      return;
    }
    if (!web3 || !userAccount) {
      if (output) output.textContent = "❌ Connect wallet first.";
      return;
    }
  
    try {
      const poolAddress = pools[idx].address;
  
      // Assuming pool contract has 'swap(address,uint256)'
      const selector = web3.utils.sha3("swap(address,uint256)").substring(0, 10);
      const params = web3.eth.abi.encodeParameters(["address", "uint256"], [tokenAddress, amountIn]).substring(2);
      const data = selector + params;
  
      const tx = {
        from: userAccount,
        to: poolAddress,
        data
      };
  
      if (output) output.textContent = "⏳ Sending swap transaction...";
  
      const receipt = await web3.eth.sendTransaction(tx);
  
      if (output) output.textContent = `✅ Swap successful.\nTx Hash: ${receipt.transactionHash}`;
    } catch (err) {
      if (output) output.textContent = "❌ Error during swap: " + (err.message || err);
    }
  }
  
  // Read My Shares in Pool
  async function readMyShares() {
    const output = document.getElementById("sharePoolOut");
    if (output) output.textContent = "";
  
    const poolId = document.getElementById("mySharePoolIdInput")?.value.trim();
  
    if (!poolId || !poolId.startsWith("pool")) {
      if (output) output.textContent = "❌ Invalid Pool ID format.";
      return;
    }
    const idx = parseInt(poolId.replace("pool", ""));
    if (isNaN(idx) || !pools[idx]) {
      if (output) output.textContent = "❌ Pool not found.";
      return;
    }
    if (!web3 || !userAccount) {
      if (output) output.textContent = "❌ Connect wallet first.";
      return;
    }
  
    try {
      const poolAddress = pools[idx].address;
  
      // Assuming pool contract has 'lpShares(address)'
      const selector = web3.utils.sha3("lpShares(address)").substring(0, 10);
      const encodedAddr = web3.eth.abi.encodeParameter("address", userAccount).substring(2);
      const data = selector + encodedAddr;
  
      const result = await web3.eth.call({ to: poolAddress, data });
      const shares = web3.eth.abi.decodeParameter("uint256", result);
  
      if (output) output.textContent = `Your LP shares in ${poolId}: ${shares}`;
    } catch (err) {
      if (output) output.textContent = "❌ Error reading shares: " + (err.message || err);
    }
  }
  
  // Read Total Shares in Pool
  async function readTotalShares() {
    const output = document.getElementById("sharePoolOut");
    if (output) output.textContent = "";
  
    const poolId = document.getElementById("mySharePoolIdInput")?.value.trim();
  
    if (!poolId || !poolId.startsWith("pool")) {
      if (output) output.textContent = "❌ Invalid Pool ID format.";
      return;
    }
    const idx = parseInt(poolId.replace("pool", ""));
    if (isNaN(idx) || !pools[idx]) {
      if (output) output.textContent = "❌ Pool not found.";
      return;
    }
    if (!web3) {
      if (output) output.textContent = "❌ Connect wallet first.";
      return;
    }
  
    try {
      const poolAddress = pools[idx].address;
  
      // Assuming pool contract has 'totalShares()'
      const selector = web3.utils.sha3("totalShares()").substring(0, 10);
  
      const result = await web3.eth.call({ to: poolAddress, data: selector });
      const totalShares = web3.eth.abi.decodeParameter("uint256", result);
  
      if (output) output.textContent = `Total LP shares in ${poolId}: ${totalShares}`;
    } catch (err) {
      if (output) output.textContent = "❌ Error reading total shares: " + (err.message || err);
    }
  }
  
  async function lendTokenA() {
    const poolId = document.getElementById("lendTokenApoolID").value.trim();
    const amount = document.getElementById("amountALend").value.trim();
    const resultBox = document.getElementById("lendResultA");
  
    try {
      const idx = parseInt(poolId.replace("pool", ""));
      const poolAddress = pools[idx]?.address;
  
      if (!web3.utils.isAddress(poolAddress)) {
        resultBox.textContent = "❌ Invalid pool address.";
        return;
      }
  
      const functionSig = web3.utils.sha3("lendTokenA(uint256,address)").substring(0, 10);
      const encodedParams = web3.eth.abi.encodeParameters(["uint256", "address"], [amount, poolAddress]).substring(2);
      const data = functionSig + encodedParams;
  
      const tx = await web3.eth.sendTransaction({
        from: userAccount,
        to: lendingCoreAddress,
        data: data,
      });
  
      resultBox.textContent = `✅ Token A lent to ${poolAddress}.\nTx Hash: ${tx.transactionHash}`;
    } catch (err) {
      console.error("LendTokenA error:", err);
      resultBox.textContent = "❌ " + (err.message || err);
    }
  }
  
  

  async function lendTokenB() {
    const poolId = document.getElementById("lendTokenBpoolID").value.trim();
    const amount = document.getElementById("amountB").value.trim();
    const resultBox = document.getElementById("lendResultB");
  
    try {
      const idx = parseInt(poolId.replace("pool", ""));
      const poolAddress = pools[idx]?.address;
  
      const functionSig = web3.utils.sha3("lendTokenB(address,uint256)").substring(0, 10);
      const encodedParams = web3.eth.abi.encodeParameters(["address", "uint256"], [poolAddress, amount]).substring(2);
      const data = functionSig + encodedParams;
  
      const tx = await web3.eth.sendTransaction({
        from: userAccount,
        to: lendingCoreAddress,
        data: data,
      });
  
      resultBox.textContent = `✅ Token B lent to ${poolAddress}.\nTx Hash: ${tx.transactionHash}`;
    } catch (err) {
      resultBox.textContent = "❌ " + (err.message || err);
    }
  }

  
  async function borrowTokenA() {
    const collateral = document.getElementById("collateralAmountA").value.trim();
    const amount = document.getElementById("borrowAmountA").value.trim();
    const poolId = document.getElementById("borrowAPoolIdInput").value.trim();
    const statusBox = document.getElementById("statusABorrow");
  
    try {
      console.log("📥 Input Values:", { collateral, amount, poolId });
  
      const idx = parseInt(poolId.replace("pool", ""));
      const poolAddress = pools[idx]?.address;
      console.log("🏦 Resolved Pool Address:", poolAddress);
  
      const functionSig = web3.utils.sha3("borrowTokenA(uint256,uint256,address)").substring(0, 10);
      console.log("🧾 Function Signature:", functionSig);
  
      const encodedParams = web3.eth.abi.encodeParameters(
        ["uint256", "uint256", "address"],
        [collateral, amount, poolAddress]
      ).substring(2);
      console.log("📦 Encoded Parameters:", encodedParams);
  
      const data = functionSig + encodedParams;
      console.log("🛠 Full Call Data:", data);
  
      const tx = await web3.eth.sendTransaction({
        from: userAccount,
        to: lendingCoreAddress,
        data: data,
      });
  
      console.log("✅ Transaction Successful:", tx);
      statusBox.textContent = `✅ Borrowed Token A\nTx Hash: ${tx.transactionHash}`;
    } catch (err) {
      console.error("❌ borrowTokenA error:", err);
      statusBox.textContent = "❌ " + (err.message || err);
    }
  }
  

  async function borrowTokenB() {
    const collateral = document.getElementById("collateralBmount").value.trim();
    const amount = document.getElementById("borrowAmountB").value.trim();
    const poolId = document.getElementById("borrowBPoolIdInput").value.trim();
    const statusBox = document.getElementById("statusBBorrow");
  
    try {
      const idx = parseInt(poolId.replace("pool", ""));
      const poolAddress = pools[idx]?.address;
  
      const functionSig = web3.utils.sha3("borrowTokenB(uint256,uint256,address)").substring(0, 10);
      const encodedParams = web3.eth.abi.encodeParameters(["uint256", "uint256", "address"], [collateral, amount, poolAddress]).substring(2);
      const data = functionSig + encodedParams;
  
      const tx = await web3.eth.sendTransaction({
        from: userAccount,
        to: lendingCoreAddress,
        data: data,
      });
  
      statusBox.textContent = `✅ Borrowed Token B\nTx Hash: ${tx.transactionHash}`;
    } catch (err) {
      statusBox.textContent = "❌ " + (err.message || err);
    }
  }
  async function repayLoanHandler() {
    const poolId = document.getElementById("repayPoolAddressIdInput").value.trim();
    const amount = document.getElementById("repayAmountInput").value.trim();
    const output = document.getElementById("repayStatusMessage");
  
    try {
      console.log("🔍 Input Values:", { poolId, amount });
  
      const idx = parseInt(poolId.replace("pool", ""));
      const poolAddress = pools[idx]?.address;
      console.log("🏦 Resolved Pool Address:", poolAddress);
  
      const selector = web3.utils.sha3("repayLoan(address,uint256)").substring(0, 10);
      console.log("🧾 Function Selector:", selector);
  
      const encoded = web3.eth.abi.encodeParameters(["address", "uint256"], [poolAddress, amount]).substring(2);
      console.log("📦 Encoded Parameters:", encoded);
  
      const txData = selector + encoded;
      console.log("🛠 Full Call Data:", txData);
  
      const tx = await web3.eth.sendTransaction({
        from: userAccount,
        to: lendingCoreAddress,
        data: txData,
      });
  
      console.log("✅ Transaction Success:", tx);
      output.textContent = `✅ Repaid loan to ${poolAddress}\nTx Hash: ${tx.transactionHash}`;
    } catch (err) {
      console.error("❌ repayLoanHandler error:", err);
      output.textContent = "❌ Error: " + (err.message || err);
    }
  }
  
  async function withdrawTokenAHandler() {
    const poolId = document.getElementById("withdrawPoolAddressIdInputA").value.trim();
    const output = document.getElementById("withdrawStatusMessageA");
  
    try {
      const idx = parseInt(poolId.replace("pool", ""));
      const poolAddress = pools[idx]?.address;
  
      const selector = web3.utils.sha3("withdrawTokenA(address)").substring(0, 10);
      const encoded = web3.eth.abi.encodeParameter("address", poolAddress).substring(2);
  
      const tx = await web3.eth.sendTransaction({
        from: userAccount,
        to: lendingCoreAddress,
        data: selector + encoded,
      });
  
      output.textContent = `✅ Withdrawn Token A from ${poolAddress}\nTx Hash: ${tx.transactionHash}`;
    } catch (err) {
      output.textContent = "❌ " + (err.message || err);
    }
  }

  async function withdrawTokenBHandler() {
    const poolId = document.getElementById("withdrawPoolAddressIdInputB").value.trim();
    const output = document.getElementById("withdrawStatusMessageB");
  
    try {
      const idx = parseInt(poolId.replace("pool", ""));
      const poolAddress = pools[idx]?.address;
  
      const selector = web3.utils.sha3("withdrawTokenB(address)").substring(0, 10);
      const encoded = web3.eth.abi.encodeParameter("address", poolAddress).substring(2);
  
      const tx = await web3.eth.sendTransaction({
        from: userAccount,
        to: lendingCoreAddress,
        data: selector + encoded,
      });
  
      output.textContent = `✅ Withdrawn Token B from ${poolAddress}\nTx Hash: ${tx.transactionHash}`;
    } catch (err) {
      output.textContent = "❌ " + (err.message || err);
    }
  }

  async function liquidateUser() {
    const user = document.getElementById("userAddressLiqui").value.trim();
    const poolId = document.getElementById("poolAddressLiquiPoolIdInput").value.trim();
    const output = document.getElementById("logLiquidation");
  
    try {
      const idx = parseInt(poolId.replace("pool", ""));
      const poolAddress = pools[idx]?.address;
  
      const selector = web3.utils.sha3("liquidate(address,address)").substring(0, 10);
      const encoded = web3.eth.abi.encodeParameters(["address", "address"], [user, poolAddress]).substring(2);
  
      const tx = await web3.eth.sendTransaction({
        from: userAccount,
        to: lendingCoreAddress,
        data: selector + encoded,
      });
  
      output.textContent = `✅ Liquidated ${user} in ${poolAddress}\nTx Hash: ${tx.transactionHash}`;
    } catch (err) {
      output.textContent = "❌ " + (err.message || err);
    }
  }async function readLoanForUser() {
    const inputAddress = document.getElementById("loanAddressInput").value.trim();
    const output = document.getElementById("loanOutput");
    const poolId = document.getElementById("poolAddressLoanPoolIdInput").value.trim();
  
    const idx = parseInt(poolId.replace("pool", ""));
    const poolAddress =  pools[idx]?.address; // Assume pools[idx] directly gives the address
  
    try {
      if (!web3.utils.isAddress(inputAddress) || !web3.utils.isAddress(poolAddress)) {
        output.textContent = "❌ Invalid user or pool address.";
        return;
      }
  
      // Get the selector for loans(address,address)
      const selector = web3.utils.sha3("loans(address,address)").substring(0, 10);
  
      // Correctly encode the 2 address parameters
      const encodedParams = web3.eth.abi.encodeParameters(
        ["address", "address"],
        [inputAddress, poolAddress]
      ).substring(2); // remove '0x'
  
      const calldata = selector + encodedParams;
  
      // Call the smart contract view function
      const result = await web3.eth.call({
        to: lendingCoreAddress,
        data: calldata
      });
  
      console.log("📬 Raw result:", result);
  
      // Decode result into Loan struct: (uint256 collateralAmount, uint256 borrowedAmount, uint8 loanType)
      const decoded = web3.eth.abi.decodeParameters(
        ["uint256", "uint256", "uint8"],
        result
      );
  
      const collateralAmount = decoded[0];
      const borrowedAmount = decoded[1];
      const loanType = decoded[2];
  
      output.textContent =
        `📊 Loan for ${inputAddress} in Pool ${poolId}:\n` +
        `🔹 Collateral Amount: ${collateralAmount}\n` +
        `🔹 Borrowed Amount: ${borrowedAmount}\n` +
        `🔹 Loan Type: ${loanType === "0" ? "Token A" : "Token B"}`;
    } catch (err) {
      console.error("❌ Error reading loan:", err);
      output.textContent = "❌ " + (err.message || err);
    }
  }
  
  

  async function readShares() {
    const user = document.getElementById("shareUserAddress").value.trim();
    const poolId = document.getElementById("sharePoolId").value.trim();
    const output = document.getElementById("shareResult");
  
    try {
      const idx = parseInt(poolId.replace("pool", ""));
      const poolAddress = pools[idx]?.address;
  
      const selector = web3.utils.sha3("shares(address,address)").substring(0, 10);
      const encoded = web3.eth.abi.encodeParameters(["address", "address"], [user, poolAddress]).substring(2);
  
      const result = await web3.eth.call({
        to: lendingCoreAddress,
        data: selector + encoded
      });
  
      const decodedShares = web3.eth.abi.decodeParameters(["uint256", "uint256"], result);
      const tokenAShare = decodedShares[0];
      const tokenBShare = decodedShares[1];

      output.textContent =
        `📦 Shares of ${user} in ${poolAddress}:\n` +
        `🔸 Token A: ${tokenAShare}\n` +
        `🔸 Token B: ${tokenBShare}`;
    } catch (err) {
      output.textContent = "❌ Error reading shares: " + (err.message || err);
    }
  }

  async function readHealthFactor() {
    const user = document.getElementById("healthUserAddressInput").value.trim();
    const poolId = document.getElementById("healthPoolAddressIdInput").value.trim();
    const output = document.getElementById("healthFactorStatusMessage");
  
    try {
      const idx = parseInt(poolId.replace("pool", ""));
      const poolAddress = pools[idx]?.address;
  
      if (!web3 || !userAccount || !lendingCoreAddress) {
        output.textContent = "❌ Web3 or contract not properly initialized.";
        return;
      }
  
      // Function selector for: getHealthFactor(address,address)
      const selector = web3.utils.sha3("getHealthFactor(address,address)").substring(0, 10);
  
      // Encode parameters: [user address, pool address]
      const encoded = web3.eth.abi.encodeParameters(["address", "address"], [user, poolAddress]).substring(2);
  
      const data = selector + encoded;
  
      // Make a call to the contract
      const result = await web3.eth.call({
        to: lendingCoreAddress,
        data: data,
      });
  
      // Decode the result (assuming returns uint256)
      const decoded = web3.eth.abi.decodeParameter("uint256", result);
  
      output.textContent = `❤️ Health Factor of ${user} in ${poolId}:\n🔸 ${decoded}`;
    } catch (err) {
      console.error("❌ Health factor read error:", err);
      output.textContent = "❌ Error reading health factor: " + (err.message || err);
    }
  }

  async function readPoolStats() {
    const poolId = document.getElementById("statsPoolId").value.trim();
    const output = document.getElementById("poolStatsOutput");
  
    try {
      const idx = parseInt(poolId.replace("pool", ""));
      const poolAddress = pools[idx]?.address;
  
      if (!poolAddress || !web3 || !lendingCoreAddress) {
        output.textContent = "❌ Invalid pool or web3 not initialized.";
        return;
      }
  
      const encodePool = web3.eth.abi.encodeParameter("address", poolAddress).substring(2);
  
      // Helper function to get uint256 value from contract mapping
      async function readUintMapping(selectorName) {
        const selector = web3.utils.sha3(selectorName).substring(0, 10);
        const calldata = selector + encodePool;
  
        const result = await web3.eth.call({
          to: lendingCoreAddress,
          data: calldata,
        });
  
        return web3.eth.abi.decodeParameter("uint256", result);
      }
  
      const [tokenAStaked, interestA, tokenBStaked, interestB] = await Promise.all([
        readUintMapping("totalTokenAStaked(address)"),
        readUintMapping("totalInterestTokenA(address)"),
        readUintMapping("totalTokenBStaked(address)"),
        readUintMapping("totalInterestTokenB(address)")
      ]);
  
      output.textContent =
        `📈 Lending Stats for ${poolId}:\n` +
        `🔹 Token A Staked: ${tokenAStaked}\n` +
        `🔹 Interest A: ${interestA}\n` +
        `🔹 Token B Staked: ${tokenBStaked}\n` +
        `🔹 Interest B: ${interestB}`;
    } catch (err) {
      console.error("❌ Error reading pool stats:", err);
      output.textContent = "❌ Error reading pool stats: " + (err.message || err);
    }
  }

  async function findBestPoolHandler() {
    const tokenToSwap = document.getElementById("tokenToSwapSelect").value.trim();
    const tokenFromSwap = document.getElementById("tokenFromSwapSelect").value.trim();
    const amount = document.getElementById("amountToSwapInput").value.trim();
    const output = document.getElementById("bestPoolOutput");
  
    if (!tokenToSwap || !tokenFromSwap || !amount) {
      output.textContent = "❌ Fill all fields.";
      return;
    }
  
    try {
      console.log("📥 Inputs:", { tokenToSwap, tokenFromSwap, amount });
  
      const selector = web3.utils.sha3("bestPool(address,address,uint256)").substring(0, 10);
      const encodedParams = web3.eth.abi.encodeParameters(
        ["address", "address", "uint256"],
        [tokenToSwap, tokenFromSwap, amount]
      ).substring(2);
      const callData = selector + encodedParams;
  
      const result = await web3.eth.call({
        to: defiCoreAddress, // ⬅️ Replace with your actual contract address
        data: callData,
      });
  
      const bestPoolAddress = web3.eth.abi.decodeParameter("address", result);
      output.textContent = `✅ Best AMM Pool: ${bestPoolAddress}`;
      console.log("✅ Best AMM Pool:", bestPoolAddress);
    } catch (err) {
      console.error("❌ Error calling bestPool:", err);
      output.textContent = "❌ Error: " + err.message;
    }
  }

  async function findBestArbitrage() {
    const output = document.getElementById("findBestArbitrageOutput");
    output.textContent = "";
  
    const baseToken = document.getElementById("token-find-select").value.trim();
    const amountIn = document.getElementById("amountInFind").value.trim();
  
    if (!baseToken || !amountIn) {
      output.textContent = "❌ Please select a token and enter an amount.";
      return;
    }
  
    if (!web3 || !userAccount) {
      output.textContent = "❌ Connect wallet first.";
      return;
    }
  
    try {
      const selector = web3.utils.sha3("findBestArbitrage(address,uint256)").substring(0, 10);
      const params = web3.eth.abi.encodeParameters(["address", "uint256"], [baseToken, amountIn]).substring(2);
      const calldata = selector + params;
  
      const tx = {
        from: userAccount,
        to: arbitrAddress,
        data: calldata
      };
  
      output.textContent = "🔍 Sending findBestArbitrage...";
      const receipt = await web3.eth.sendTransaction(tx);
      output.textContent = `✅ Best path search complete. Tx Hash: ${receipt.transactionHash}`;
    } catch (err) {
      output.textContent = "❌ Error: " + (err.message || err);
    }
  }
  
  async function executeArbitrage() {
    const output = document.getElementById("arbitrageOutput");
    output.textContent = "";
  
    const baseToken = document.getElementById("token-exec-select").value.trim();
    const amountIn = document.getElementById("amountInExec").value.trim();
  
    if (!baseToken || !amountIn) {
      output.textContent = "❌ Please select a token and enter an amount.";
      return;
    }
  
    if (!web3 || !userAccount) {
      output.textContent = "❌ Connect wallet first.";
      return;
    }
  
    try {
      const selector = web3.utils.sha3("executeArbitrage(address,uint256)").substring(0, 10);
      const params = web3.eth.abi.encodeParameters(["address", "uint256"], [baseToken, amountIn]).substring(2);
      const calldata = selector + params;
  
      const tx = {
        from: userAccount,
        to: arbitrAddress,
        data: calldata
      };
  
      output.textContent = "🚀 Executing arbitrage...";
      const receipt = await web3.eth.sendTransaction(tx);
      output.textContent = `✅ Arbitrage executed. Tx Hash: ${receipt.transactionHash}`;
    } catch (err) {
      output.textContent = "❌ Error: " + (err.message || err);
    }
  }

  async function readBestPath() {
    const output = document.getElementById("bestPathOutput");
    output.textContent = "";
  
    if (!web3 || !userAccount) {
      output.textContent = "❌ Connect wallet first.";
      return;
    }
  
    try {
      const selector = web3.utils.sha3("bestPath()").substring(0, 10);
  
      const result = await web3.eth.call({
        to: arbitrAddress,
        data: selector
      });
  
      const decoded = web3.eth.abi.decodeParameters(
        ["address", "address", "address", "uint256"],
        result
      );
  
      const pool1 = decoded[0];
      const pool2 = decoded[1];
      const midToken = decoded[2];
      const expectedOutput = decoded[3];
  
      const midTokenName = tokenMap[midToken.toLowerCase()] || "(Unknown token)";
  
      output.textContent =
        `📦 Best Arbitrage Path:\n` +
        `🔹 Pool 1: ${pool1}\n` +
        `🔹 Pool 2: ${pool2}\n` +
        `🔹 Mid Token: ${midToken} (${midTokenName})\n` +
        `🔹 Expected Output: ${expectedOutput}`;
    } catch (err) {
      output.textContent = "❌ Error reading bestPath: " + (err.message || err);
    }
  }
  