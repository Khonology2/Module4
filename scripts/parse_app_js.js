const fs = require('fs');

const paths = [
  'backend/node-backend/src/app.js',
  'Flow-Space/backend/node-backend/src/app.js',
];

for (const p of paths) {
  const code = fs.readFileSync(p, 'utf8');
  // eslint-disable-next-line no-new-func
  new Function(code);
}

process.stdout.write('js-parse-ok\n');

