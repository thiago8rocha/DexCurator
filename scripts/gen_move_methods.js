// Gera assets/data/move_methods.json
// Para cada golpe em move_map.json, agrupa os IDs de Pokémon por método de aprendizado.
// Execute com: node scripts/gen_move_methods.js
//
// Saída: {"tackle": {"level-up": [1,4,...], "machine": [15,...], "egg": [...], "tutor": [...]}}

const https = require('https');
const fs    = require('fs');
const path  = require('path');

const MOVE_MAP  = path.join(__dirname, '../assets/data/move_map.json');
const OUT_FILE  = path.join(__dirname, '../assets/data/move_methods.json');
const BASE      = 'https://pokeapi.co/api/v2';
const TOTAL     = 1025;
const BATCH     = 5;
const DELAY_MS  = 150;

// Prioridade de método (menor = maior prioridade p/ deduplicação)
const METHOD_PRIORITY = { 'level-up': 0, 'machine': 1, 'tutor': 2, 'egg': 3 };

function get(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, { headers: { 'User-Agent': 'DexCurator/1.0' } }, res => {
      if (res.statusCode === 429) {
        return reject(new Error(`rate-limited on ${url}`));
      }
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch(e) { reject(new Error(`JSON parse error for ${url}: ${e.message}`)); }
      });
    });
    req.setTimeout(12000, () => { req.destroy(); reject(new Error(`timeout: ${url}`)); });
    req.on('error', reject);
  });
}

async function getWithRetry(url, retries = 3) {
  for (let i = 0; i < retries; i++) {
    try {
      return await get(url);
    } catch(e) {
      if (i === retries - 1) throw e;
      const wait = 1000 * (i + 1);
      process.stderr.write(`  Retry ${i+1} for ${url} (${e.message}), waiting ${wait}ms\n`);
      await delay(wait);
    }
  }
}

function delay(ms) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  const moveMap    = JSON.parse(fs.readFileSync(MOVE_MAP, 'utf8'));
  const validMoves = new Set(Object.keys(moveMap));

  // methods[moveName][pokemonId] = priority (lowest wins)
  const methodMap = {}; // moveName -> {pokemonId -> bestMethod}

  let done = 0;
  const errors = [];

  for (let start = 1; start <= TOTAL; start += BATCH) {
    const ids = [];
    for (let id = start; id < start + BATCH && id <= TOTAL; id++) ids.push(id);

    await Promise.all(ids.map(async id => {
      try {
        const poke = await getWithRetry(`${BASE}/pokemon/${id}`);
        for (const m of poke.moves || []) {
          const moveName = m.move.name;
          if (!validMoves.has(moveName)) continue;

          // Collect all methods across all version groups
          const methodPriority = {};
          for (const vg of m.version_group_details || []) {
            const method = vg.move_learn_method.name;
            const p = METHOD_PRIORITY[method] ?? 99;
            if (!(method in methodPriority) || p < methodPriority[method]) {
              methodPriority[method] = p;
            }
          }

          // Pick the best (lowest priority) method
          let bestMethod = null, bestP = 999;
          for (const [method, p] of Object.entries(methodPriority)) {
            if (p < bestP) { bestP = p; bestMethod = method; }
          }
          if (!bestMethod) continue;

          if (!methodMap[moveName]) methodMap[moveName] = {};
          // Only upgrade if new method has higher priority
          const existing = methodMap[moveName][id];
          if (existing === undefined || (METHOD_PRIORITY[bestMethod] ?? 99) < (METHOD_PRIORITY[existing] ?? 99)) {
            methodMap[moveName][id] = bestMethod;
          }
        }
        done++;
        if (done % 100 === 0 || done === TOTAL) {
          process.stderr.write(`Progress: ${done}/${TOTAL}\n`);
        }
      } catch(e) {
        errors.push(`id=${id}: ${e.message}`);
        process.stderr.write(`  ERROR id=${id}: ${e.message}\n`);
      }
    }));

    await delay(DELAY_MS);
  }

  // Convert to grouped format: moveName -> {method -> [ids]}
  const result = {};
  for (const [moveName, idMap] of Object.entries(methodMap)) {
    const groups = {};
    for (const [idStr, method] of Object.entries(idMap)) {
      if (!groups[method]) groups[method] = [];
      groups[method].push(Number(idStr));
    }
    // Sort IDs within each group
    for (const g of Object.values(groups)) g.sort((a, b) => a - b);
    result[moveName] = groups;
  }

  fs.writeFileSync(OUT_FILE, JSON.stringify(result), 'utf8');

  process.stderr.write(`\nDone! ${Object.keys(result).length} moves with method data\n`);
  if (errors.length) {
    process.stderr.write(`Errors (${errors.length}):\n${errors.slice(0,10).join('\n')}\n`);
  }
}

main().catch(e => { process.stderr.write('Fatal: ' + e.message + '\n'); process.exit(1); });
