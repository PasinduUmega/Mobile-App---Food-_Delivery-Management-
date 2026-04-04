const express = require("express");
const cors = require("cors");
const http = require("http");
const { WebSocketServer } = require("ws");
require("dotenv").config();

const usersRouter = require("./routes/users");
const restaurantsRouter = require("./routes/restaurants");
const menuItemsRouter = require("./routes/menu_items");
const { dbHealthCheck } = require("./db/pool");

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ noServer: true });

// WebSocket setup
const clients = new Set();
wss.on("connection", (ws) => {
  clients.add(ws);
  ws.on("close", () => clients.delete(ws));
});

server.on("upgrade", (request, socket, head) => {
  if (request.url === "/ws") {
    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit("connection", ws, request);
    });
  } else {
    socket.destroy();
  }
});

function broadcast(data) {
  const payload = JSON.stringify(data);
  for (const client of clients) {
    if (client.readyState === 1) { // 1 = OPEN
      client.send(payload);
    }
  }
}

app.set("wsBroadcaster", broadcast);

app.use(cors({ origin: process.env.CORS_ORIGIN || "*" }));
app.use(express.json());

// Request logger
app.use((req, res, next) => {
  // eslint-disable-next-line no-console
  console.log(`${new Date().toISOString()} [${req.method}] ${req.url}`);
  // eslint-disable-next-line no-console
  if (req.method !== 'GET') console.log('Body:', JSON.stringify(req.body));
  next();
});

app.get("/api/health", async (req, res) => {
  try {
    const ok = await dbHealthCheck();
    return res.json({ ok: true, database: ok });
  } catch (err) {
    return res.status(500).json({ ok: false, error: err?.message || String(err) });
  }
});

app.use("/api/users", usersRouter);
app.use("/restaurants", restaurantsRouter);
app.use("/menu-items", menuItemsRouter); // Matching the Flutter app's expected path

const port = Number(process.env.PORT || 8080); // Changed default to 8080 to match Flutter app
server.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`food_rush API listening on port ${port}`);
});

