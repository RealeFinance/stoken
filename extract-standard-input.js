const { readdirSync, readFileSync, writeFileSync } = require("fs");
const { join, resolve, relative } = require("path");
const { config } = require("hardhat");

// 项目根目录
const ROOT_DIR = process.cwd();
// 合约目录
const CONTRACTS_DIR = resolve(ROOT_DIR, "contracts");
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
  // 支持三种导入模式:
  // 1. import "path";
  // 2. import 'path';
  // 3. import {Symbol} from "path";
  // 4. import {Symbol} from 'path';
  const importRegex =
    /import\s+(?:\{[^}]*\}\s+from\s+)?(?:"([^"]+)"|'([^']+)')\s*;/g;
  const imports = [];
  let match;

  while ((match = importRegex.exec(content)) !== null) {
    // 匹配双引号或单引号中的路径
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
  console.log(`🔍 处理文件: ${filePath}`);
  // 跳过已处理的文件
  if (processedFiles.has(filePath)) {
    return;
  }

  try {
    // 读取文件内容
    const content = readFileSync(filePath, "utf8");
    // 计算相对路径作为 sources 的键（保持项目结构）
    const relativePath = relative(ROOT_DIR, filePath);

    // 添加到源文件集合
    sources[relativePath] = { content };
    processedFiles.add(filePath);

    // 解析并处理导入的文件
    const imports = parseImports(content);
    for (const importPath of imports) {
      // 处理重映射
      const resolvedImportPath = resolveRemapping(importPath);
      // 尝试可能的文件路径
      const possiblePaths = [
        // 相对于当前文件的路径
        resolve(join(filePath, ".."), resolvedImportPath),
        // 相对于项目根目录的路径
        resolve(ROOT_DIR, resolvedImportPath),
        // 相对于 node_modules 的路径
        resolve(NODE_MODULES_DIR, resolvedImportPath),
        // 直接作为绝对路径
        resolve(resolvedImportPath),
      ];

      // 查找有效的文件路径
      for (const possiblePath of possiblePaths) {
        // 检查文件是否存在（处理可能的 .sol 扩展名省略）
        const filePathWithExt = possiblePath.endsWith(".sol")
          ? possiblePath
          : `${possiblePath}.sol`;

        try {
          // 检查文件是否可访问
          readFileSync(filePathWithExt);
          // 递归处理导入的文件
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

/**
 * 遍历合约目录并处理所有 .sol 文件
 */
function processContractDirectory() {
  function traverseDir(dir) {
    const files = readdirSync(dir, { withFileTypes: true });
    for (const file of files) {
      const fullPath = join(dir, file.name);
      if (file.isDirectory()) {
        traverseDir(fullPath);
      } else if (file.isFile() && fullPath.endsWith(".sol")) {
        processFile(fullPath);
      }
    }
  }

  traverseDir(CONTRACTS_DIR);
}

/**
 * 生成 Standard Json-Input 并写入文件
 */
async function generateStandardInput() {
  // 处理所有合约文件及其依赖（包括 @openzeppelin）
  processContractDirectory();

  // 获取编译器配置
  const compiler = config.solidity.compilers[0];

  // 修改 sources 中的所有路径，将 / 替换为 \
  const newSources = {};
  for (const key in sources) {
    const newKey = key.replaceAll("\\", "/").replaceAll("node_modules/", "");
    newSources[newKey] = sources[key];
  }
  // 用新的 sources 替换原来的
  Object.keys(sources).forEach((k) => delete sources[k]);
  Object.assign(sources, newSources);

  // 构造 Standard Json-Input
  const standardInput = {
    language: "Solidity",
    sources: sources,
    settings: {
      optimizer: compiler.optimizer || { enabled: true, runs: 100 },
      viaIR: true,
      evmVersion: compiler.evmVersion || "london",
      outputSelection: {
        "*": {
          "*": ["abi", "evm.bytecode", "evm.deployedBytecode", "metadata"],
          "": ["ast"],
        },
      },
      remappings: config.solidity.remappings || [],
    },
  };

  // 写入文件
  writeFileSync("standard-input.json", JSON.stringify(standardInput, null, 2));
  console.log(
    `✅ 已生成包含所有依赖（包括 @openzeppelin）的 Standard Json-Input`
  );
  console.log(`📦 共处理 ${Object.keys(sources).length} 个文件`);
  console.log(`📄 输出文件: standard-input.json`);
}

// 执行生成
generateStandardInput()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ 生成失败:", err);
    process.exit(1);
  });
