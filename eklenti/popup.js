// popup.js
const btn = document.getElementById("toggleBtn");
const statusEl = document.getElementById("status");
const connStatusEl = document.getElementById("connStatus");
const portInput = document.getElementById("portInput");
const saveBtn = document.getElementById("saveBtn");
const overlapCheckbox = document.getElementById("overlapCheckbox");

function renderToggle(enabled) {
  btn.textContent = enabled ? "Durdur" : "Baslat";
  btn.className = enabled ? "running" : "stopped";
  statusEl.textContent = enabled ? "Calisiyor" : "Durduruldu";
}

function renderConn(state) {
  // state: "ok" | "err" | "unknown"
  if (state === "ok") {
    connStatusEl.textContent = "Yerel uygulamaya baglandi";
    connStatusEl.className = "ok";
  } else if (state === "err") {
    connStatusEl.textContent = "Yerel uygulamaya baglanilamiyor - calistiginizdan emin olun";
    connStatusEl.className = "err";
  } else {
    connStatusEl.textContent = "";
    connStatusEl.className = "";
  }
}

chrome.storage.local.get(
  { enabled: true, port: 8765, lastConnState: "unknown", interruptOnOverlap: true },
  (res) => {
    renderToggle(res.enabled);
    portInput.value = res.port;
    renderConn(res.lastConnState);
    overlapCheckbox.checked = res.interruptOnOverlap;
  }
);

btn.addEventListener("click", () => {
  chrome.storage.local.get({ enabled: true }, ({ enabled }) => {
    const newState = !enabled;
    chrome.storage.local.set({ enabled: newState });
    chrome.runtime.sendMessage({ type: "toggle", enabled: newState });
    renderToggle(newState);
  });
});

saveBtn.addEventListener("click", () => {
  const newPort = parseInt(portInput.value, 10);
  if (!newPort || newPort < 1 || newPort > 65535) {
    portInput.style.borderColor = "#c62828";
    return;
  }
  portInput.style.borderColor = "#ccc";
  chrome.storage.local.set({ port: newPort }, () => {
    saveBtn.textContent = "Kaydedildi";
    setTimeout(() => { saveBtn.textContent = "Kaydet"; }, 1200);
    chrome.runtime.sendMessage({ type: "port-changed", port: newPort });
  });
});

overlapCheckbox.addEventListener("change", () => {
  const value = overlapCheckbox.checked;
  chrome.storage.local.set({ interruptOnOverlap: value });
  chrome.runtime.sendMessage({ type: "overlap-changed", interruptOnOverlap: value });
});

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && changes.lastConnState) {
    renderConn(changes.lastConnState.newValue);
  }
});
