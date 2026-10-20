// 构建脚本：产出「单文件 JS + 关卡数据」这两个小游戏端唯一需要的东西。
//
// 为什么不用 vite / webpack：微信小游戏最终要的是 `game.js` 单个 IIFE
// （基础库按 CommonJS 加载体，多文件反而要走分包配置）。esbuild 一条
// build 就能出，零运行时依赖，包体最小。
import { build } from 'esbuild';
import fs from 'node:fs';
import path from 'node:path';

const watch = process.argv.includes('--watch');
const ROOT = path.dirname(new URL(import.meta.url).pathname);
const OUT = path.join(ROOT, 'dist');

function copyStatic() {
  fs.mkdirSync(OUT, { recursive: true });
  // 关卡数据是跨端唯一真源，直接复制，不在 TS 侧重写生成器。
  fs.cpSync(path.join(ROOT, '../shared/levels'), path.join(OUT, 'levels'), {
    recursive: true,
  });
  fs.copyFileSync(path.join(ROOT, 'index.html'), path.join(OUT, 'index.html'));
}

copyStatic();

const options = {
  entryPoints: [path.join(ROOT, 'src/main.ts')],
  bundle: true,
  format: 'iife',
  target: 'es2019',
  outfile: path.join(OUT, 'bundle.js'),
  minify: !watch,
  sourcemap: watch ? 'inline' : false,
  legalComments: 'none',
  logLevel: 'info',
  // 小游戏没有 DOM，平台差异全部收敛在 src/platform/ 下；
  // 打包时不能把 platform/web.ts 里的 DOM 类型带进 wx 分支——运行时按
  // env 判断，两条实现都在包里（体积代价 < 2KB，换来单一产物）。
  define: { 'process.env.NODE_ENV': watch ? '"development"' : '"production"' },
};

if (watch) {
  const { context } = await import('esbuild');
  const ctx = await context(options);
  await ctx.watch();
  fs.watch(path.join(ROOT, 'index.html'), copyStatic);
  console.log('watch 模式：改 src/**/*.ts 自动重建 → dist/bundle.js');
} else {
  await build(options);
  const size = fs.statSync(path.join(OUT, 'bundle.js')).size;
  const levels = fs
    .readdirSync(path.join(OUT, 'levels'))
    .reduce((n, f) => n + fs.statSync(path.join(OUT, 'levels', f)).size, 0);
  console.log(
    `产物：dist/bundle.js ${(size / 1024).toFixed(1)}KB + levels ${(levels / 1024).toFixed(0)}KB`,
  );
}
