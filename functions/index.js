/**
 * functions/index.js
 */
const { setGlobalOptions } = require("firebase-functions");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const axios = require("axios");
const http = require("http");
const https = require("https");

const admin = require("firebase-admin");
const { FieldValue } = require("firebase-admin/firestore");

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const ax = axios.create({
    timeout: 15000,
    httpAgent: new http.Agent({ keepAlive: true, maxSockets: 10 }),
    httpsAgent: new https.Agent({ keepAlive: true, maxSockets: 10 })
})

setGlobalOptions({ maxInstances: 2 });

/** -----------------------------
 *  공통 유틸
 * ------------------------------ */
function toNum(v) {
  if (v === undefined || v === null) return null;
  const s = String(v).trim();
  if (s === '' || s === '-' ) return null;
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}
function pad2(n) { return String(n).padStart(2, "0"); }

function addDaysYmd(ymd, addDays) {
  const y = Number(ymd.slice(0, 4));
  const m = Number(ymd.slice(4, 6)) - 1;
  const d = Number(ymd.slice(6, 8));
  const dt = new Date(Date.UTC(y, m, d));
  dt.setUTCDate(dt.getUTCDate() + addDays);
  const yy = dt.getUTCFullYear();
  const mm = pad2(dt.getUTCMonth() + 1);
  const dd = pad2(dt.getUTCDate());
  return `${yy}${mm}${dd}`;
}

async function safe(promise, fallback, tag) {
  try {
    return await promise;
  } catch (e) {
    logger.warn(`${tag} failed (ignored)`, summarizeErr(e));
    return fallback;
  }
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

function isAxiosErr(e) {
  return !!(e && (e.isAxiosError || e.config || e.response));
}

function summarizeErr(e) {
  if (!isAxiosErr(e)) {
    return { msg: String(e?.message ?? e) };
  }
  const status = e?.response?.status ?? null;
  const method = e?.config?.method ?? null;
  const url = e?.config?.url ?? null;
  const header = e?.response?.data?.response?.header;
  const resultCode = header?.resultCode ? String(header.resultCode) : null;
  const resultMsg = header?.resultMsg ? String(header.resultMsg) : null;
  const retryAfter = e?.response?.headers?.['retry-after'] ?? null;
  const rawMsg = resultMsg || e?.message || '';
  const msg = String(rawMsg).slice(0, 160);
  return { status, method, url, resultCode, retryAfter, msg };
}

// 메모리 캐시 + 동시요청 합치기
const _mem = new Map();      
const _inflight = new Map(); 

function cacheGetFresh(key) {
  const v = _mem.get(key);
  if (!v) return null;
  if (Date.now() > v.exp) return null;
  return v.value;
}

function cacheGetStale(key, maxStaleMs) {
  const v = _mem.get(key);
  if (!v) return null;
  const age = Date.now() - (v.ts ?? 0);
  if (age > maxStaleMs) return null;
  return v.value;
}

function cacheSet(key, value, ttlMs) {
  _mem.set(key, { value, exp: Date.now() + ttlMs, ts: Date.now() });
  return value;
}

async function cached(key, ttlMs, fetcher, { staleMs = 15 * 60 * 1000 } = {}) {
  const hit = cacheGetFresh(key);
  if (hit) return hit;
  const stale = cacheGetStale(key, staleMs);
  const p0 = _inflight.get(key);
  if (p0) return p0;
  const p = (async () => {
    try {
      const v = await fetcher();
      return cacheSet(key, v, ttlMs);
    } catch (e) {
      const status = e?.response?.status;
      if (status === 429) {
        if (stale) return stale;
        return { items: [], _fallback: "429_empty" };
      }
      throw e;
    } finally {
      _inflight.delete(key);
    }
  })();
  _inflight.set(key, p);
  return p;
}

function isRetryable(e) {
  const s = e?.response?.status;
  if (s === 429) return false;
  if (s && s >= 400 && s < 500) return false;
  return true;
}

async function axGetWithRetry(tag, url, params, { max = 2 } = {}) {
  let lastErr;
  for (let i = 0; i <= max; i++) {
    try {
      return await ax.get(url, { params, timeout: 8000 });
    } catch (e) {
      lastErr = e;
      const status = e?.response?.status;
      if (status === 429) throw e;
      if (!isRetryable(e) || i === max) throw e;
      const wait = Math.min(800 * (2 ** i) + Math.floor(Math.random() * 300), 8000);
      await sleep(wait);
    }
  }
  throw lastErr;
}

let _kmaChain = Promise.resolve();
let _lastKmaAt = 0;

function withKmaLock(fn) {
  const p = _kmaChain.then(async () => {
    const gap = 1000;
    const wait = Math.max(0, gap - (Date.now() - _lastKmaAt));
    if (wait) await sleep(wait);
    _lastKmaAt = Date.now();
    return fn();
  });
  _kmaChain = p.catch(() => {});
  return p;
}

function latLonToGrid(lat, lon) {
  const RE = 6371.00877, GRID = 5.0, SLAT1 = 30.0, SLAT2 = 60.0, OLON = 126.0, OLAT = 38.0;
  const XO = 43, YO = 136;
  const DEGRAD = Math.PI / 180.0;
  const re = RE / GRID;
  const slat1 = SLAT1 * DEGRAD;
  const slat2 = SLAT2 * DEGRAD;
  const olon = OLON * DEGRAD;
  const olat = OLAT * DEGRAD;
  let sn = Math.tan(Math.PI * 0.25 + slat2 * 0.5) / Math.tan(Math.PI * 0.25 + slat1 * 0.5);
  sn = Math.log(Math.cos(slat1) / Math.cos(slat2)) / Math.log(sn);
  let sf = Math.tan(Math.PI * 0.25 + slat1 * 0.5);
  sf = Math.pow(sf, sn) * Math.cos(slat1) / sn;
  let ro = Math.tan(Math.PI * 0.25 + olat * 0.5);
  ro = re * sf / Math.pow(ro, sn);
  let ra = Math.tan(Math.PI * 0.25 + lat * DEGRAD * 0.5);
  ra = re * sf / Math.pow(ra, sn);
  let theta = lon * DEGRAD - olon;
  if (theta > Math.PI) theta -= 2.0 * Math.PI;
  if (theta < -Math.PI) theta += 2.0 * Math.PI;
  theta *= sn;
  const x = Math.floor(ra * Math.sin(theta) + XO + 0.5);
  const y = Math.floor(ro - ra * Math.cos(theta) + YO + 0.5);
  return { nx: x, ny: y };
}

function kmaNcstBase(dt) {
  const d = new Date(dt);
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  let hh = kst.getUTCHours();
  const mm = kst.getUTCMinutes();
  if (mm < 40) hh -= 1;
  if (hh < 0) { hh = 23; kst.setUTCDate(kst.getUTCDate() - 1); }
  return { base_date: `${kst.getUTCFullYear()}${pad2(kst.getUTCMonth() + 1)}${pad2(kst.getUTCDate())}`, base_time: `${pad2(hh)}00` };
}

function kmaUltraFcstBase(dt) {
  const d = new Date(dt);
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  let hh = kst.getUTCHours();
  const mm = kst.getUTCMinutes();
  if (mm < 45) hh -= 1;
  if (hh < 0) { hh = 23; kst.setUTCDate(kst.getUTCDate() - 1); }
  return { base_date: `${kst.getUTCFullYear()}${pad2(kst.getUTCMonth() + 1)}${pad2(kst.getUTCDate())}`, base_time: `${pad2(hh)}30` };
}

function kmaVilageBase(dt) {
  const d = new Date(dt);
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  const hh = kst.getUTCHours();
  const mm = kst.getUTCMinutes();
  const baseHours = [23, 20, 17, 14, 11, 8, 5, 2];
  let baseH = baseHours.find(h => hh > h || (hh === h && mm >= 10));
  if (baseH == null) { baseH = 23; kst.setUTCDate(kst.getUTCDate() - 1); }
  return { base_date: `${kst.getUTCFullYear()}${pad2(kst.getUTCMonth() + 1)}${pad2(kst.getUTCDate())}`, base_time: `${pad2(baseH)}00` };
}

async function callKmaUltraNcst(nx, ny) {
  const { base_date, base_time } = kmaNcstBase(new Date());
  const url = "http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst";
  const params = { ServiceKey: process.env.KMA_SERVICE_KEY, numOfRows: 1000, dataType: "JSON", base_date, base_time, nx, ny };
  return cached(`kmaNcst:${nx}:${ny}:${base_date}:${base_time}`, 2 * 60 * 1000, async () => {
    const res = await withKmaLock(() => axGetWithRetry("kmaNcst", url, params));
    return { items: res.data?.response?.body?.items?.item ?? [], base_date, base_time };
  });
}

async function callKmaUltraFcst(nx, ny) {
  const { base_date, base_time } = kmaUltraFcstBase(new Date());
  const url = "http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtFcst";
  const params = { ServiceKey: process.env.KMA_SERVICE_KEY, numOfRows: 1000, dataType: "JSON", base_date, base_time, nx, ny };
  return cached(`kmaUltra:${nx}:${ny}:${base_date}:${base_time}`, 3 * 60 * 1000, async () => {
    const res = await withKmaLock(() => axGetWithRetry("kmaUltra", url, params));
    return { items: res.data?.response?.body?.items?.item ?? [], base_date, base_time };
  });
}

async function callKmaVilageFcst(nx, ny) {
  const { base_date, base_time } = kmaVilageBase(new Date());
  const url = "http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst";
  const params = { ServiceKey: process.env.KMA_SERVICE_KEY, numOfRows: 1000, dataType: "JSON", base_date, base_time, nx, ny };
  return cached(`kmaVilage:${nx}:${ny}:${base_date}:${base_time}`, 15 * 60 * 1000, async () => {
    const res = await withKmaLock(() => axGetWithRetry("kmaVilage", url, params));
    return { items: res.data?.response?.body?.items?.item ?? [], base_date, base_time };
  });
}

function buildHourlyUltraRaw(items) {
  const byKey = new Map();
  for (const it of items) {
    const key = `${it.fcstDate}${it.fcstTime}`;
    if (!byKey.has(key)) byKey.set(key, { fcstDate: it.fcstDate, fcstTime: it.fcstTime });
    byKey.get(key)[it.category] = it.fcstValue;
  }
  return [...byKey.values()].map(v => ({ _k: `${v.fcstDate}${v.fcstTime}`, timeLabel: `${Number(String(v.fcstTime).slice(0, 2))}시`, sky: v.SKY != null ? Number(v.SKY) : null, pty: v.PTY != null ? Number(v.PTY) : null, temp: v.T1H != null ? Number(v.T1H) : (v.TMP != null ? Number(v.TMP) : null) })).filter(x => x.temp !== null).sort((a, b) => (a._k < b._k ? -1 : 1));
}

function buildHourlyFromVilage(items) {
  const byKey = new Map();
  for (const it of items) {
    const key = `${it.fcstDate}${it.fcstTime}`;
    if (!byKey.has(key)) byKey.set(key, { fcstDate: it.fcstDate, fcstTime: it.fcstTime });
    byKey.get(key)[it.category] = it.fcstValue;
  }
  return [...byKey.values()].map(v => ({ _k: `${v.fcstDate}${v.fcstTime}`, timeLabel: `${Number(String(v.fcstTime).slice(0, 2))}시`, sky: v.SKY != null ? Number(v.SKY) : null, pty: v.PTY != null ? Number(v.PTY) : null, temp: v.TMP != null ? Number(v.TMP) : null })).filter(x => x.temp !== null).sort((a, b) => (a._k < b._k ? -1 : 1));
}

function mergeHourly(ultra, vilage, take = 24) {
  const seen = new Set();
  const out = [];
  for (const x of ultra) { if (!x._k || seen.has(x._k)) continue; seen.add(x._k); out.push(x); }
  for (const x of vilage) { if (!x._k || seen.has(x._k)) continue; seen.add(x._k); out.push(x); }
  out.sort((a, b) => (a._k < b._k ? -1 : 1));
  if (out.length > 0) out[0].timeLabel = "NOW";
  return out.slice(0, take).map(({ _k, ...rest }) => rest);
}

function buildDailyFromVilage(items) {
  const byDate = new Map();
  for (const it of items) {
    const d = it.fcstDate;
    if (!byDate.has(d)) { byDate.set(d, { date: d, min: null, max: null, pop: null, sky12: null, pty: null, tmpMin: null, tmpMax: null }); }
    const row = byDate.get(d);
    if (it.category === "TMN") row.min = toNum(it.fcstValue);
    if (it.category === "TMX") row.max = toNum(it.fcstValue);
    if (it.category === "TMP") { const v = toNum(it.fcstValue); if (v != null) { row.tmpMin = row.tmpMin == null ? v : Math.min(row.tmpMin, v); row.tmpMax = row.tmpMax == null ? v : Math.max(row.tmpMax, v); } }
    if (it.category === "POP") { const v = toNum(it.fcstValue); if (v != null) row.pop = row.pop == null ? v : Math.max(row.pop, v); }
    if (it.category === "PTY") { const v = toNum(it.fcstValue); if (v != null) row.pty = row.pty == null ? v : Math.max(row.pty, v); }
    if (it.category === "SKY") { if (it.fcstTime === "1200") row.sky12 = toNum(it.fcstValue); if (row.sky12 == null) row.sky12 = toNum(it.fcstValue); }
  }
  for (const row of byDate.values()) { if (row.min == null) row.min = row.tmpMin; if (row.max == null) row.max = row.tmpMax; }
  return [...byDate.values()].sort((a, b) => (a.date < b.date ? -1 : 1)).slice(0, 4).map(d => ({ date: d.date, min: d.min, max: d.max, pop: d.pop, sky: d.sky12, pty: d.pty, wfText: null }));
}

async function callMidLand(regId, tmFc) {
  const res = await ax.get("http://apis.data.go.kr/1360000/MidFcstInfoService/getMidLandFcst", { params: { ServiceKey: process.env.KMA_SERVICE_KEY, dataType: "JSON", regId, tmFc } });
  return res.data?.response?.body?.items?.item?.[0] ?? null;
}

async function callMidTa(regId, tmFc) {
  const res = await ax.get("http://apis.data.go.kr/1360000/MidFcstInfoService/getMidTa", { params: { ServiceKey: process.env.KMA_SERVICE_KEY, dataType: "JSON", regId, tmFc } });
  return res.data?.response?.body?.items?.item?.[0] ?? null;
}

function appendMidToWeekly(shortList, midLand, midTa, baseYmd) {
  const out = [...shortList];
  for (let off = (out.length >= 4 ? 4 : 3); off <= 7; off++) {
    out.push({ date: addDaysYmd(baseYmd, off), min: toNum(midTa?.[`taMin${off}`]), max: toNum(midTa?.[`taMax${off}`]), wfText: midLand?.[`wf${off}Pm`] ?? null, pop: midLand?.[`rnSt${off}Pm`] != null ? toNum(midLand[`rnSt${off}Pm`]) : null });
  }
  return out.slice(0, 7);
}

function gradeTextFromKhai(grade) {
  const g = String(grade ?? "");
  if (g === "1") return "좋음";
  if (g === "2") return "보통";
  if (g === "3") return "나쁨";
  if (g === "4") return "매우나쁨";
  return "정보없음";
}

async function buildAir(addr, administrativeArea) {
  const uniq = [...new Set([addr, administrativeArea].map(s => String(s ?? "").trim()).filter(Boolean))];
  for (const cand of uniq) {
    const res1 = await ax.get("http://apis.data.go.kr/B552584/MsrstnInfoInqireSvc/getMsrstnList", { params: { serviceKey: process.env.AIRKOREA_SERVICE_KEY, returnType: "json", addr: cand } });
    for (const st of (res1.data?.response?.body?.items ?? [])) {
      if (!st?.stationName) continue;
      const res2 = await ax.get("http://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getMsrstnAcctoRltmMesureDnsty", { params: { serviceKey: process.env.AIRKOREA_SERVICE_KEY, returnType: "json", stationName: st.stationName, dataTerm: "DAILY", ver: "1.3" } });
      const hit = (res2.data?.response?.body?.items ?? []).find(r => toNum(r.pm10Value) != null || toNum(r.pm25Value) != null);
      if (hit) return { air: { gradeText: gradeTextFromKhai(hit.khaiGrade), pm10: toNum(hit.pm10Value), pm25: toNum(hit.pm25Value) } };
    }
  }
  return { air: { gradeText: "정보없음", pm10: null, pm25: null } };
}

exports.getDashboard = onCall({ region: "asia-northeast3" }, async (request) => {
  try {
    const { lat, lon, locationName } = request.data || {};
    if (typeof lat !== "number" || typeof lon !== "number") throw new HttpsError("invalid-argument", "lat/lon is required");
    const { nx, ny } = latLonToGrid(lat, lon);
    const addr = String(request.data?.addr ?? request.data?.locationName ?? "");
    const administrativeArea = String(request.data?.administrativeArea ?? "");
    const [kmaNcst, kmaUltra, kmaVilage, airRes] = await Promise.all([callKmaUltraNcst(nx, ny), callKmaUltraFcst(nx, ny), callKmaVilageFcst(nx, ny), safe(buildAir(addr, administrativeArea), { air: { gradeText: "정보없음", pm10: null, pm25: null } })]);
    const hourlyFcst = mergeHourly(buildHourlyUltraRaw(kmaUltra.items), buildHourlyFromVilage(kmaVilage.items));
    const weeklyShort = buildDailyFromVilage(kmaVilage.items);
    const [midLand, midTa] = await Promise.all([regIdLandFromAdmin(administrativeArea) ? safe(callMidLand(regIdLandFromAdmin(administrativeArea), midTmFc(new Date())), null) : null, regIdTaFromAdmin(administrativeArea) ? safe(callMidTa(regIdTaFromAdmin(administrativeArea), midTmFc(new Date())), null) : null]);
    const weekly = (midLand || midTa) ? appendMidToWeekly(weeklyShort, midLand, midTa, weeklyShort[0]?.date ?? "") : weeklyShort;
    return { updatedAt: new Date().toISOString(), locationName, weatherNow: kmaNcst.items, hourlyFcst, weekly, air: airRes.air };
  } catch (e) {
    logger.error("getDashboard failed", summarizeErr(e));
    throw new HttpsError("internal", `getDashboard failed: ${String(e?.message ?? e)}`);
  }
});

/** -----------------------------
 *  (5) 관리자 수동 알림 발송 (Alarm)
 * ------------------------------ */
exports.sendAdminNotification = onCall({ region: "asia-northeast3" }, async (request) => {
  const { title, body, topic } = request.data || {};
  if (!title || !body) throw new HttpsError("invalid-argument", "title and body are required");
  const message = { notification: { title, body }, data: { type: "admin_alarm" }, topic: topic || 'community_topic' };
  try {
    const response = await admin.messaging().send(message);
    await admin.firestore().collection("notifications").add({
      title, body, type: "admin_alarm",
      createdAt: FieldValue.serverTimestamp(),
      isRead: false
    });
    return { success: true, messageId: response };
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});

// Firestore 트리거 알림
exports.sendPostNotification = onDocumentCreated({
  document: "community/{postId}",
  region: "asia-northeast3"
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const postData = snapshot.data();
  const title = `새로운 교통 제보: ${postData.user_nickname || "익명"}님`;
  const body = (postData.content || postData.plain || "").substring(0, 30);
  const message = { notification: { title, body }, data: { postId: event.params.postId, type: "community" }, topic: "community_topic" };
  try {
    await admin.messaging().send(message);
    await admin.firestore().collection("notifications").add({
      title, body, postId: event.params.postId,
      createdAt: FieldValue.serverTimestamp(),
      type: "community", isRead: false
    });
  } catch (error) {
    console.error("❌ 알림 처리 오류:", error);
  }
});
