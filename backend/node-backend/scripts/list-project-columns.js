require('dotenv').config({ path: require('path').resolve(__dirname, '..', '..', '.env') });
const { sequelize } = require('../src/models');
const table = process.argv[2] || 'projects';
(async () => {
  const [rows] = await sequelize.query(
    `SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='public' AND table_name=:table ORDER BY ordinal_position`,
    { replacements: { table } },
  );
  console.log(rows);
  await sequelize.close();
})();
