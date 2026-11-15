// One framed buffer request; no file I/O or project configuration loading.
import { createInterface } from 'node:readline';
import * as prettier from './tooling/node_modules/prettier/index.mjs';
const lines = createInterface({ input: process.stdin, crlfDelay: Infinity });
lines.once('line', async (line) => {
  lines.close();
  process.stdin.pause();
  try {
    const { source, parser, tabWidth, useTabs } = JSON.parse(line);
    const plugins = parser === 'php'
      ? [await import('./tooling/node_modules/@prettier/plugin-php/src/index.mjs')]
      : [];
    const result = await prettier.format(source, { parser, tabWidth, useTabs, plugins });
    process.stdout.write(result, () => process.exit(0));
  } catch (error) {
    process.stderr.write(String(error.message ?? error), () => process.exit(1));
  }
});
