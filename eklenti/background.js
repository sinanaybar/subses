// background.js
// content.js'ten gelen zaman bilgisini localhost'taki Python
// HTTP sunucusuna (local_server.py) fetch ile POST eder.

let enabled = true;
let port = 8765;
let lastConnOk = null;

chrome.storage.local.get(
  { enabled: true, port: 8765, interruptOnOverlap: true, lastConnState: "unknown" },
  (res) => {
    enabled = res.enabled;
    port = res.port;
    if (res.lastConnState === "ok") lastConnOk = true;
    else if (res.lastConnState === "err") lastConnOk = false;
    notifyServer("/settings", { interrupt_on_overlap: res.interruptOnOverlap });
  }
);

chrome.runtime.onMessage.addListener((msg) => {
  if (msg.type === "toggle") {
    enabled = msg.enabled;
    notifyServer("/control", { enabled });
    return;
  }

  if (msg.type === "port-changed") {
    port = msg.port;
    lastConnOk = null; // yeni port icin durumu sifirla, tekrar denensin
    return;
  }

  if (msg.type === "overlap-changed") {
    notifyServer("/settings", { interrupt_on_overlap: msg.interruptOnOverlap });
    return;
  }

  if (msg.type === "time") {
    if (!enabled) return; // durdurulmusken zaman gondermeye gerek yok
    notifyServer("/time", msg);
  }
});

function notifyServer(path, body) {
  fetch(`http://localhost:${port}${path}`, {
    method: "POST",
    mode: "no-cors", // yerel sunucudan CORS basligi beklemeden istegi yolla
    headers: { "Content-Type": "text/plain" },
    body: JSON.stringify(body),
  })
    .then(() => {
      onConnResult(true);
    })
    .catch(() => {
      onConnResult(false);
    });
}

function onConnResult(ok) {
  if (lastConnOk === ok) return;
  lastConnOk = ok;

  chrome.storage.local.set({ lastConnState: ok ? "ok" : "err" });

  if (!ok) {
    chrome.notifications.create("subses-conn-error", {
      type: "basic",
      iconUrl: "icons/icon128.png",
      title: "YouTube Subses - Baglanti Hatasi",
      message: `Yerel uygulamaya (port ${port}) baglanilamadi. Dublaj uygulamasini baslattiginizdan ve portun dogru oldugundan emin olun.`,
      priority: 2,
    });
  } else {
    // Onceden hata varsa, duzeldigini de bildir
    chrome.notifications.create("subses-conn-ok", {
      type: "basic",
      iconUrl: "icons/icon128.png",
      title: "YouTube Subses",
      message: "Yerel uygulamaya baglanti kuruldu.",
      priority: 0,
    });
  }
}
