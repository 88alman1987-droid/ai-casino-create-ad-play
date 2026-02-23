

```bash
#!/usr/bin/env bash
set -e

# setup_repo.sh
# Creates a full repo skeleton for the AI Game Platform Demo (server + client).
# Optionally installs npm packages and optionally creates & pushes a GitHub repo via 'gh'.
#
# Usage:
#   ./setup_repo.sh [--install] [--repo owner/repo] [--push] [--branch BRANCH]
# Example:
#   ./setup_repo.sh --install --repo yourname/ai-game-platform-demo --push
#

INSTALL_NODE=false
GITHUB_REPO=""
PUSH=false
BRANCH="main"

print_help() {
  cat <<EOF
Usage: $0 [--install] [--repo owner/repo] [--push] [--branch BRANCH] [--help]

--install       Run npm install in server and client directories after creating files.
--repo OWNER/REPO  Use gh CLI to create remote repository with that name (optional).
--push          Push the initial commit to the remote (uses gh to create repo if needed).
--branch BRANCH Set initial branch name (default: main).
--help          Show this help.

Note: gh CLI is required for --repo and --push. Do not store secrets in the repo.
EOF
}

# parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --install) INSTALL_NODE=true; shift ;;
    --repo) GITHUB_REPO="$2"; shift 2 ;;
    --push) PUSH=true; shift ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --help) print_help; exit 0 ;;
    *) echo "Unknown arg: $1"; print_help; exit 1 ;;
  esac
done

if $PUSH && [ -z "$GITHUB_REPO" ]; then
  echo "Error: --push requires --repo OWNER/REPO"
  exit 1
fi

if $PUSH && ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI not found. Install and authenticate before using --push."
  exit 1
fi

echo "Creating repository files..."

# create directories
mkdir -p ai-game-platform
cd ai-game-platform

mkdir -p server/src/utils server/src/scripts server
mkdir -p client/src
mkdir -p .github/workflows
mkdir -p scripts

# ===== top-level README.md =====
cat > README.md <<'EOF'
# AI Game Platform Demo — Enhanced (GitHub-ready)

This repository is a demonstration prototype of an AI-driven game platform with:
- AI-generated original game specs (OpenAI), with safe prompt templates.
- Provably-fair: encrypted server seeds, HMAC-derived RNG, deterministic dice/slots/deck shuffle.
- JWT auth, admin features.
- Stripe Checkout sketch for buying SweepCoins (no cashouts).
- Socket.IO lobby & multiplayer stubs.
- Frontend React app with Lobby, GameEditor, MultiplayerRoom.
- GitHub Actions CI to prevent committing secrets and to run basic builds.
- A script to create a zip for distribution (excludes secrets).

Security & Legal Notice:
- This is a demo. Do not operate real-money gambling without legal advice and licenses.
- Do not commit .env or API keys.
- Use MASTER_KEY to encrypt server seeds and store MASTER_KEY in a proper secret manager.

Quick start (local)
1. Clone repo (or use the files below).
2. Configure environment:
   - Copy server/.env.example => server/.env and fill keys.
   - Generate MASTER_KEY (32 bytes hex): e.g. `openssl rand -hex 32` and set MASTER_KEY in .env.
3. Start MongoDB (local or Atlas).
4. Start server:
   cd server
   npm install
   npm run dev
5. Start client:
   cd client
   npm install
   npm start

Push to GitHub
1. git init
2. git add .
3. git commit -m "Initial commit — AI Game Platform Demo (enhanced)"
4. git remote add origin https://github.com/yourname/repo.git
5. git branch -M main
6. git push -u origin main

Create zip for distribution
- scripts/create-zip.sh will create a secure zip that excludes .env and node_modules:
  ./scripts/create-zip.sh ai-game-platform.zip

If you want I can generate a ready-to-download zip content (I can provide a tarball text you can decode) or prepare a minimal repo tarball here.
EOF

# ===== .gitignore =====
cat > .gitignore <<'EOF'
node_modules
client/node_modules
.env
server/.env
.DS_Store
coverage
*.log
EOF

# ===== scripts/create-zip.sh =====
cat > scripts/create-zip.sh <<'EOF'
#!/usr/bin/env bash
# Create an archive without secrets and node_modules
ZIPNAME="$1"
if [ -z "$ZIPNAME" ]; then
  echo "Usage: $0 <output.zip>"
  exit 1
fi
TMPDIR=$(mktemp -d)
echo "Creating temp copy at $TMPDIR"
rsync -av --exclude='.env' --exclude='node_modules' --exclude='server/node_modules' --exclude='client/node_modules' . "$TMPDIR/repo"
cd "$TMPDIR"
zip -r "$ZIPNAME" repo
mv "$ZIPNAME" "$(pwd)/../$ZIPNAME"
echo "Created $ZIPNAME in original directory"
rm -rf "$TMPDIR"
EOF
chmod +x scripts/create-zip.sh

# ===== .github/workflows/ci.yml =====
cat > .github/workflows/ci.yml <<'EOF'
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-and-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 18
      - name: Check no .env committed (server)
        run: |
          cd server
          npm ci
          npm run check-secrets
      - name: Build client
        run: |
          cd client
          npm ci
          npm run build
EOF

# ===== server/package.json =====
cat > server/package.json <<'EOF'
{
  "name": "ai-game-platform-server",
  "version": "1.0.0",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "check-secrets": "node src/scripts/check_no_env.js"
  },
  "dependencies": {
    "bcrypt": "^5.1.0",
    "body-parser": "^1.20.2",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "jsonwebtoken": "^9.0.0",
    "mongoose": "^7.5.0",
    "openai": "^4.9.0",
    "stripe": "^12.12.0",
    "socket.io": "^4.8.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

# ===== server/.env.example =====
cat > server/.env.example <<'EOF'
PORT=4000
MONGO_URI=mongodb://localhost:27017/ai-games
JWT_SECRET=change_this_to_a_long_random_string
OPENAI_API_KEY=sk-...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
CLIENT_BASE_URL=http://localhost:3000
MASTER_KEY=replace_this_with_64hexchars_or_base64
EOF

# ===== server/src/scripts/check_no_env.js =====
cat > server/src/scripts/check_no_env.js <<'EOF'
const fs = require('fs');
const path = require('path');

const p = path.resolve(process.cwd(), '.env');
if (fs.existsSync(p)) {
  console.error('.env file exists in repo root — remove it before committing.');
  process.exit(1);
} else {
  console.log('No .env in repo root — OK.');
  process.exit(0);
}
EOF

# ===== server/src/utils/cryptoStore.js =====
cat > server/src/utils/cryptoStore.js <<'EOF'
const crypto = require('crypto');

const MASTER_KEY = process.env.MASTER_KEY || null;
if (!MASTER_KEY) {
  console.warn('MASTER_KEY not set — seed encryption disabled (not secure). Set MASTER_KEY for production.');
}

function masterKeyBuf() {
  if (!MASTER_KEY) return null;
  if (/^[0-9a-fA-F]+$/.test(MASTER_KEY) && MASTER_KEY.length === 64) {
    return Buffer.from(MASTER_KEY, 'hex');
  }
  return Buffer.from(MASTER_KEY, 'base64');
}

function encryptSeed(plainHex) {
  const key = masterKeyBuf();
  if (!key) {
    return { encrypted: plainHex, iv: null, tag: null, aad: null, mode: 'plain' };
  }
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv, { authTagLength: 16 });
  const ciphertext = Buffer.concat([cipher.update(Buffer.from(plainHex, 'hex')), cipher.final()]);
  const tag = cipher.getAuthTag();
  return { encrypted: ciphertext.toString('hex'), iv: iv.toString('hex'), tag: tag.toString('hex'), mode: 'gcm' };
}

function decryptSeed(encryptedObj) {
  const key = masterKeyBuf();
  if (!key) {
    if (encryptedObj.mode === 'plain') return encryptedObj.encrypted;
    throw new Error('MASTER_KEY missing — cannot decrypt seed');
  }
  if (encryptedObj.mode === 'plain') return encryptedObj.encrypted;
  const iv = Buffer.from(encryptedObj.iv, 'hex');
  const tag = Buffer.from(encryptedObj.tag, 'hex');
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv, { authTagLength: 16 });
  decipher.setAuthTag(tag);
  const pt = Buffer.concat([decipher.update(Buffer.from(encryptedObj.encrypted, 'hex')), decipher.final()]);
  return pt.toString('hex');
}

module.exports = { encryptSeed, decryptSeed };
EOF

# ===== server/src/utils/provablyFair.js =====
cat > server/src/utils/provablyFair.js <<'EOF'
const crypto = require('crypto');

function hmacSha256Hex(keyHex, msg) {
  const key = Buffer.from(keyHex, 'hex');
  return crypto.createHmac('sha256', key).update(msg).digest('hex');
}

function hexToFloat01(hexStr) {
  const slice = hexStr.slice(0, 8);
  const intVal = parseInt(slice, 16);
  const max32 = Math.pow(2, 32);
  return intVal / max32;
}

function percentileFromDigest(digestHex) {
  const f = hexToFloat01(digestHex);
  return Math.floor(f * 100);
}

function diceFromDigest(digestHex, sides = 6) {
  const f = hexToFloat01(digestHex);
  return Math.floor(f * sides) + 1;
}

function slotsFromDigest(digestHex, reels) {
  const results = [];
  let seed = digestHex;
  for (let i = 0; i < reels.length; i++) {
    const h = crypto.createHash('sha256').update(seed + ':' + i).digest('hex');
    const idx = parseInt(h.slice(0, 8), 16) % reels[i].length;
    results.push({ symbol: reels[i][idx], index: idx });
    seed = h;
  }
  return results;
}

function shuffleDeck(digestHex, deck) {
  const arr = deck.slice();
  let counter = 0;
  function randInt(max) {
    const h = crypto.createHash('sha256').update(digestHex + ':' + counter).digest('hex');
    counter++;
    return parseInt(h.slice(0, 8), 16) % max;
  }
  for (let i = arr.length - 1; i > 0; i--) {
    const j = randInt(i + 1);
    const tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

module.exports = {
  hmacSha256Hex,
  hexToFloat01,
  percentileFromDigest,
  diceFromDigest,
  slotsFromDigest,
  shuffleDeck
};
EOF

# ===== server/src/utils/aiPromptTemplates.js =====
cat > server/src/utils/aiPromptTemplates.js <<'EOF'
function systemPrompt() {
  return `You are a creative game-design assistant. Invent original, non-infringing casual game mechanics. Do NOT copy trademarked or proprietary games. Output ONLY valid JSON (no extra commentary).`;
}

function userPrompt(userIdea) {
  return `Design an original game from this idea: "${userIdea}". Output EXACTLY valid JSON with keys:
"title" (string),
"description" (1-3 sentences),
"playerCount" ({"min":n,"max":m}),
"mechanics" (array of strings),
"setup" (array of steps),
"playFlow" (array of steps per round),
"resolutionAlgorithm" (short text describing how to map a random numeric value to a winner/result),
"sampleParameters" (object with numeric parameters).
Do not reference or resemble any named commercial games.`;
}

module.exports = { systemPrompt, userPrompt };
EOF

# ===== server/src/models.js =====
cat > server/src/models.js <<'EOF'
const mongoose = require('mongoose');
const { Schema } = mongoose;

const UserSchema = new Schema({
  username: { type: String, unique: true },
  passwordHash: String,
  sweepCoins: { type: Number, default: 1000 },
  referralCode: String,
  referredBy: String,
  lastDailyClaim: Date,
  isAdmin: { type: Boolean, default: false }
});

const GameSchema = new Schema({
  title: String,
  description: String,
  spec: Schema.Types.Mixed,
  creatorId: String,
  epoch: { type: Number, default: 1 },
  serverSeedEncrypted: Schema.Types.Mixed,
  serverSeedHash: String,
  createdAt: { type: Date, default: Date.now }
});

const RoundSchema = new Schema({
  gameId: String,
  userId: String,
  clientSeed: String,
  epoch: Number,
  nonce: Number,
  result: Schema.Types.Mixed,
  createdAt: { type: Date, default: Date.now }
});

module.exports = {
  User: mongoose.model('User', UserSchema),
  Game: mongoose.model('Game', GameSchema),
  Round: mongoose.model('Round', RoundSchema)
};
EOF

# ===== server/src/auth.js =====
cat > server/src/auth.js <<'EOF'
const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { User } = require('./models');
const router = express.Router();

const JWT_SECRET = process.env.JWT_SECRET || 'dev_secret';

router.post('/register', async (req, res) => {
  const { username, password, referral } = req.body;
  if (!username || !password) return res.status(400).json({ error: 'username and password required' });

  const existing = await User.findOne({ username });
  if (existing) return res.status(400).json({ error: 'username taken' });

  const hash = await bcrypt.hash(password, 10);
  const referralCode = require('crypto').randomBytes(4).toString('hex');
  const user = new User({ username, passwordHash: hash, referralCode, sweepCoins: 1000, referredBy: referral || null });
  await user.save();

  if (referral) {
    const referrer = await User.findOne({ referralCode: referral });
    if (referrer) {
      referrer.sweepCoins += 200;
      await referrer.save();
      user.sweepCoins += 100;
      await user.save();
    }
  }

  const token = jwt.sign({ id: user._id, username: user.username, isAdmin: user.isAdmin }, JWT_SECRET);
  res.json({ token, user: { username: user.username, sweepCoins: user.sweepCoins, referralCode: user.referralCode } });
});

router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  const user = await User.findOne({ username });
  if (!user) return res.status(400).json({ error: 'invalid credentials' });
  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) return res.status(400).json({ error: 'invalid credentials' });
  const token = jwt.sign({ id: user._id, username: user.username, isAdmin: user.isAdmin }, JWT_SECRET);
  res.json({ token, user: { username: user.username, sweepCoins: user.sweepCoins, referralCode: user.referralCode, isAdmin: user.isAdmin } });
});

router.get('/me', async (req, res) => {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ error: 'unauthorized' });
  const token = auth.split(' ')[1];
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    const user = await User.findById(payload.id);
    res.json({ username: user.username, sweepCoins: user.sweepCoins, referralCode: user.referralCode, isAdmin: user.isAdmin });
  } catch (err) {
    res.status(401).json({ error: 'invalid token' });
  }
});

module.exports = router;
EOF

# ===== server/src/games.js =====
cat > server/src/games.js <<'EOF'
const express = require('express');
const router = express.Router();
const { Game, Round, User } = require('./models');
const { hmacSha256Hex, percentileFromDigest, diceFromDigest, slotsFromDigest, shuffleDeck } = require('./utils/provablyFair');
const { encryptSeed, decryptSeed } = require('./utils/cryptoStore');
const { systemPrompt, userPrompt } = require('./utils/aiPromptTemplates');
const { Configuration, OpenAIApi } = require('openai');
const jwt = require('jsonwebtoken');

const OPENAI_KEY = process.env.OPENAI_API_KEY;
const openai = OPENAI_KEY ? new OpenAIApi(new Configuration({ apiKey: OPENAI_KEY })) : null;

function authMiddleware(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ error: 'unauthorized' });
  const token = auth.split(' ')[1];
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET || 'dev_secret');
    next();
  } catch (err) {
    res.status(401).json({ error: 'invalid token' });
  }
}

const crypto = require('crypto');
function randomHex(bytes = 32) { return crypto.randomBytes(bytes).toString('hex'); }

router.post('/generate', authMiddleware, async (req, res) => {
  const { prompt } = req.body;
  if (!prompt) return res.status(400).json({ error: 'prompt required' });

  if (!openai) return res.status(400).json({ error: 'OpenAI API not configured' });
  if (/(copy|clone|exact|emulate).*(poker|blackjack|slot|casino|roulette|baccarat)/i.test(prompt)) {
    return res.status(400).json({ error: 'Please request an original game without copying existing commercial games.' });
  }

  const messages = [
    { role: 'system', content: systemPrompt() },
    { role: 'user', content: userPrompt(prompt) }
  ];

  const completion = await openai.createChatCompletion({
    model: 'gpt-4o-mini',
    messages,
    max_tokens: 800
  });

  let aiText = completion.data.choices[0].message.content;
  let spec;
  try {
    spec = JSON.parse(aiText);
  } catch (e) {
    const m = aiText.match(/\{[\s\S]*\}$/);
    if (!m) return res.status(500).json({ error: 'AI did not return JSON' });
    spec = JSON.parse(m[0]);
  }

  const serverSeed = randomHex(32);
  const encrypted = encryptSeed(serverSeed);
  const serverSeedHash = crypto.createHash('sha256').update(serverSeed).digest('hex');

  const game = new Game({
    title: spec.title || 'Untitled',
    description: spec.description || '',
    spec,
    creatorId: req.user.username,
    epoch: 1,
    serverSeedEncrypted: encrypted,
    serverSeedHash
  });
  await game.save();
  res.json({ gameId: game._id, title: game.title, spec: game.spec, serverSeedHash, epoch: game.epoch });
});

router.post('/:gameId/play', authMiddleware, async (req, res) => {
  const { clientSeed } = req.body;
  const { gameId } = req.params;
  const user = await User.findOne({ username: req.user.username });
  if (!user) return res.status(404).json({ error: 'user not found' });

  const game = await Game.findById(gameId);
  if (!game) return res.status(404).json({ error: 'game not found' });

  const prev = await Round.countDocuments({ gameId, userId: user.username, epoch: game.epoch });
  const nonce = prev + 1;
  const cs = clientSeed || randomHex(8);
  let serverSeedHex;
  try {
    serverSeedHex = decryptSeed(game.serverSeedEncrypted);
  } catch (err) {
    return res.status(500).json({ error: 'cannot decrypt server seed' });
  }
  const message = `${cs}:${nonce}:${game.epoch}`;
  const digest = hmacSha256Hex(serverSeedHex, message);

  const resolutionType = game.spec?.resolutionType || 'percentile';
  let result;
  if (resolutionType === 'dice') {
    const sides = game.spec?.sampleParameters?.sides || 6;
    result = { diceValue: diceFromDigest(digest, sides), digest };
  } else if (resolutionType === 'slots') {
    const reels = game.spec?.sampleParameters?.reels;
    if (!reels) {
      result = { error: 'game spec missing reels config' };
    } else {
      result = { spins: slotsFromDigest(digest, reels), digest };
    }
  } else if (resolutionType === 'deck') {
    const deck = game.spec?.sampleParameters?.deck;
    if (!deck) {
      result = { error: 'game spec missing deck config' };
    } else {
      result = { shuffled: shuffleDeck(digest, deck), digest };
    }
  } else {
    const p = percentileFromDigest(digest);
    result = { percentile: p, digest };
  }

  const round = new Round({
    gameId,
    userId: user.username,
    clientSeed: cs,
    epoch: game.epoch,
    nonce,
    result
  });
  await round.save();

  if ((result.percentile && result.percentile >= 95) || (result.diceValue && result.diceValue >= 6) || (result.spins && result.spins.every(s => s.index === 0))) {
    user.sweepCoins += 200;
    await user.save();
  }

  res.json({ roundId: round._id, result, serverSeedHash: game.serverSeedHash, epoch: game.epoch });
});

router.post('/:gameId/reveal', authMiddleware, async (req, res) => {
  const game = await Game.findById(req.params.gameId);
  if (!game) return res.status(404).json({ error: 'game not found' });
  if (!(req.user.isAdmin || req.user.username === game.creatorId)) return res.status(403).json({ error: 'forbidden' });
  const seed = decryptSeed(game.serverSeedEncrypted);
  res.json({ serverSeed: seed, serverSeedHash: game.serverSeedHash, epoch: game.epoch });
});

router.post('/:gameId/rotate-seed', authMiddleware, async (req, res) => {
  if (!req.user.isAdmin) return res.status(403).json({ error: 'admin only' });
  const game = await Game.findById(req.params.gameId);
  if (!game) return res.status(404).json({ error: 'game not found' });
  const newSeed = randomHex(32);
  const encrypted = encryptSeed(newSeed);
  const hash = crypto.createHash('sha256').update(newSeed).digest('hex');
  game.epoch += 1;
  game.serverSeedEncrypted = encrypted;
  game.serverSeedHash = hash;
  await game.save();
  res.json({ gameId: game._id, epoch: game.epoch, serverSeedHash: game.serverSeedHash });
});

router.post('/verify', (req, res) => {
  const { serverSeed, clientSeed, nonce, epoch, resolutionType, params } = req.body;
  if (!serverSeed || clientSeed == null || !nonce || !epoch) return res.status(400).json({ error: 'serverSeed, clientSeed, nonce, epoch required' });
  const message = `${clientSeed}:${nonce}:${epoch}`;
  const digest = require('crypto').createHmac('sha256', Buffer.from(serverSeed, 'hex')).update(message).digest('hex');
  let computed;
  if (resolutionType === 'dice') computed = { diceValue: require('./utils/provablyFair').diceFromDigest(digest, params?.sides || 6) };
  else if (resolutionType === 'slots') computed = { spins: require('./utils/provablyFair').slotsFromDigest(digest, params.reels) };
  else if (resolutionType === 'deck') computed = { shuffled: require('./utils/provablyFair').shuffleDeck(digest, params.deck) };
  else computed = { percentile: require('./utils/provablyFair').percentileFromDigest(digest) };
  res.json({ digest, computed, serverSeedHash: require('crypto').createHash('sha256').update(serverSeed).digest('hex') });
});

module.exports = router;
EOF

# ===== server/src/payments.js =====
cat > server/src/payments.js <<'EOF'
const express = require('express');
const router = express.Router();
const Stripe = require('stripe');
const jwt = require('jsonwebtoken');
const { User } = require('./models');

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_placeholder', { apiVersion: '2022-11-15' });

function authMiddleware(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ error: 'unauthorized' });
  const token = auth.split(' ')[1];
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET || 'dev_secret');
    next();
  } catch (err) {
    res.status(401).json({ error: 'invalid token' });
  }
}

router.post('/create-checkout-session', authMiddleware, async (req, res) => {
  const { amountUsd } = req.body;
  if (!amountUsd) return res.status(400).json({ error: 'amountUsd required' });

  const sweepPerUsd = 100;
  const sweepAmount = amountUsd * sweepPerUsd;

  const session = await stripe.checkout.sessions.create({
    mode: 'payment',
    payment_method_types: ['card'],
    line_items: [{
      price_data: {
        currency: 'usd',
        product_data: { name: `SweepCoins x${sweepAmount}` },
        unit_amount: Math.round(amountUsd * 100)
      },
      quantity: 1
    }],
    success_url: `${process.env.CLIENT_BASE_URL || 'http://localhost:3000'}/?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.CLIENT_BASE_URL || 'http://localhost:3000'}/payments/cancel`
  });

  res.json({ url: session.url });
});

router.post('/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const event = req.body;

  try {
    const eType = event.type || (event?.data?.object?.payment_status ? 'checkout.session.completed' : null);
    if (eType === 'checkout.session.completed') {
      const session = event.data.object;
      console.log('Payment completed (demo)', session);
    }
    res.json({ received: true });
  } catch (err) {
    console.error('Webhook error', err);
    res.status(500).end();
  }
});

module.exports = router;
EOF

# ===== server/src/admin.js =====
cat > server/src/admin.js <<'EOF'
const express = require('express');
const router = express.Router();
const { Game, User, Round } = require('./models');
const jwt = require('jsonwebtoken');

function authMiddleware(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ error: 'unauthorized' });
  const token = auth.split(' ')[1];
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET || 'dev_secret');
    next();
  } catch (err) {
    res.status(401).json({ error: 'invalid token' });
  }
}

router.get('/stats', authMiddleware, async (req, res) => {
  if (!req.user.isAdmin) return res.status(403).json({ error: 'admin only' });
  const userCount = await User.countDocuments();
  const gameCount = await Game.countDocuments();
  const roundCount = await Round.countDocuments();
  res.json({ userCount, gameCount, roundCount });
});

router.get('/games', authMiddleware, async (req, res) => {
  if (!req.user.isAdmin) return res.status(403).json({ error: 'admin only' });
  const games = await Game.find();
  res.json(games);
});

module.exports = router;
EOF

# ===== server/src/realtime.js =====
cat > server/src/realtime.js <<'EOF'
const { Server } = require('socket.io');
const { Game } = require('./models');

function initRealtime(httpServer) {
  const io = new Server(httpServer, { cors: { origin: '*' } });

  io.on('connection', (socket) => {
    console.log('socket connected', socket.id);

    socket.on('joinLobby', async () => {
      const games = await Game.find({}, { title: 1, description: 1, epoch: 1 });
      socket.emit('lobbyGames', games);
    });

    socket.on('joinRoom', (roomId, username) => {
      socket.join(roomId);
      io.to(roomId).emit('systemMessage', \`\${username} joined the room.\`);
    });

    socket.on('leaveRoom', (roomId, username) => {
      socket.leave(roomId);
      io.to(roomId).emit('systemMessage', \`\${username} left the room.\`);
    });

    socket.on('roomMessage', (roomId, payload) => {
      io.to(roomId).emit('roomMessage', payload);
    });

    socket.on('disconnect', () => {
      console.log('socket disconnected', socket.id);
    });
  });

  return io;
}

module.exports = initRealtime;
EOF

# ===== server/src/index.js =====
cat > server/src/index.js <<'EOF'
require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const mongoose = require('mongoose');
const http = require('http');

const authRoutes = require('./auth');
const gamesRoutes = require('./games');
const paymentsRoutes = require('./payments');
const adminRoutes = require('./admin');
const initRealtime = require('./realtime');

const app = express();
const PORT = process.env.PORT || 4000;

app.use(cors());
app.use(bodyParser.json());

mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/ai-games', {
  useNewUrlParser: true,
  useUnifiedTopology: true
}).then(() => console.log('Mongo connected')).catch(err => console.error(err));

app.use('/api/auth', authRoutes);
app.use('/api/games', gamesRoutes);
app.use('/api/payments', paymentsRoutes);
app.use('/api/admin', adminRoutes);

app.get('/', (req, res) => res.send('AI Game Platform API'));

const server = http.createServer(app);
const io = initRealtime(server);

server.listen(PORT, () => console.log(\`Server listening on \${PORT}\`));
EOF

# ===== client/package.json =====
cat > client/package.json <<'EOF'
{
  "name": "ai-game-platform-client",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "socket.io-client": "^4.8.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build"
  }
}
EOF

# ===== client/src/api.js =====
cat > client/src/api.js <<'EOF'
const API_BASE = 'http://localhost:4000/api';

export async function register(username, password, referral) {
  const res = await fetch(`${API_BASE}/auth/register`, {
    method: 'POST', headers: {'Content-Type':'application/json'},
    body: JSON.stringify({ username, password, referral })
  });
  return res.json();
}

export async function login(username, password) {
  const res = await fetch(`${API_BASE}/auth/login`, {
    method: 'POST', headers: {'Content-Type':'application/json'},
    body: JSON.stringify({ username, password })
  });
  return res.json();
}

export async function me(token) {
  const res = await fetch(`${API_BASE}/auth/me`, { headers: { Authorization: `Bearer ${token}` } });
  return res.json();
}

export async function generateGame(token, prompt) {
  const res = await fetch(`${API_BASE}/games/generate`, {
    method: 'POST', headers: { 'Content-Type':'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ prompt })
  });
  return res.json();
}

export async function playGame(token, gameId, clientSeed) {
  const res = await fetch(`${API_BASE}/games/${gameId}/play`, {
    method: 'POST', headers: {'Content-Type':'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ clientSeed })
  });
  return res.json();
}

export async function createCheckout(token, amountUsd) {
  const res = await fetch(`${API_BASE}/payments/create-checkout-session`, {
    method: 'POST', headers: {'Content-Type':'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ amountUsd })
  });
  return res.json();
}

export async function adminGames(token) {
  const res = await fetch(`${API_BASE}/admin/games`, { headers: { Authorization: `Bearer ${token}` } });
  return res.json();
}

export async function adminStats(token) {
  const res = await fetch(`${API_BASE}/admin/stats`, { headers: { Authorization: `Bearer ${token}` } });
  return res.json();
}
EOF

# ===== client/src/Lobby.js =====
cat > client/src/Lobby.js <<'EOF'
import React, { useEffect, useState } from 'react';
import { io } from 'socket.io-client';

export default function Lobby({ serverUrl = 'http://localhost:4000' }) {
  const [socket, setSocket] = useState(null);
  const [games, setGames] = useState([]);

  useEffect(() => {
    const s = io(serverUrl);
    setSocket(s);
    s.on('connect', () => {
      s.emit('joinLobby');
    });
    s.on('lobbyGames', (payload) => setGames(payload));
    return () => s.disconnect();
  }, [serverUrl]);

  return (
    <div>
      <h3>Lobby</h3>
      <ul>
        {games.map(g => <li key={g._id}>{g.title} — {g.description} (epoch {g.epoch})</li>)}
      </ul>
      <p>Click a game to open a room (not fully implemented).</p>
    </div>
  );
}
EOF

# ===== client/src/GameEditor.js =====
cat > client/src/GameEditor.js <<'EOF'
import React, { useState } from 'react';

export default function GameEditor({ initial, onSave }) {
  const [jsonText, setJsonText] = useState(JSON.stringify(initial || { title: '', description: '' }, null, 2));
  return (
    <div>
      <h4>Game Editor</h4>
      <textarea style={{ width: '100%', height: 200 }} value={jsonText} onChange={e=>setJsonText(e.target.value)} />
      <button onClick={() => {
        try {
          const parsed = JSON.parse(jsonText);
          onSave(parsed);
        } catch (err) {
          alert('Invalid JSON');
        }
      }}>Save</button>
    </div>
  );
}
EOF

# ===== client/src/MultiplayerRoom.js =====
cat > client/src/MultiplayerRoom.js <<'EOF'
import React, { useEffect, useState } from 'react';
import { io } from 'socket.io-client';

export default function MultiplayerRoom({ roomId, username, serverUrl = 'http://localhost:4000' }) {
  const [socket, setSocket] = useState(null);
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState('');

  useEffect(() => {
    const s = io(serverUrl);
    setSocket(s);
    s.on('connect', () => {
      s.emit('joinRoom', roomId, username);
    });
    s.on('roomMessage', (m) => setMessages(prev => [...prev, m]));
    s.on('systemMessage', (m) => setMessages(prev => [...prev, { system: true, text: m }]));
    return () => {
      s.emit('leaveRoom', roomId, username);
      s.disconnect();
    };
  }, [roomId, username, serverUrl]);

  function send() {
    if (socket && text.trim()) {
      socket.emit('roomMessage', roomId, { username, text });
      setText('');
    }
  }

  return (
    <div>
      <h4>Room {roomId}</h4>
      <div style={{ border: '1px solid #ccc', padding: 8, height: 200, overflow: 'auto' }}>
        {messages.map((m, i) => (
          <div key={i} style={{ color: m.system ? 'gray' : 'black' }}>
            {m.system ? m.text : `${m.username}: ${m.text}`}
          </div>
        ))}
      </div>
      <input value={text} onChange={e=>setText(e.target.value)} />
      <button onClick={send}>Send</button>
    </div>
  );
}
EOF

# ===== client/src/AdminDashboard.js =====
cat > client/src/AdminDashboard.js <<'EOF'
import React, { useEffect, useState } from 'react';
import { adminGames, adminStats } from './api';

export default function AdminDashboard({ token }) {
  const [games, setGames] = useState([]);
  const [stats, setStats] = useState(null);

  useEffect(() => {
    async function load() {
      const g = await adminGames(token);
      const s = await adminStats(token);
      setGames(g);
      setStats(s);
    }
    if (token) load();
  }, [token]);

  return (
    <div>
      <h3>Admin Dashboard</h3>
      {stats && <div>
        <p>Users: {stats.userCount}</p>
        <p>Games: {stats.gameCount}</p>
        <p>Rounds: {stats.roundCount}</p>
      </div>}
      <h4>Games</h4>
      <ul>
        {games.map(g => <li key={g._id}>{g.title} (epoch {g.epoch}) - created by {g.creatorId}</li>)}
      </ul>
    </div>
  );
}
EOF

# ===== client/src/App.js =====
cat > client/src/App.js <<'EOF'
import React, { useState, useEffect } from 'react';
import { register, login, generateGame, playGame, createCheckout, me } from './api';
import AdminDashboard from './AdminDashboard';
import Lobby from './Lobby';
import GameEditor from './GameEditor';
import MultiplayerRoom from './MultiplayerRoom';

function App(){
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [token, setToken] = useState(null);
  const [game, setGame] = useState(null);
  const [prompt, setPrompt] = useState('');
  const [userInfo, setUserInfo] = useState(null);
  const [showLobby, setShowLobby] = useState(false);
  const [roomId, setRoomId] = useState(null);

  useEffect(() => {
    if (token) {
      me(token).then(u => setUserInfo(u));
    }
  }, [token]);

  async function doRegister() {
    const r = await register(username, password);
    if (r.token) {
      setToken(r.token);
      setUserInfo(r.user);
    } else {
      alert(JSON.stringify(r));
    }
  }

  async function doLogin() {
    const r = await login(username, password);
    if (r.token) {
      setToken(r.token);
      setUserInfo(r.user);
    } else {
      alert(JSON.stringify(r));
    }
  }

  async function doGenerate() {
    if (!token) return alert('Login first');
    const r = await generateGame(token, prompt);
    setGame(r);
  }

  async function doPlay() {
    if (!token || !game) return alert('Login and generate game first');
    const cs = Math.random().toString(36).slice(2,12);
    const r = await playGame(token, game.gameId, cs);
    alert(JSON.stringify(r.result));
  }

  async function buyCoins() {
    if (!token) return alert('Login first');
    const r = await createCheckout(token, 5);
    if (r.url) window.location.href = r.url;
  }

  return (
    <div style={{ padding: 20 }}>
      <h2>AI Game Platform Demo</h2>
      {!token && (
        <div>
          <input placeholder="username" value={username} onChange={e=>setUsername(e.target.value)} />
          <input placeholder="password" type="password" value={password} onChange={e=>setPassword(e.target.value)} />
          <button onClick={doRegister}>Register</button>
          <button onClick={doLogin}>Login</button>
        </div>
      )}
      {token && (
        <div>
          <p>Logged in as {userInfo?.username}</p>
          <p>SweepCoins: {userInfo?.sweepCoins}</p>
          <hr/>
          <textarea value={prompt} onChange={e=>setPrompt(e.target.value)} rows={4} cols={60} placeholder="Describe an original casual game idea"></textarea>
          <br/>
          <button onClick={doGenerate}>Generate Game</button>
          {game && (
            <div>
              <h3>{game.title}</h3>
              <pre style={{ maxHeight: 200, overflow: 'auto' }}>{JSON.stringify(game.spec, null, 2)}</pre>
              <button onClick={doPlay}>Play a Demo Round</button>
            </div>
          )}
          <hr/>
          <button onClick={buyCoins}>Buy SweepCoins ($5)</button>
          <button onClick={() => setShowLobby(s => !s)}>{showLobby ? 'Hide Lobby' : 'Show Lobby'}</button>
          {showLobby && <Lobby />}
          <hr />
          <h4>Multiplayer (demo)</h4>
          <input placeholder="room id" value={roomId || ''} onChange={e => setRoomId(e.target.value)} />
          {roomId && <MultiplayerRoom roomId={roomId} username={userInfo?.username || 'guest'} />}
          <hr/>
          {userInfo?.isAdmin && <AdminDashboard token={token} />}
        </div>
      )}
      <hr/>
      <h5>Game Editor</h5>
      <GameEditor initial={game?.spec} onSave={(spec) => alert('Local save (demo): ' + JSON.stringify(spec))} />
    </div>
  );
}

export default App;
EOF

# ===== client/src/index.js =====
cat > client/src/index.js <<'EOF'
import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
createRoot(document.getElementById('root')).render(<App />);
EOF

# ===== Create root HTML for client (public/index.html minimal) =====
mkdir -p client/public
cat > client/public/index.html <<'EOF'
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>AI Game Platform Demo</title>
  </head>
  <body>
    <div id="root"></div>
    <script src="/static/js/bundle.js"></script>
  </body>
</html>
EOF

# Done creating files
echo "Files created."

# Initialize git
if [ ! -d .git ]; then
  git init
  git checkout -b "$BRANCH"
  git add .
  git commit -m "Initial commit — AI Game Platform Demo (generated by setup_repo.sh)"
  echo "Git repo initialized and initial commit created on branch '$BRANCH'."
else
  echo "Git repository already initialized; skipping git init."
fi

# Create remote & push if requested
if [ -n "$GITHUB_REPO" ]; then
  echo "Creating GitHub repo $GITHUB_REPO using gh..."
  gh repo create "$GITHUB_REPO" --public --source=. --remote=origin --push || true
  echo "Repository created/pushed using gh (if permitted)."
  if $PUSH; then
    echo "Pushing to origin $BRANCH..."
    git push -u origin "$BRANCH"
  fi
fi

# Optionally npm install
if $INSTALL_NODE; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "npm not found; skipping npm install."
  else
    echo "Installing server dependencies..."
    (cd server && npm install)
    echo "Installing client dependencies..."
    (cd client && npm install)
  fi
fi

# Final instructions
cat <<EOF

Repository skeleton created in: $(pwd)

Next steps (important):
1) Copy server/.env.example -> server/.env and fill values (OPENAI_API_KEY, MONGO_URI, JWT_SECRET, STRIPE keys, MASTER_KEY).
   - Generate MASTER_KEY: openssl rand -hex 32
   - Do NOT commit server/.env to GitHub.

2) Start MongoDB (local or use MongoDB Atlas).
   - Local quick: docker run -p 27017:27017 --name mongo -d mongo:latest

3) Run server:
   cd server
   npm install
   npm run dev

4) Run client:
   cd client
   npm install
   npm start

5) Use the client web UI (http://localhost:3000) to register, generate games (if OPENAI_API_KEY is set), play rounds, view lobby.

