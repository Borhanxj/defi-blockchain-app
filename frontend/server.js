const https = require('https');
const fs = require('fs');
const path = require('path');

const options = {
  key: fs.readFileSync('./localhost+2-key.pem'),
  cert: fs.readFileSync('./localhost+2.pem')
};

https.createServer(options, (req, res) => {
  const filePath = path.join(__dirname, req.url === '/' ? 'index.html' : req.url);
  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end('404 Not Found');
    } else {
      res.writeHead(200);
      res.end(data);
    }
  });
}).listen(4433, () => {
  console.log('HTTPS Server running at https://localhost:4433/');
});
