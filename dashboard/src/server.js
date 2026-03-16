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
      youtube: { status: 'disconnected', viewers: 0, bitrate: 0 },
      facebook: { status: 'disconnected', viewers: 0, bitrate: 0 },
      instagram: { status: 'disconnected', viewers: 0, bitrate: 0 },
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
            bytesIn: parseInt(stream.bytes_in?.[0] || 0),
            bytesOut: parseInt(stream.bytes_out?.[0] || 0),
            clients: [],
          };

          // Process clients (viewers)
          if (stream.client) {
            const clients = Array.isArray(stream.client)
              ? stream.client
              : [stream.client];

            clients.forEach(client => {
              const address = client.address?.[0] || '';
              const isPublisher = client.publishing?.[0] !== undefined;

              streamInfo.clients.push({
                id: client.id?.[0] || 'unknown',
                address: address,
                time: parseInt(client.time?.[0] || 0),
                dropped: parseInt(client.dropped?.[0] || 0),
                isPublisher: isPublisher,
              });

              // Detect platform by analyzing the stream flow
              // This is a simple heuristic based on the client count and direction
              if (!isPublisher) {
                // These are outgoing streams to platforms
                const totalBandwidth = streamInfo.bandwidth.video + streamInfo.bandwidth.audio;

                // We can't reliably detect which platform each client is
                // So we'll mark all platforms as "connected" if there are active streams
                if (totalBandwidth > 0) {
                  result.platforms.youtube.status = 'connected';
                  result.platforms.youtube.bitrate = totalBandwidth;
                  result.platforms.facebook.status = 'connected';
                  result.platforms.facebook.bitrate = totalBandwidth;
                }
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
  console.log(`Nginx:     ${NGINX_STAT_URL}`);
  console.log(`========================================`);
});
