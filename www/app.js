const DEFAULT_SERVER = "http://media-server-share.taild3fa5b.ts.net:8090";
const STORAGE_KEY = "mediaServerManagerUrl";

const $ = (id) => document.getElementById(id);

function normalizeUrl(value) {
  return String(value || "").trim().replace(/\/+$/, "");
}

function migrateStoredUrl(value) {
  const url = normalizeUrl(value);

  if (
    url === "http://media-server-share:8088" ||
    url === "http://media-server-share:8090"
  ) {
    return DEFAULT_SERVER;
  }

  return url;
}

function setStatus(type, title, detail) {
  $("status-dot").className = "dot " + type;
  $("status-title").textContent = title;
  $("status-detail").textContent = detail;
}

function getServerUrl() {
  const storedUrl = migrateStoredUrl(localStorage.getItem(STORAGE_KEY));

  if (storedUrl) {
    localStorage.setItem(STORAGE_KEY, storedUrl);
  }

  return normalizeUrl(storedUrl || $("server-url").value || DEFAULT_SERVER);
}

async function checkHealth(url) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 6000);
  try {
    const response = await fetch(url + "/api/health", {
      method: "GET",
      cache: "no-store",
      signal: controller.signal
    });
    if (!response.ok) throw new Error("HTTP " + response.status);
    const payload = await response.json();
    return payload && payload.status === "ok";
  } finally {
    clearTimeout(timer);
  }
}

function openManager(url) {
  localStorage.setItem(STORAGE_KEY, url);
  window.location.replace(url);
}

async function connect() {
  const url = normalizeUrl($("server-url").value);
  if (!/^https?:\/\//i.test(url)) {
    setStatus("bad", "Dirección no válida", "Usa una URL que empiece por http:// o https://");
    return;
  }

  setStatus("checking", "Buscando servidor…", "Comprobando " + url);

  try {
    const ok = await checkHealth(url);
    if (!ok) throw new Error("Respuesta de salud no válida");
    setStatus("ok", "Servidor encontrado", "Media Server Manager está disponible");
    setTimeout(() => openManager(url), 350);
  } catch (error) {
    setStatus(
      "bad",
      "No se puede conectar",
      "Error: " + (error && error.message ? error.message : "conexión rechazada")
    );
  }
}

document.addEventListener("DOMContentLoaded", () => {
  const storedUrl = migrateStoredUrl(localStorage.getItem(STORAGE_KEY));

  if (storedUrl) {
    localStorage.setItem(STORAGE_KEY, storedUrl);
  }

  $("server-url").value = storedUrl || DEFAULT_SERVER;
  $("connect-btn").addEventListener("click", connect);
  $("retry-btn").addEventListener("click", connect);
  setTimeout(connect, 300);
});
