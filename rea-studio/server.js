const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const https = require('https');
const { spawn } = require('child_process');

const app = express();
const PORT = process.env.PORT || 4321;
const CURRENT_VERSION = '6.8.0';

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const cleanName = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
    cb(null, `${Date.now()}_${cleanName}`);
  }
});
const upload = multer({ storage });

function runReaCommand(args) {
  return new Promise((resolve) => {
    const proc = spawn('npx', ['-y', 'rea-agents@latest', ...args], {
      shell: false,
      env: {
        ...process.env,
        NODE_OPTIONS: '--max-old-space-size=4096'
      }
    });

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (d) => {
      stdout += d.toString();
      if (stdout.length > 8 * 1024 * 1024) {
        proc.kill('SIGTERM');
      }
    });

    proc.stderr.on('data', (d) => {
      stderr += d.toString();
      if (stderr.length > 2 * 1024 * 1024) {
        stderr = stderr.slice(-100000);
      }
    });

    proc.on('close', (code) => {
      resolve({ code, stdout, stderr });
    });

    proc.on('error', (err) => {
      resolve({ code: -1, stdout: '', stderr: err.message });
    });
  });
}

// 1. Check for updates on npm registry
app.get('/api/check-update', (req, res) => {
  https.get('https://registry.npmjs.org/rea-agents/latest', { headers: { 'User-Agent': 'rea-studio' } }, (resp) => {
    let data = '';
    resp.on('data', (chunk) => { data += chunk; });
    resp.on('end', () => {
      try {
        const json = JSON.parse(data);
        const latestVersion = json.version || CURRENT_VERSION;
        const hasUpdate = latestVersion !== CURRENT_VERSION;
        res.json({
          currentVersion: CURRENT_VERSION,
          latestVersion,
          hasUpdate
        });
      } catch (e) {
        res.json({ currentVersion: CURRENT_VERSION, latestVersion: CURRENT_VERSION, hasUpdate: false });
      }
    });
  }).on('error', () => {
    res.json({ currentVersion: CURRENT_VERSION, latestVersion: CURRENT_VERSION, hasUpdate: false });
  });
});

// 2. Perform update
app.post('/api/perform-update', async (req, res) => {
  const result = await runReaCommand(['update']);
  res.json({
    success: result.code === 0,
    output: result.stdout || result.stderr
  });
});

// 3. Analyze general target
app.post('/api/analyze', async (req, res) => {
  const { targetPath, mode, query } = req.body;
  if (!targetPath) {
    return res.status(400).json({ error: 'targetPath é obrigatório' });
  }

  let args = [];
  if (mode === 'javascript') {
    args = ['analyze-javascript-application', targetPath, '--format', 'json', '--max-heap-mb', '2048'];
  } else if (mode === 'search') {
    args = ['search', targetPath, '--pattern', query || 'main', '--format', 'json'];
  } else if (mode === 'decompile') {
    args = ['decompile', targetPath, '--procedure', query || 'main', '--format', 'json'];
  } else if (mode === 'trace') {
    args = ['trace', targetPath, '--query', query || 'main', '--format', 'json'];
  } else {
    args = ['analyze', targetPath, '--format', 'json'];
  }

  try {
    const result = await runReaCommand(args);
    let parsed = null;

    try {
      const jsonStart = result.stdout.indexOf('{');
      const jsonArrayStart = result.stdout.indexOf('[');
      let startIdx = -1;
      if (jsonStart !== -1 && jsonArrayStart !== -1) {
        startIdx = Math.min(jsonStart, jsonArrayStart);
      } else if (jsonStart !== -1) {
        startIdx = jsonStart;
      } else if (jsonArrayStart !== -1) {
        startIdx = jsonArrayStart;
      }

      if (startIdx !== -1) {
        parsed = JSON.parse(result.stdout.slice(startIdx));
      }
    } catch (e) {}

    res.json({
      success: result.code === 0,
      exitCode: result.code,
      data: parsed,
      rawOutput: result.stdout || result.stderr
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 4. Upload file
app.post('/api/upload', upload.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Nenhum arquivo enviado' });
  }
  res.json({
    filePath: req.file.path,
    fileName: req.file.originalname,
    size: req.file.size
  });
});

app.listen(PORT, () => {
  console.log(`REA Studio visual rodando em http://localhost:${PORT}`);
});
