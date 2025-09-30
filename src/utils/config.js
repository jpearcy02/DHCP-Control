const fs = require('fs');
const path = require('path');

// Load environment variables
require('dotenv').config();

// Load JSON config files
const loadConfig = (filename) => {
  const configPath = path.join(__dirname, '../../config', filename);
  if (fs.existsSync(configPath)) {
    return JSON.parse(fs.readFileSync(configPath, 'utf8'));
  }
  return {};
};

// Load configs in order (later overrides earlier)
const defaultConfig = loadConfig('default.json');
const envConfig = loadConfig(`${process.env.NODE_ENV || 'development'}.json`);
const localConfig = loadConfig('local.json'); // Not committed to git

// Deep merge function
const deepMerge = (target, ...sources) => {
  if (!sources.length) return target;
  const source = sources.shift();

  if (source) {
    Object.keys(source).forEach((key) => {
      if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
        if (!target[key]) target[key] = {};
        target[key] = deepMerge(Object.assign({}, target[key]), source[key]);
      } else {
        target[key] = source[key];
      }
    });
  }

  return deepMerge(target, ...sources);
};

// Merge all configs
const config = deepMerge({}, defaultConfig, envConfig, localConfig);

// Override with environment variables
if (process.env.PORT) config.service.port = parseInt(process.env.PORT, 10);
if (process.env.HOST) config.service.host = process.env.HOST;
if (process.env.LOG_LEVEL) config.logging.level = process.env.LOG_LEVEL;
if (process.env.AUTH_TOKEN) config.security.authToken = process.env.AUTH_TOKEN;
if (process.env.TLS_CERT_PATH) config.tls.certPath = process.env.TLS_CERT_PATH;
if (process.env.TLS_KEY_PATH) config.tls.keyPath = process.env.TLS_KEY_PATH;

// Validate required configuration
const validateConfig = () => {
  const errors = [];

  if (config.service.environment === 'production') {
    if (!config.security.authToken) {
      errors.push('AUTH_TOKEN is required in production');
    }
    if (config.tls.enabled && !fs.existsSync(config.tls.certPath)) {
      errors.push(`TLS certificate not found: ${config.tls.certPath}`);
    }
    if (config.tls.enabled && !fs.existsSync(config.tls.keyPath)) {
      errors.push(`TLS key not found: ${config.tls.keyPath}`);
    }
  }

  if (errors.length > 0) {
    throw new Error(`Configuration validation failed:\n${errors.join('\n')}`);
  }
};

// Run validation
validateConfig();

module.exports = config;