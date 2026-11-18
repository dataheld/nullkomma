// Prints the fonts with which Chromium renders Bootstrap 5's and 3's font stacks
// and the generic families, one line per stack.
// Usage: node _browser-fonts.js <launch options as JSON>
//        node _browser-fonts.js --mcp <Playwright MCP server command...>
const { spawn } = require("child_process");
const readline = require("readline");
const { chromium } = require("playwright-core");

// Self-contained: the MCP server runs its source.
const rendered = async (page) => {
  const stacks = [
    `system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", "Noto Sans", "Liberation Sans", Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"`,
    `SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace`,
    `"Helvetica Neue", Helvetica, Arial, sans-serif`,
    `Georgia, "Times New Roman", Times, serif`,
    `Menlo, Monaco, Consolas, "Courier New", monospace`,
    "sans-serif",
    "serif",
    "monospace",
    "Cantarell, serif",
  ];
  await page.setContent(
    stacks.map((stack) => `<p style='font-family: ${stack}'>Text</p>`).join(""),
  );
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("DOM.enable");
  await cdp.send("CSS.enable");
  const { root } = await cdp.send("DOM.getDocument");
  const { nodeIds } = await cdp.send("DOM.querySelectorAll", {
    nodeId: root.nodeId,
    selector: "p",
  });
  const fonts = [];
  for (const nodeId of nodeIds) {
    const used = await cdp.send("CSS.getPlatformFontsForNode", { nodeId });
    fonts.push(used.fonts.map((font) => font.familyName).join(", "));
  }
  return fonts;
};

const launched = async (options) => {
  const browser = await chromium.launch(options);
  try {
    return await rendered(await browser.newPage());
  } finally {
    await browser.close();
  }
};

const served = async ([command, ...args]) => {
  const server = spawn(command, args, { stdio: ["pipe", "pipe", "inherit"] });
  const send = (id, method, params) =>
    server.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
  send(0, "initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: { name: "check", version: "0" },
  });
  send(1, "tools/call", {
    name: "browser_run_code",
    arguments: { code: rendered.toString() },
  });
  try {
    for await (const line of readline.createInterface({ input: server.stdout })) {
      const { id, result } = JSON.parse(line);
      if (id !== 1) continue;
      const text = result.content[0].text;
      if (result.isError) throw new Error(text);
      return JSON.parse(text.match(/^### Result\n(.*)$/m)[1]);
    }
  } finally {
    server.kill();
  }
};

(async () => {
  const [mode, ...rest] = process.argv.slice(2);
  const fonts = mode === "--mcp" ? await served(rest) : await launched(JSON.parse(mode));
  console.log(fonts.join("\n"));
})();
