// postinstall.js — patches @nomicfoundation/hardhat-ethers to handle `to: ""` from RPC
const fs = require("fs");
const path = require("path");

try {
  // Find the ethers-utils.js file in pnpm's virtual store
  const pnpmDir = path.join(__dirname, "node_modules", ".pnpm");
  const entries = fs.readdirSync(pnpmDir);
  const targetDir = entries.find(
    (e) => e.startsWith("@nomicfoundation+hardhat-ethers@") && 
           fs.statSync(path.join(pnpmDir, e)).isDirectory()
  );
  
  if (!targetDir) {
    // Fallback: check node_modules directly (npm/yarn)
    const directPath = path.join(
      __dirname,
      "node_modules",
      "@nomicfoundation",
      "hardhat-ethers",
      "internal",
      "ethers-utils.js"
    );
    if (fs.existsSync(directPath)) {
      patchFile(directPath);
    } else {
      console.error("✗ Could not find hardhat-ethers package");
      process.exit(1);
    }
    return;
  }

  const baseDir = path.join(pnpmDir, targetDir, "node_modules", "@nomicfoundation", "hardhat-ethers");
  const jsFile = path.join(baseDir, "internal", "ethers-utils.js");
  patchFile(jsFile);
} catch (err) {
  console.error("✗ Failed to patch hardhat-ethers:", err.message);
  process.exit(1);
}

function patchFile(jsFile) {
  if (!fs.existsSync(jsFile)) {
    console.error("✗ File not found:", jsFile);
    process.exit(1);
  }

  let content = fs.readFileSync(jsFile, "utf8");

  // Only patch if not already patched
  if (content.includes("// Some RPC nodes return empty string instead of null")) {
    console.log("✓ hardhat-ethers already patched, skipping");
    return;
  }

  const search = `    if (value.to && (0, ethers_1.getBigInt)(value.to) === 0n) {
        value.to = "0x0000000000000000000000000000000000000000";
    }
    const result = object({`;

  const replace = `    if (value.to && (0, ethers_1.getBigInt)(value.to) === 0n) {
        value.to = "0x0000000000000000000000000000000000000000";
    }
    // Some RPC nodes return empty string instead of null for
    // contract creation (CREATE) transactions
    if (value.to === "") {
        value.to = null;
    }
    const result = object({`;

  if (content.includes(search)) {
    content = content.replace(search, replace);
    fs.writeFileSync(jsFile, content, "utf8");
    console.log("✓ hardhat-ethers patched successfully:", jsFile);
  } else {
    console.error("✗ Could not find target code in:", jsFile);
    process.exit(1);
  }
}
