const { readFileSync, writeFileSync } = require("fs");
const { join, resolve, relative } = require("path");
const { config } = require("hardhat");

// 项目根目录
const ROOT_DIR = process.cwd();
// node_modules 目录
const NODE_MODULES_DIR = resolve(ROOT_DIR, "node_modules");
// 已处理的文件缓存（避免重复处理）
const processedFiles = new Set();
// 最终收集的所有合约源文件
const sources = {};

/**
 * 解析 Solidity 文件中的导入语句
 * @param {string} content - Solidity 文件内容
 * @returns {string[]} 导入的文件路径列表
 */
function parseImports(content) {
  const importRegex =
    /import\s+(?:\{[^}]*\}\s+from\s+)?(?:"([^"]+)"|'([^']+)')\s*;/g;
  const imports = [];
  let match;

  while ((match = importRegex.exec(content)) !== null) {
    const importPath = match[1] || match[2];
    imports.push(importPath);
  }

  return imports;
}

/**
 * 解析重映射规则（如 @openzeppelin/=node_modules/@openzeppelin/）
 * @param {string} importPath - 导入路径
 * @returns {string} 解析后的实际路径
 */
function resolveRemapping(importPath) {
  const remappings = config.solidity.remappings || [];

  for (const remapping of remappings) {
    const [prefix, target] = remapping.split("=");
    if (importPath.startsWith(prefix)) {
      return importPath.replace(prefix, target);
    }
  }

  return importPath;
}

/**
 * 递归处理所有合约文件及其依赖
 * @param {string} filePath - 文件绝对路径
 */
function processFile(filePath) {
  if (processedFiles.has(filePath)) {
    return;
  }

  try {
    const content = readFileSync(filePath, "utf8");
    const relativePath = relative(ROOT_DIR, filePath);

    sources[relativePath] = { content };
    processedFiles.add(filePath);

    const imports = parseImports(content);
    for (const importPath of imports) {
      const resolvedImportPath = resolveRemapping(importPath);
      const possiblePaths = [
        // 相对于当前文件
        resolve(join(filePath, ".."), resolvedImportPath),
        // 相对于项目根目录
        resolve(ROOT_DIR, resolvedImportPath),
        // 相对于 node_modules
        resolve(NODE_MODULES_DIR, resolvedImportPath),
        // 绝对路径
        resolve(resolvedImportPath),
      ];

      for (const possiblePath of possiblePaths) {
        const filePathWithExt = possiblePath.endsWith(".sol")
          ? possiblePath
          : `${possiblePath}.sol`;

        try {
          readFileSync(filePathWithExt);
          processFile(filePathWithExt);
          break;
        } catch (e) {
          continue;
        }
      }
    }
  } catch (err) {
    console.warn(`⚠️ 无法处理文件 ${filePath}: ${err.message}`);
  }
}

async function generateProxyStandardInput() {
  // 入口：OpenZeppelin 的 ERC1967Proxy 合约
  const entryProxyPath = resolve(
    NODE_MODULES_DIR,
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol"
  );

  console.log("🔍 处理代理合约:", entryProxyPath);
  processFile(entryProxyPath);

  // 获取编译器配置
  const compiler = (config.solidity.compilers || [config.solidity])[0];

  // 规范化 sources 路径（与实现合约 standard-input.json 保持一致）
  const newSources = {};
  for (const key in sources) {
    const newKey = key.replace(/\\/g, "/").replace("node_modules/", "");
    newSources[newKey] = sources[key];
  }

  // 构造 Standard Json-Input
  const standardInput = {
    language: "Solidity",
    sources: newSources,
    settings: {
      optimizer: compiler.settings?.optimizer || { enabled: true, runs: 100 },
      viaIR: compiler.settings?.viaIR ?? true,
      evmVersion: compiler.settings?.evmVersion || "london",
      outputSelection: {
        "*": {
          "*": ["abi", "evm.bytecode", "evm.deployedBytecode", "metadata"],
          "": ["ast"],
        },
      },
      remappings: config.solidity.remappings || [],
    },
  };

  writeFileSync(
    "standard-input-proxy.json",
    JSON.stringify(standardInput, null, 2)
  );

  console.log(
    `✅ 已生成代理合约 ERC1967Proxy 的 Standard Json-Input (standard-input-proxy.json)`
  );
  console.log(`📦 共处理 ${Object.keys(newSources).length} 个文件`);
}

generateProxyStandardInput()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ 生成失败:", err);
    process.exit(1);
  });
