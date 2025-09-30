const winston = require('winston');
const DailyRotateFile = require('winston-daily-rotate-file');
const path = require('path');
const config = require('./config');

// Custom format for console output
const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    let msg = `${timestamp} [${level}]: ${message}`;
    if (Object.keys(meta).length > 0) {
      msg += ` ${JSON.stringify(meta)}`;
    }
    return msg;
  })
);

// JSON format for file output
const fileFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json()
);

// Create transports array
const transports = [];

// Console transport
if (config.logging.console) {
  transports.push(
    new winston.transports.Console({
      format: consoleFormat,
      level: config.logging.level
    })
  );
}

// File transports with rotation
if (config.logging.file.enabled) {
  // Application log
  transports.push(
    new DailyRotateFile({
      filename: path.join(config.logging.file.path, 'dhcp-agent-%DATE%.log'),
      datePattern: 'YYYY-MM-DD',
      maxSize: config.logging.file.maxSize,
      maxFiles: config.logging.file.maxFiles,
      format: fileFormat,
      level: config.logging.level
    })
  );

  // Error-only log
  transports.push(
    new DailyRotateFile({
      filename: path.join(config.logging.file.path, 'error-%DATE%.log'),
      datePattern: 'YYYY-MM-DD',
      maxSize: config.logging.file.maxSize,
      maxFiles: '90d',
      format: fileFormat,
      level: 'error'
    })
  );

  // Audit log
  transports.push(
    new DailyRotateFile({
      filename: path.join(config.logging.file.path, 'audit-%DATE%.log'),
      datePattern: 'YYYY-MM-DD',
      maxSize: config.logging.file.maxSize,
      maxFiles: '365d',
      format: fileFormat,
      level: 'info'
    })
  );
}

// Create logger instance
const logger = winston.createLogger({
  level: config.logging.level,
  format: fileFormat,
  transports,
  exitOnError: false
});

// Windows Event Log support (optional)
if (config.logging.windowsEventLog.enabled) {
  try {
    const { EventLogger } = require('node-windows');
    const eventLogger = new EventLogger(config.logging.windowsEventLog.source);

    // Wrap event logger
    const originalError = logger.error.bind(logger);
    const originalWarn = logger.warn.bind(logger);
    const originalInfo = logger.info.bind(logger);

    logger.error = (...args) => {
      originalError(...args);
      try {
        eventLogger.error(args[0]);
      } catch (e) {
        // Silent fail for event log
      }
    };

    logger.warn = (...args) => {
      originalWarn(...args);
      try {
        eventLogger.warn(args[0]);
      } catch (e) {
        // Silent fail
      }
    };

    logger.info = (...args) => {
      originalInfo(...args);
      try {
        eventLogger.info(args[0]);
      } catch (e) {
        // Silent fail
      }
    };
  } catch (error) {
    logger.warn('Windows Event Log integration failed', { error: error.message });
  }
}

module.exports = logger;