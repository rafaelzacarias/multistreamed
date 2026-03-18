const express = require('express');
const http = require('http');
const xml2js = require('xml2js');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const NGINX_STAT_URL = process.env.NGINX_STAT_URL || 'http://multistreamed:8080/stat';

// Serve static files from public directory
app.use(express.static(path.join(__dirname, '../public')));

// API endpoint to get stream statistics
app.get('/api/stats', async (req, res) => {
  try {
    const statsXml = await fetchStats(NGINX_STAT_URL);
    const statsJson = await parseXmlStats(statsXml);
    const formattedStats = formatStats(statsJson);
    res.json(formattedStats);
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({
      error: 'Failed to fetch stream statistics',
      message: error.message
    });
  }
});

// API endpoint to get recent nginx error log entries
app.get('/api/logs', async (req, res) => {
  try {
    const lines = parseInt(req.query.lines) || 50;
    const safeLines = Math.min(Math.max(lines, 1), 200);
    const logs = await fetchNginxLogs(safeLines);
    res.json({ logs });
  } catch (error) {
    console.error('Error fetching logs:', error);
    res.json({ logs: [], error: error.message });
  }
});

// Fetch recent nginx error log entries from Docker stdout/stderr
function fetchNginxLogs(lines) {
  return new Promise((resolve) => {
    // In Docker, nginx error log is symlinked to stderr which goes to Docker logs
    // We read from the nginx error log directly if accessible
    try {
      const logUrl = NGINX_STAT_URL.replace('/stat', '/health');
      const baseUrl = new URL(NGINX_STAT_URL);
      const logHost = baseUrl.hostname;
      const logPort = baseUrl.port || 8080;

      // Fetch the raw stat XML and extract useful log-like information
      http.get(NGINX_STAT_URL, (response) => {
        let data = '';
        response.on('data', (chunk) => { data += chunk; });
        response.on('end', async () => {
          try {
            const stats = await parseXmlStats(data);
            const logEntries = extractLogEntries(stats);
            resolve(logEntries.slice(-lines));
          } catch {
            resolve([]);
          }
        });
      }).on('error', () => resolve([]));
    } catch {
      resolve([]);
    }
  });
}

// Extract log-like entries from the stat data (connection events, errors)
function extractLogEntries(stats) {
  const entries = [];
  const now = new Date();

  const server = stats.rtmp?.server?.[0];
  if (!server?.application) return entries;

  const applications = Array.isArray(server.application)
    ? server.application
    : [server.application];

  applications.forEach(app => {
    if (!app.live?.[0]?.stream) return;

    const streams = Array.isArray(app.live[0].stream)
      ? app.live[0].stream
      : [app.live[0].stream];

    streams.forEach(stream => {
      const streamName = stream.name?.[0] || 'unknown';

      if (stream.client) {
        const clients = Array.isArray(stream.client)
          ? stream.client
          : [stream.client];

        clients.forEach(client => {
          const address = client.address?.[0] || '';
          const isPublisher = client.publishing?.[0] !== undefined;
          const dropped = parseInt(client.dropped?.[0] || 0);
          const connTime = parseInt(client.time?.[0] || 0);
          const platform = detectPlatform(address, isPublisher);
          const connStart = new Date(now.getTime() - connTime);

          entries.push({
            timestamp: connStart.toISOString(),
            level: dropped > 100 ? 'warn' : 'info',
            message: `${isPublisher ? 'Publisher' : `Push to ${platform}`} from ${address} on '${streamName}' - connected ${formatDurationMs(connTime)} ago${dropped > 0 ? `, ${dropped} frames dropped` : ''}`
          });
        });
      }
    });
  });

  return entries.sort((a, b) => a.timestamp.localeCompare(b.timestamp));
}

function formatDurationMs(ms) {
  const seconds = Math.floor(ms / 1000);
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ${seconds % 60}s`;
  const hours = Math.floor(minutes / 60);
  return `${hours}h ${minutes % 60}m`;
}

// Fetch stats from Nginx RTMP module
function fetchStats(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (response) => {
      let data = '';

      response.on('data', (chunk) => {
        data += chunk;
      });

      response.on('end', () => {
        resolve(data);
      });
    }).on('error', (error) => {
      reject(error);
    });
  });
}

// Parse XML stats to JSON
async function parseXmlStats(xml) {
  const parser = new xml2js.Parser();
  return parser.parseStringPromise(xml);
}

// Detect platform based on client address
function detectPlatform(address, isPublisher) {
  if (isPublisher) return 'publisher';
  // Facebook streams go through stunnel on localhost
  if (address === '127.0.0.1') return 'facebook';
  // Everything else is YouTube (or other configured push destinations)
  return 'youtube';
}

// Format stats for dashboard consumption
function formatStats(stats) {
  const result = {
    timestamp: new Date().toISOString(),
    nginx: {
      version: stats.rtmp?.nginx_version?.[0] || 'unknown',
      uptime: parseInt(stats.rtmp?.uptime?.[0] || 0),
    },
    server: {
      bandwidth: {
        in: parseInt(stats.rtmp?.bw_in?.[0] || 0),
        out: parseInt(stats.rtmp?.bw_out?.[0] || 0),
      },
      bytesIn: parseInt(stats.rtmp?.bytes_in?.[0] || 0),
      bytesOut: parseInt(stats.rtmp?.bytes_out?.[0] || 0),
    },
    streams: [],
    platforms: {
      youtube: { status: 'inactive', viewers: 0, bitrate: 0, details: null },
      facebook: { status: 'inactive', viewers: 0, bitrate: 0, details: null },
    }
  };

  // Process applications and streams
  const server = stats.rtmp?.server?.[0];
  if (server?.application) {
    const applications = Array.isArray(server.application)
      ? server.application
      : [server.application];

    applications.forEach(app => {
      if (app.live?.[0]?.stream) {
        const streams = Array.isArray(app.live[0].stream)
          ? app.live[0].stream
          : [app.live[0].stream];

        streams.forEach(stream => {
          const streamInfo = {
            name: stream.name?.[0] || 'unknown',
            time: parseInt(stream.time?.[0] || 0),
            bandwidth: {
              video: parseInt(stream.bw_video?.[0] || 0),
              audio: parseInt(stream.bw_audio?.[0] || 0),
            },
            meta: {
              video: stream.meta?.video?.[0] || null,
              audio: stream.meta?.audio?.[0] || null,
            },
            bytesIn: parseInt(stream.bytes_in?.[0] || 0),
            bytesOut: parseInt(stream.bytes_out?.[0] || 0),
            clients: [],
          };

          // Process clients (viewers and push targets)
          if (stream.client) {
            const clients = Array.isArray(stream.client)
              ? stream.client
              : [stream.client];

            const totalBandwidth = streamInfo.bandwidth.video + streamInfo.bandwidth.audio;

            clients.forEach(client => {
              const address = client.address?.[0] || '';
              const isPublisher = client.publishing?.[0] !== undefined;
              const dropped = parseInt(client.dropped?.[0] || 0);
              const clientTime = parseInt(client.time?.[0] || 0);

              const clientInfo = {
                id: client.id?.[0] || 'unknown',
                address: address,
                time: clientTime,
                dropped: dropped,
                flashver: client.flashver?.[0] || '',
                isPublisher: isPublisher,
                bytesIn: parseInt(client.bytes_in?.[0] || 0),
                bytesOut: parseInt(client.bytes_out?.[0] || 0),
              };

              streamInfo.clients.push(clientInfo);

              // Detect platform based on client address
              const platform = detectPlatform(address, isPublisher);

              if (platform === 'facebook') {
                result.platforms.facebook.status = dropped > 100 ? 'degraded' : 'connected';
                result.platforms.facebook.bitrate = totalBandwidth;
                result.platforms.facebook.details = {
                  address: address,
                  connectionTime: clientTime,
                  dropped: dropped,
                  bytesOut: clientInfo.bytesOut,
                  protocol: 'RTMPS (via stunnel)',
                };
              } else if (platform === 'youtube') {
                result.platforms.youtube.status = dropped > 100 ? 'degraded' : 'connected';
                result.platforms.youtube.bitrate = totalBandwidth;
                result.platforms.youtube.details = {
                  address: address,
                  connectionTime: clientTime,
                  dropped: dropped,
                  bytesOut: clientInfo.bytesOut,
                  protocol: 'RTMP',
                };
              }
            });
          }

          result.streams.push(streamInfo);
        });
      }
    });
  }

  return result;
}

app.listen(PORT, '0.0.0.0', () => {
  console.log(`========================================`);
  console.log(`  Multistreamed Dashboard`);
  console.log(`========================================`);
  console.log(`Dashboard: http://localhost:${PORT}`);
  console.log(`API:       http://localhost:${PORT}/api/stats`);
  console.log(`Logs:      http://localhost:${PORT}/api/logs`);
  console.log(`Nginx:     ${NGINX_STAT_URL}`);
  console.log(`========================================`);
});
