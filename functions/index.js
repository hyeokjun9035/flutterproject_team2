/**
 * functions/index.js
 */
const { setGlobalOptions } = require("firebase-functions");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore"); // ✅ 위로
const { onSchedule } = require("firebase-functions/v2/scheduler");       // ✅ 위로
const logger = require("firebase-functions/logger");

const admin = require("firebase-admin");                                 // ✅ 위로
if (admin.apps.length === 0) admin.initializeApp();
const { FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

const axios = require("axios");
const http = require("http");
const https = require("https");
const MID_ZONES = require("./mid_zones.json");

const ax = axios.create({
    timeout: 15000,
    httpAgent: new http.Agent({ keepAlive: true, maxSockets: 10 }),
    httpsAgent: new https.Agent({ keepAlive: true, maxSockets: 10 })
})

setGlobalOptions({ maxInstances: 2 });

/** -----------------------------
 *  공통 유틸
 * ------------------------------ */
 async function fetchEnabledChecklistItems(db) {
   const snap = await db
     .collection("checklist_items")
     .where("enabled", "==", true)
     .get();

   return snap.docs.map(d => ({ id: d.id, ...d.data() }));
 }

 function extractDongName(raw) {
   const s = String(raw ?? "").trim();
   if (!s) return "";

   // 공백/구두점 정리
   const cleaned = s.replace(/[,\(\)\[\]]/g, " ").replace(/\s+/g, " ").trim();
   const tokens = cleaned.split(" ").filter(Boolean);

   // 뒤에서부터 '동/읍/면/리/가' 로 끝나는 토큰 찾기
   for (let i = tokens.length - 1; i >= 0; i--) {
     const t = tokens[i];
     if (/(동|읍|면|리|가)$/.test(t)) return t;
   }

   // 혹시 "부평구부평동" 같이 붙어오면 분리 시도
   const glued = cleaned.replace(/\s+/g, "");
   const m = glued.match(/([가-힣0-9]+(동|읍|면|리|가))$/);
   if (m) return m[1];

   return "";
 }

 function pickNotificationDongName(userData) {
   // 후보(네가 이미 쓰던 필드들 + 동 후보가 있을 법한 순서)
   const candidates = [
     userData?.locationName,
     userData?.addressName,
     userData?.addr,
     userData?.address,
   ];

   for (const c of candidates) {
     const dong = extractDongName(c);
     if (dong) return dong;
   }

   // 마지막 fallback: '행정구역' 기반으로라도 "동네"로
   // (절대 "내 위치"는 쓰지 않기)
   return "우리 동네";
 }

 function matchesChecklistRule(item, ctx) {
   const rules = item?.rules || {};

   const pty = ctx.pty;     // number
   const pop = ctx.pop;     // number (0~100)
   const temp = ctx.temp;   // number
   const pm25 = ctx.pm25;   // number

   if (Array.isArray(rules.ptyIn)) {
     const set = rules.ptyIn.map(Number);
     if (pty == null || !set.includes(Number(pty))) return false;
   }

   if (Array.isArray(rules.ptyNotIn)) {
     const set = rules.ptyNotIn.map(Number);
     if (pty != null && set.includes(Number(pty))) return false;
   }

   if (rules.popMin != null) {
     if (pop == null || Number(pop) < Number(rules.popMin)) return false;
   }

   if (rules.tempMin != null) {
     if (temp == null || Number(temp) < Number(rules.tempMin)) return false;
   }
   if (rules.tempMax != null) {
     if (temp == null || Number(temp) > Number(rules.tempMax)) return false;
   }

   if (rules.pm25Min != null) {
     if (pm25 == null || Number(pm25) < Number(rules.pm25Min)) return false;
   }
   if (rules.pm25Max != null) {
     if (pm25 == null || Number(pm25) > Number(rules.pm25Max)) return false;
   }

   return true;
 }

 function buildChecklistText(items, maxLines = 3) {
   const top = items.slice(0, maxLines);
   if (top.length === 0) return "";
   return "\n\n" + top.map(it => `• ${it.title}`).join("\n");
   // 메시지까지 넣고 싶으면:
   // return "\n\n" + top.map(it => `• ${it.title}: ${it.message}`).join("\n");
 }

function toNum(v) {
  if (v === undefined || v === null) return null;
  const s = String(v).trim();
  if (s === '' || s === '-' ) return null;
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}
function pad2(n) { return String(n).padStart(2, "0"); }

// ⏰ KST 기준 현재 시각 → "HH:mm"
function getHHmmKst() {
  const now = new Date();
  const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);

  const hh = String(kst.getUTCHours()).padStart(2, "0");
  const mm = String(kst.getUTCMinutes()).padStart(2, "0");

  return `${hh}:${mm}`;
}

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

async function buildDashboardData({ lat, lon, locationName = "", addr = "", administrativeArea = "" }) {
  const { nx, ny } = latLonToGrid(lat, lon);

  const kmaNcst = await callKmaUltraNcst(nx, ny);
  const kmaUltra = await callKmaUltraFcst(nx, ny);
  const kmaVilage = await callKmaVilageFcst(nx, ny);

  const ncstItems = Array.isArray(kmaNcst?.items) ? kmaNcst.items : [];
  const ultraItems = Array.isArray(kmaUltra?.items) ? kmaUltra.items : [];
  const vilageItems = Array.isArray(kmaVilage?.items) ? kmaVilage.items : [];

  const hourlyFcst = mergeHourly(
    buildHourlyUltraRaw(ultraItems),
    buildHourlyFromVilage(vilageItems),
    24
  );

  const weeklyShort = buildDailyFromVilage(vilageItems);
  const baseYmd = weeklyShort[0]?.date ?? ymdKst(new Date());

  const tmFc = midTmFc(new Date());
  const landRegId = regIdLandFromAdmin(administrativeArea, String(locationName ?? ""), lon);
  const taRegId = resolveRegIdTa({ administrativeArea, locationName, addr });

  const midLandP = landRegId ? safe(callMidLand(landRegId, tmFc), null, "midLand") : Promise.resolve(null);
  const midTaP   = taRegId   ? safe(callMidTa(taRegId, tmFc), null, "midTa")       : Promise.resolve(null);

  const airP = safe(
    buildAir(addr, administrativeArea),
    { air: { gradeText: "정보없음", pm10: null, pm25: null }, meta: { reason: "air_failed" } },
    "air"
  );

  const alertsP = safe((async () => {
    const todayYmd = ymdKst(new Date());
    const fromYmd = addDaysYmd(todayYmd, -3);

    const wrnItems = await callKmaWthrWrnList({
      fromTmFc: fromYmd,
      toTmFc: todayYmd,
    });

    const keywords = buildAlertKeywords(administrativeArea, addr);
    const alerts = buildAlertsFromWrnList(wrnItems, { keywords });

    if (!alerts || alerts.length === 0) {
      return buildAlertsFromWrnList(wrnItems, { keywords: [] }).slice(0, 1);
    }
    return alerts;
  })(), [], "alerts");

  const [midLand, midTa, airRes, alerts] = await Promise.all([midLandP, midTaP, airP, alertsP]);

  const weekly = (midLand || midTa)
    ? appendMidToWeekly(weeklyShort, midLand, midTa, baseYmd)
    : weeklyShort;

  return {
    nx, ny,
    weatherNow: ncstItems,
    hourlyFcst,
    weekly,
    alerts,
    air: airRes.air,
  };
}

function getUserLatLon(u) {
  const lat = u?.lastLocation?.latitude ?? u?.latitude ?? u?.lat;
  const lon = u?.lastLocation?.longitude ?? u?.longitude ?? u?.lon;
  const nLat = typeof lat === "string" ? parseFloat(lat) : lat;
  const nLon = typeof lon === "string" ? parseFloat(lon) : lon;
  if (!Number.isFinite(nLat) || !Number.isFinite(nLon)) return null;
  return { lat: nLat, lon: nLon };
}

function mapByCategory(items) {
  const m = {};
  for (const it of (items ?? [])) {
    if (it?.category) m[it.category] = it.fcstValue;
  }
  return m;
}

function ptyToText(pty) {
  const v = Number(pty);
  if (!Number.isFinite(v)) return null;
  if (v === 0) return "없음";
  if (v === 1) return "비";
  if (v === 2) return "비/눈";
  if (v === 3) return "눈";
  if (v === 4) return "소나기";
  if (v === 5) return "빗방울";
  if (v === 6) return "빗방울/눈날림";
  if (v === 7) return "눈날림";
  return "강수";
}

function skyToText(sky) {
  const v = Number(sky);
  if (!Number.isFinite(v)) return null;
  if (v === 1) return "맑음";
  if (v === 3) return "구름많음";
  if (v === 4) return "흐림";
  return null;
}

// POP 최대값 뽑기 (null 무시 + fallback)
function maxPopFromHourly(hourly, hours = 12) {
  const arr = Array.isArray(hourly) ? hourly : [];
  let max = null;
  for (const h of arr.slice(0, hours)) {
    const p = toNum(h?.pop);
    if (p == null) continue;
    max = (max == null) ? p : Math.max(max, p);
  }
  return max;
}

function buildWeatherAlarmMessage(dashboard, fallbackLocName = "", checklistText = "") {
  const nowMap = mapByCategory(dashboard?.weatherNow);

  // 초단기실황(현재)
  const t1h = toNum(nowMap.T1H);
  const reh = toNum(nowMap.REH);     // 습도
  const wsd = toNum(nowMap.WSD);     // 풍속
  const ptyNow = toNum(nowMap.PTY);  // 현재 강수형태
  const rn1 = toNum(nowMap.RN1);     // 1시간 강수량

  // 시간대별(초단기+단기 merge)
  const hourly = Array.isArray(dashboard?.hourlyFcst) ? dashboard.hourlyFcst : [];

  // NOW 근처(첫 1~2개)에서 SKY/PTY를 보조로 가져오기
  const h0 = hourly[0] || {};
  const skyNow = toNum(h0.sky);
  const ptyNow2 = toNum(h0.pty);

  // 강수확률: next 6에서 null 무시 -> 없으면 next 12로 fallback
  let maxPop = maxPopFromHourly(hourly, 6);
  if (maxPop == null) maxPop = maxPopFromHourly(hourly, 12);

  // 오늘 최저/최고(weekly[0])
  const today = Array.isArray(dashboard?.weekly) ? dashboard.weekly[0] : null;
  const tMin = toNum(today?.min);
  const tMax = toNum(today?.max);

  const alertTitle = (dashboard?.alerts?.[0]?.title) ? String(dashboard.alerts[0].title) : null;
  const locName =
    String(fallbackLocName ?? "").trim() ||
    "우리 동네";

  const loc = `${locName} `;

  // 상태 텍스트
  const ptyText = ptyToText(ptyNow ?? ptyNow2);
  const skyText = skyToText(skyNow);
  const condition = (ptyNow != null && ptyNow > 0)
    ? (ptyText ?? "강수")
    : (skyText ?? "날씨");

  // ✅ title을 “지역 + 현재온도 + 상태”로(알림 리스트에서 바로 보이게)
  const tempNow = (t1h != null) ? t1h : toNum(h0.temp);
  const titleTemp = (tempNow != null) ? `${tempNow}°` : "현재";
  const title = `${loc}${titleTemp} ${condition}`.trim() || "날씨 알림";

  // ✅ body를 여러 줄로(확장하면 다 보임)
  const lines = [];

  // 1) 현재 한 줄 요약
  const nowParts = [];
  // ✅ checklistText를 한 줄로 압축해서 추가
  if (checklistText) {
    const oneLine = checklistText
      .replace(/\n/g, " ")       // 줄바꿈 제거
      .replace(/•\s/g, "")       // 불릿 제거
      .replace(/\s+/g, " ")
      .trim();
    // 너무 길면 더 잘리니까 적당히 컷
    nowParts.push(`${oneLine}`.slice(0, 70));
  }
  if (tMin != null && tMax != null) nowParts.push(`오늘 ${tMin}~${tMax}°`);
  if (maxPop != null) nowParts.push(`강수확률 ${maxPop}%`);
  lines.push(nowParts.join(" · "));
  if (alertTitle) lines.push(`⚠️ ${alertTitle}`);

  // 2) 강수 관련 디테일(있을 때만)
  const hasNowPrecip = (ptyNow != null && ptyNow > 0);
  if (hasNowPrecip) {
    const extra = [];
    extra.push(`지금 ${ptyText ?? "강수"} 중`);
    if (rn1 != null && rn1 > 0) extra.push(`1시간 ${rn1}mm`);
    lines.push(extra.join(" · "));
  } else {
    // 다음 강수 시점(있으면)
    const nextPrecip = hourly.slice(0, 12).find(h => (toNum(h?.pty) != null && toNum(h.pty) > 0));
    if (nextPrecip) {
      lines.push(`${nextPrecip.timeLabel ?? "곧"} ${ptyToText(nextPrecip.pty) ?? "강수"} 가능`);
    }
  }

  const body = lines.filter(Boolean).join("\n");
  return { title, body, maxPop, t1h, pty: (ptyNow ?? ptyNow2) };
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

  // KMA는 header.resultCode/resultMsg가 핵심인 경우 많음
  const header = e?.response?.data?.response?.header;
  const resultCode = header?.resultCode ? String(header.resultCode) : null;
  const resultMsg = header?.resultMsg ? String(header.resultMsg) : null;

  const retryAfter = e?.response?.headers?.['retry-after'] ?? null;

  // body가 너무 길면 잘라서
  const rawMsg = resultMsg || e?.message || '';
  const msg = String(rawMsg).slice(0, 160);

  return { status, method, url, resultCode, retryAfter, msg };
}

// 메모리 캐시 + 동시요청 합치기
const _mem = new Map();      // key -> { exp, value }
const _inflight = new Map(); // key -> Promise

function cacheGetFresh(key) {
  const v = _mem.get(key);
  if (!v) return null;
  if (Date.now() > v.exp) return null;
  return v.value;
}

// 만료됐어도 maxStaleMs 이내면 스테일로 반환
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

      // ✅ 429면 "절대 throw 하지 않음"
      if (status === 429) {
        if (stale) {
          logger.warn(`[cache] ${key} 429 -> stale fallback`, summarizeErr(e));
          return stale;
        }
        logger.warn(`[cache] ${key} 429 -> empty fallback`, summarizeErr(e));
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
  // ✅ 429 + 4xx는 재시도 금지
  if (s === 429) return false;
  if (s && s >= 400 && s < 500) return false;
  return true; // 네트워크/5xx만 재시도
}

async function axGetWithRetry(tag, url, params, { max = 2 } = {}) {
  let lastErr;
  for (let i = 0; i <= max; i++) {
    try {
      return await ax.get(url, { params, timeout: 8000 });
    } catch (e) {
      lastErr = e;
      const status = e?.response?.status;

      // ✅ 429는 “즉시 종료” (재시도하면 더 막힘)
      if (status === 429) {
        logger.warn(`${tag} failed (429) - no retry`, summarizeErr(e));
        throw e;
      }

      if (!isRetryable(e) || i === max) {
        throw e;
      }

      // ✅ 네트워크/5xx만 백오프 재시도
      const wait = Math.min(800 * (2 ** i) + Math.floor(Math.random() * 300), 8000);
      logger.warn(`${tag} failed (${status ?? "no-status"}), retrying after ${wait}ms...`, summarizeErr(e));
      await sleep(wait);
    }
  }
  throw lastErr;
}

let _kmaChain = Promise.resolve();
let _lastKmaAt = 0;

function withKmaLock(fn) {
  const p = _kmaChain.then(async () => {
    const gap = 1000; // 1초 간격
    const wait = Math.max(0, gap - (Date.now() - _lastKmaAt));
    if (wait) await sleep(wait);
    _lastKmaAt = Date.now();
    return fn();
  }, async () => {
    // 실패해도 체인 유지
    const gap = 1000;
    const wait = Math.max(0, gap - (Date.now() - _lastKmaAt));
    if (wait) await sleep(wait);
    _lastKmaAt = Date.now();
    return fn();
  });

  _kmaChain = p.catch(() => {});
  return p;
}

/** -----------------------------
 *  (1) 위경도 -> 기상청 격자(nx, ny) (LCC)
 * ------------------------------ */
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

/** -----------------------------
 *  (2) 기상청: 초단기실황 base_date/base_time
 *  - mm<40이면 1시간 전
 * ------------------------------ */
function kmaNcstBase(dt) {
  const d = new Date(dt);
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  let hh = kst.getUTCHours();
  const mm = kst.getUTCMinutes();
  if (mm < 40) hh -= 1;
  if (hh < 0) {
    hh = 23;
    kst.setUTCDate(kst.getUTCDate() - 1);
  }
  const y = kst.getUTCFullYear();
  const m = pad2(kst.getUTCMonth() + 1);
  const day = pad2(kst.getUTCDate());
  return { base_date: `${y}${m}${day}`, base_time: `${pad2(hh)}00` };
}

/** -----------------------------
 *  (3) 기상청: 초단기예보 base_date/base_time
 *  - 보통 30분 발표, mm<45면 1시간 전 회차로
 * ------------------------------ */
function kmaUltraFcstBase(dt) {
  const d = new Date(dt);
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  let hh = kst.getUTCHours();
  const mm = kst.getUTCMinutes();
  if (mm < 45) hh -= 1;
  if (hh < 0) {
    hh = 23;
    kst.setUTCDate(kst.getUTCDate() - 1);
  }
  const y = kst.getUTCFullYear();
  const m = pad2(kst.getUTCMonth() + 1);
  const day = pad2(kst.getUTCDate());
  return { base_date: `${y}${m}${day}`, base_time: `${pad2(hh)}30` };
}

/** -----------------------------
 *  (4) 기상청: 단기예보 base_date/base_time
 *  - 02/05/08/11/14/17/20/23 중 최신 회차
 * ------------------------------ */
function kmaVilageBase(dt) {
  const d = new Date(dt);
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  const hh = kst.getUTCHours();
  const mm = kst.getUTCMinutes();

  const baseHours = [23, 20, 17, 14, 11, 8, 5, 2];
  let baseH = baseHours.find(h => hh > h || (hh === h && mm >= 10));

  if (baseH == null) {
    baseH = 23;
    kst.setUTCDate(kst.getUTCDate() - 1);
  }

  const y = kst.getUTCFullYear();
  const m = pad2(kst.getUTCMonth() + 1);
  const day = pad2(kst.getUTCDate());
  return { base_date: `${y}${m}${day}`, base_time: `${pad2(baseH)}00` };
}

/** -----------------------------
 *  기상청 호출들
 * ------------------------------ */
async function callKmaUltraNcst(nx, ny) {
  const { base_date, base_time } = kmaNcstBase(new Date());
  const url = "http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst";
  const params = {
    ServiceKey: process.env.KMA_SERVICE_KEY,
    pageNo: 1,
    numOfRows: 1000,
    dataType: "JSON",
    base_date,
    base_time,
    nx,
    ny,
  };
  const key = `kmaNcst:${nx}:${ny}:${base_date}:${base_time}`;

  return cached(key, 2 * 60 * 1000, async () => {
    const res = await withKmaLock(() => axGetWithRetry("kmaNcst", url, params, { max: 3 }));
    return { items: res.data?.response?.body?.items?.item ?? [], base_date, base_time };
  });
}

async function callKmaUltraFcst(nx, ny) {
  const { base_date, base_time } = kmaUltraFcstBase(new Date());
  const url = "http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtFcst";
  const params = {
    ServiceKey: process.env.KMA_SERVICE_KEY,
    pageNo: 1,
    numOfRows: 1000,
    dataType: "JSON",
    base_date,
    base_time,
    nx,
    ny,
  };

  const key = `kmaUltra:${nx}:${ny}:${base_date}:${base_time}`;

  return cached(key, 3 * 60 * 1000, async () => {
    const res = await withKmaLock(() => axGetWithRetry("kmaUltra", url, params, { max: 3 }));
    return { items: res.data?.response?.body?.items?.item ?? [], base_date, base_time };
  });
}

async function callKmaVilageFcst(nx, ny) {
  const { base_date, base_time } = kmaVilageBase(new Date());
  const url = "http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst";
  const params = {
    ServiceKey: process.env.KMA_SERVICE_KEY,
    pageNo: 1,
    numOfRows: 1000,
    dataType: "JSON",
    base_date,
    base_time,
    nx,
    ny,
  };

  const key = `kmaVilage:${nx}:${ny}:${base_date}:${base_time}`;

  // ✅ 단기예보는 TTL을 길게 줘도 체감 문제 거의 없음
  return cached(key, 15 * 60 * 1000, async () => {
    const res = await withKmaLock(() => axGetWithRetry("kmaVilage", url, params, { max: 4 }));
    return { items: res.data?.response?.body?.items?.item ?? [], base_date, base_time };
  });
}

/** -----------------------------
 *  시간대별: 초단기(ultra) + 단기(vilage) 합치기
 * ------------------------------ */
function buildHourlyUltraRaw(items) {
  const byKey = new Map();
  for (const it of items) {
    const key = `${it.fcstDate}${it.fcstTime}`;
    if (!byKey.has(key)) byKey.set(key, { fcstDate: it.fcstDate, fcstTime: it.fcstTime });
    byKey.get(key)[it.category] = it.fcstValue;
  }

  return [...byKey.values()]
    .map((v) => {
      const hh = Number(String(v.fcstTime).slice(0, 2));
      return {
        _k: `${v.fcstDate}${v.fcstTime}`,
        timeLabel: `${hh}시`,
        sky: v.SKY != null ? Number(v.SKY) : null,
        pty: v.PTY != null ? Number(v.PTY) : null,
        pop: v.POP != null ? Number(v.POP) : null,      // ✅ 추가
        temp: v.T1H != null ? Number(v.T1H) : (v.TMP != null ? Number(v.TMP) : null),
      };
    })
    .filter(x => x.temp !== null)
    .sort((a, b) => (a._k < b._k ? -1 : 1));
}

function buildHourlyFromVilage(items) {
  const byKey = new Map();
  for (const it of items) {
    const key = `${it.fcstDate}${it.fcstTime}`;
    if (!byKey.has(key)) byKey.set(key, { fcstDate: it.fcstDate, fcstTime: it.fcstTime });
    byKey.get(key)[it.category] = it.fcstValue;
  }

  return [...byKey.values()]
    .map((v) => {
      const hh = Number(String(v.fcstTime).slice(0, 2));
      return {
        _k: `${v.fcstDate}${v.fcstTime}`,
        timeLabel: `${hh}시`,
        sky: v.SKY != null ? Number(v.SKY) : null,
        pty: v.PTY != null ? Number(v.PTY) : null,
        pop: v.POP != null ? Number(v.POP) : null,      // ✅ 추가
        temp: v.TMP != null ? Number(v.TMP) : null,
      };
    })
    .filter(x => x.temp !== null)
    .sort((a, b) => (a._k < b._k ? -1 : 1));
}

function mergeHourly(ultra, vilage, take = 24) {
  const byKey = new Map();

  const put = (x) => {
    if (!x?._k) return;
    const prev = byKey.get(x._k) || { _k: x._k };
    // 기존 값이 null이면 새 값으로 채우기
    byKey.set(x._k, {
      _k: x._k,
      timeLabel: prev.timeLabel ?? x.timeLabel,
      sky: prev.sky ?? x.sky,
      pty: prev.pty ?? x.pty,
      pop: prev.pop ?? x.pop,
      temp: prev.temp ?? x.temp,
    });
  };

  // ultra 먼저 넣고
  for (const x of (ultra ?? [])) put(x);
  // vilage로 부족한 필드를 채우기
  for (const x of (vilage ?? [])) put(x);

  const out = [...byKey.values()].sort((a, b) => (a._k < b._k ? -1 : 1));
  if (out.length > 0) out[0].timeLabel = "NOW";

  return out.slice(0, take).map(({ _k, ...rest }) => rest);
}

/** -----------------------------
 *  주간(7일): 단기에서 3일 요약 + 중기(나머지) 덧붙이기
 * ------------------------------ */
function buildDailyFromVilage(items) {
  const byDate = new Map();

  for (const it of items) {
    const d = it.fcstDate;
    if (!byDate.has(d)) {
        byDate.set(d, { date: d, min: null, max: null, pop: null, sky12: null, pty: null, tmpMin: null, tmpMax: null });
    }
    const row = byDate.get(d);

    if (it.category === "TMN") row.min = toNum(it.fcstValue);
    if (it.category === "TMX") row.max = toNum(it.fcstValue);

    if (it.category === "TMP") {
      const v = toNum(it.fcstValue);
      if (v != null) {
        row.tmpMin = row.tmpMin == null ? v : Math.min(row.tmpMin, v);
        row.tmpMax = row.tmpMax == null ? v : Math.max(row.tmpMax, v);
      }
    }

    if (it.category === "POP") {
      const v = toNum(it.fcstValue);
      if (v != null) row.pop = row.pop == null ? v : Math.max(row.pop, v);
    }

    if (it.category === "PTY") {
      const v = toNum(it.fcstValue);
      if (v != null) row.pty = row.pty == null ? v : Math.max(row.pty, v);
    }

    if (it.category === "SKY") {
      const v = toNum(it.fcstValue);
      if (it.fcstTime === "1200") row.sky12 = v;
      if (row.sky12 == null) row.sky12 = v;
    }
  }

  for (const row of byDate.values()) {
      if (row.min == null) row.min = row.tmpMin;
      if (row.max == null) row.max = row.tmpMax;
  }

  return [...byDate.values()]
    .sort((a, b) => (a.date < b.date ? -1 : 1))
    .slice(0, 4)
    .map(d => ({
      date: d.date,
      min: d.min,
      max: d.max,
      pop: d.pop,
      sky: d.sky12,
      pty: d.pty,
      wfText: null, // 단기 기반은 sky/pty로 아이콘 가능
    }));
}

// 중기예보는 일 2회(06/18시) 발표라는 설명이 공식 페이지에 있음. :contentReference[oaicite:2]{index=2}
function midTmFc(dt) {
  const d = new Date(dt);
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  const hh = kst.getUTCHours();
  let baseH = hh >= 18 ? 18 : (hh >= 6 ? 6 : 18);
  if (hh < 6) kst.setUTCDate(kst.getUTCDate() - 1);

  const y = kst.getUTCFullYear();
  const m = pad2(kst.getUTCMonth() + 1);
  const day = pad2(kst.getUTCDate());
  return `${y}${m}${day}${pad2(baseH)}00`;
}

// regId 대표 코드(예: 11B00000 수도권, 11H20000 경남권 등) 목록 예시는 아래처럼 널리 쓰임. :contentReference[oaicite:3]{index=3}
function regIdLandFromAdmin(administrativeArea, locationName = "", lon = null) {
  const s = String(administrativeArea ?? "").replace(/\s/g, "");

  if (s.includes("서울") || s.includes("인천") || s.includes("경기")) return "11B00000";
  if (s.includes("충청")) return "11C00000";
  if (s.includes("전라")) return "11F00000";
  if (s.includes("경상") || s.includes("부산") || s.includes("대구") || s.includes("울산")) return "11H00000";
  if (s.includes("제주")) return "11G00000";

  if (s.includes("강원")) {
    const t = String(locationName ?? "").replace(/\s/g, "");
    const east = ["속초","고성","양양","강릉","동해","삼척","태백","대관령"];
    const isEast = east.some(k => t.includes(k)) || (typeof lon === "number" && lon >= 128.0);
    return isEast ? "11D20000" : "11D10000";
  }

  return null;
}

/** -----------------------------
 *  mid_zones.json 인덱스(메모리)
 * ------------------------------ */
const _MID = (() => {
  const zones = Array.isArray(MID_ZONES) ? MID_ZONES : [];
  const A = zones.filter(z => z?.regSp === "A"); // (필요하면 later) 육상예보용
  const C = zones.filter(z => z?.regSp === "C"); // ✅ 중기기온(getMidTa)용

  // normalize: 공백/점/특수문자 제거, 행정 접미(시/군/구 등) 제거 버전도 같이 만들기
  const norm = (s) => String(s ?? "")
    .trim()
    .replace(/\s+/g, "")
    .replace(/[·\.\(\)\[\],]/g, "");

  const stripSuffix = (s) => norm(s)
    .replace(/(특별자치도|특별자치시|광역시|특별시|자치시|자치도)$/g, "")
    .replace(/(도|시|군|구)$/g, ""); // 예: 속초시 -> 속초

  // C 구역명 -> regId (동명이인 대비로 prefix 필터링을 같이 씀)
  const C_LIST = C.map(z => ({
    regId: String(z.regId),
    name: String(z.regName),
    n0: norm(z.regName),
    n1: stripSuffix(z.regName),
  }));

  // 긴 이름 우선(부분매칭 충돌 방지)
  C_LIST.sort((a, b) => (b.n0.length - a.n0.length));

  return { A, C_LIST, norm, stripSuffix };
})();

function guessPrefixForAdmin(administrativeArea) {
  const s = String(administrativeArea ?? "").replace(/\s+/g, "");
  if (s.includes("서울") || s.includes("인천") || s.includes("경기")) return "11B"; // 수도권
  if (s.includes("강원")) return "11D";
  if (s.includes("충북") || s.includes("충청북")) return "11C";
  if (s.includes("충남") || s.includes("충청남") || s.includes("대전") || s.includes("세종")) return "11C";
  if (s.includes("전북") || s.includes("전라북")) return "11F";
  if (s.includes("전남") || s.includes("전라남") || s.includes("광주")) return "11F";
  if (s.includes("경북") || s.includes("경상북") || s.includes("대구")) return "11H";
  if (s.includes("경남") || s.includes("경상남") || s.includes("부산") || s.includes("울산")) return "11H";
  if (s.includes("제주")) return "11G";
  return null;
}

/**
 * ✅ getMidTa용 regId 자동 선택
 * - locationName / addr / administrativeArea 에서 "속초/강릉/부산..." 같은 토큰을 찾아
 * - mid_zones.json(C)에서 매칭되는 regId를 리턴
 */
function resolveRegIdTa({ administrativeArea, locationName, addr }) {
  const prefix = guessPrefixForAdmin(administrativeArea); // 예: 강원 -> 11D
  const hay = _MID.stripSuffix(`${locationName ?? ""} ${addr ?? ""} ${administrativeArea ?? ""}`);

  // 1) 같은 prefix(지역권) 내에서 구역명 매칭
  for (const z of _MID.C_LIST) {
    if (prefix && !z.regId.startsWith(prefix)) continue;

    // 구역명이 "속초"인데 텍스트가 "속초시"여도 stripSuffix로 맞아짐
    if (z.n0 && hay.includes(z.n0)) return z.regId;
    if (z.n1 && hay.includes(z.n1)) return z.regId;
  }

  // 2) fallback(대표도시) — 최소 커버용
  // (여기 값은 mid_zones.json에 있는 도시로 골라야 함)
  if (prefix === "11D") return "11D10301"; // 춘천(강원) fallback
  if (prefix === "11B") return "11B10101"; // 서울 fallback
  if (prefix === "11C") return "11C10301"; // 청주 fallback
  if (prefix === "11F") return "11F20501"; // 광주 fallback(전라권)
  if (prefix === "11H") return "11H10701"; // 대구 fallback(경상권)
  if (prefix === "11G") return "11G00201"; // 제주 fallback

  return null;
}

async function callMidLand(regId, tmFc) {
  const url = "http://apis.data.go.kr/1360000/MidFcstInfoService/getMidLandFcst";
  const params = {
    ServiceKey: process.env.KMA_SERVICE_KEY,
    pageNo: 1,
    numOfRows: 10,
    dataType: "JSON",
    regId,
    tmFc,
  };
  const res = await ax.get(url, { params });
  return res.data?.response?.body?.items?.item?.[0] ?? null;
}

async function callMidTa(regId, tmFc) {
  const url = "http://apis.data.go.kr/1360000/MidFcstInfoService/getMidTa";
  const params = {
    ServiceKey: process.env.KMA_SERVICE_KEY,
    pageNo: 1,
    numOfRows: 10,
    dataType: "JSON",
    regId,
    tmFc,
  };
  const res = await ax.get(url, { params });
  return res.data?.response?.body?.items?.item?.[0] ?? null;
}

function pickMax(a, b) {
  const na = toNum(a);
  const nb = toNum(b);
  if (na == null) return nb;
  if (nb == null) return na;
  return Math.max(na, nb);
}

function ymdKst(dt) {
  const d = new Date(dt);
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  const y = kst.getUTCFullYear();
  const m = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const day = String(kst.getUTCDate()).padStart(2, "0");
  return `${y}${m}${day}`;
}

function parseYmd(ymd) {
  const y = Number(ymd.slice(0,4));
  const m = Number(ymd.slice(4,6));
  const d = Number(ymd.slice(6,8));
  // UTC로 고정 (일수 차이 계산 안정)
  return new Date(Date.UTC(y, m - 1, d));
}

function diffDaysYmd(aYmd, bYmd) {
  const a = parseYmd(aYmd);
  const b = parseYmd(bYmd);
  return Math.round((a - b) / (24 * 60 * 60 * 1000)); // a - b (일)
}

function appendMidToWeekly(shortList, midLand, midTa, baseYmd) {
  const out = [...shortList];

  const startOff = out.length >= 4 ? 4 : 3;

  for (let off = startOff; off <= 7; off++) {

    out.push({
      date: addDaysYmd(baseYmd, off),
      min: toNum(midTa?.[`taMin${off}`]),
      max: toNum(midTa?.[`taMax${off}`]),
      wfAm: midLand?.[`wf${off}Am`] ?? null,
      wfPm: midLand?.[`wf${off}Pm`] ?? null,
      popAm: midLand?.[`rnSt${off}Am`] != null ? toNum(midLand[`rnSt${off}Am`]) : null,
      popPm: midLand?.[`rnSt${off}Pm`] != null ? toNum(midLand[`rnSt${off}Pm`]) : null,
      // 기존 유지
      wfText: midLand?.[`wf${off}Pm`] ?? null,
      pop: midLand?.[`rnSt${off}Pm`] != null ? toNum(midLand[`rnSt${off}Pm`]) : null,
    });
  }

  return out.slice(0, 7);
}

/** -----------------------------
 *  에어코리아(지금 네 로직 유지)
 * ------------------------------ */
function gradeTextFromKhai(grade) {
  const g = String(grade ?? "");
  if (g === "1") return "좋음";
  if (g === "2") return "보통";
  if (g === "3") return "나쁨";
  if (g === "4") return "매우나쁨";
  return "정보없음";
}

async function callAirMsrstnListByAddr(addr) {
  const url = "http://apis.data.go.kr/B552584/MsrstnInfoInqireSvc/getMsrstnList";
  const params = {
    serviceKey: process.env.AIRKOREA_SERVICE_KEY, // ⚠️ 소문자
    returnType: "json",
    numOfRows: 10,
    pageNo: 1,
    addr,
  };
  const res = await ax.get(url, { params });
  return res.data?.response?.body?.items ?? [];
}

async function callAirRltmByStation(stationName) {
  const url = "http://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getMsrstnAcctoRltmMesureDnsty";
  const params = {
    serviceKey: process.env.AIRKOREA_SERVICE_KEY,
    returnType: "json",
    numOfRows: 10,
    pageNo: 1,
    stationName,
    dataTerm: "DAILY",
    ver: "1.3",
  };
  const res = await ax.get(url, { params });
  return res.data?.response?.body?.items ?? [];
}

async function buildAir(addr, administrativeArea) {
  // addr 없으면 adminArea라도 시도
  const candidates = [addr, administrativeArea]
    .map(s => String(s ?? "").trim())
    .filter(s => s.length > 0);

  // addr가 "강원특별자치도 속초시" 같은 경우를 대비해 축약 후보도 추가
  const more = [];
  for (const a of candidates) {
    const parts = a.split(/\s+/).filter(Boolean);
    if (parts.length >= 2) more.push(parts.slice(0, 2).join(" ")); // "인천광역시 부평구"
    if (parts.length >= 1) more.push(parts[0]);                    // "인천광역시"
    more.push(a.replace("특별자치도", "도").replace("특별자치시", "시"));
  }
  const uniq = [...new Set([...candidates, ...more])];

  for (const cand of uniq) {
    const stations = await callAirMsrstnListByAddr(cand);
    for (const st of stations) {
      const stationName = st?.stationName;
      if (!stationName) continue;

      const rows = await callAirRltmByStation(stationName);

      // ✅ 10건 중에서 pm10/pm25가 숫자인 첫 행 선택
      const hit = rows.find(r => toNum(r.pm10Value) != null || toNum(r.pm25Value) != null);
      if (!hit) continue;

      const pm10 = toNum(hit.pm10Value);
      const pm25 = toNum(hit.pm25Value);

      // (선택) pm10Grade/pm25Grade가 있으면 분리 등급도 같이 내려줌(Flutter에서 나중에 사용)
      const pm10GradeText = gradeTextFromKhai(hit.pm10Grade ?? hit.pm10Grade1h ?? hit.khaiGrade);
      const pm25GradeText = gradeTextFromKhai(hit.pm25Grade ?? hit.pm25Grade1h ?? hit.khaiGrade);

      const grade = String(hit.khaiGrade ?? "").trim();

      return {
        air: {
          gradeText: gradeTextFromKhai(grade), // 기존 호환
          pm10,
          pm25,
          pm10GradeText,
          pm25GradeText,
        },
        meta: { stationName, dataTime: hit.dataTime ?? null, addrUsed: cand },
      };
    }
  }

  return { air: { gradeText: "정보없음", pm10: null, pm25: null }, meta: { stationName: null, reason: "no_station_or_no_valid_rows" } };
}

/** -----------------------------
 *  (특보) 기상청 기상특보목록 getWthrWrnList
 *  - fromTmFc / toTmFc: YYYYMMDD
 * ------------------------------ */
async function callKmaWthrWrnList({ fromTmFc, toTmFc, stnId }) {
  const url = "http://apis.data.go.kr/1360000/WthrWrnInfoService/getWthrWrnList";
  const params = {
    ServiceKey: process.env.KMA_SERVICE_KEY,
    pageNo: 1,
    numOfRows: 200,      // 넉넉히 받고(범위는 짧게), 서버에서 필터링
    dataType: "JSON",
    fromTmFc,            // YYYYMMDD
    toTmFc,              // YYYYMMDD
  };
  if (stnId) params.stnId = stnId; // 옵션

  const res = await ax.get(url, { params });
  const header = res.data?.response?.header;
  const code = String(header?.resultCode ?? "00");
  const msg = String(header?.resultMsg ?? "");

  // ✅ 핵심: NO_DATA는 정상 상황으로 보고 빈 배열 리턴
  if (code === "03") return [];
  if (code !== "00") throw new Error(`KMA WRN ${code} ${header?.resultMsg ?? ""}`);

  return res.data?.response?.body?.items?.item ?? [];
}

function compactRegion(s) {
  return String(s ?? "")
    .trim()
    .replace(/\s+/g, "")
    .replace(/(특별시|광역시|특별자치시|특별자치도|자치도)$/g, ""); // 끝에 붙는 행정 접미 제거
}

function buildAlertKeywords(administrativeArea, addr) {
  const out = new Set();

  const add = (v) => {
    const raw = String(v ?? "").trim();
    if (!raw) return;
    out.add(raw);
    out.add(compactRegion(raw));
    // “부산광역시” -> “부산” 같은 1단어도 추가
    const first = raw.split(/\s+/)[0];
    if (first) out.add(compactRegion(first));
    const short = raw
      .replace(/특별시|광역시|자치시|자치도|도/g, "")
      .trim();
    if (short) out.add(short);
  };

  add(administrativeArea); // 예: "인천광역시"
  add(addr);               // 예: "인천광역시 부평구"

  // addr 두 번째 토큰(구/군)도 추가: "부평구"
  const parts = String(addr ?? "").split(/\s+/).filter(Boolean);
  if (parts[1]) out.add(parts[1]);

  return [...out].filter(Boolean);
}

function buildAlertsFromWrnList(items, { keywords = [] } = {}) {
  const kw = keywords.map(k => String(k).replace(/\s+/g, "")).filter(Boolean);

  const cleaned = (items ?? [])
    .map(it => ({
      title: String(it.title ?? "특보"),
      region: "",
      timeText: String(it.tmFc ?? ""),
      tmSeq: String(it.tmSeq ?? ""),
      stnId: String(it.stnId ?? ""),
    }))
    .filter(a => !a.title.includes("해제") && !a.title.includes("취소"))
    .sort((a, b) => (a.timeText < b.timeText ? 1 : -1));

  if (cleaned.length === 0) return [];

  // ✅ 1차: 키워드 매칭
  const matched = kw.length
      ? cleaned.filter(a => {
          const t = a.title.replace(/\s+/g, "");
          return kw.some(k => k && t.includes(k));
        })
      : cleaned;

  // ✅ 핵심: 매칭이 0개면 그냥 최신 특보라도 내려줘서 배너가 뜨게
  const finalList = (matched.length > 0) ? matched : cleaned;

  return finalList.slice(0, 5);
}

function guessWthrWrnStnId(administrativeArea) {
  const s = String(administrativeArea ?? "").replace(/\s/g, "");
  if (s.includes("서울")) return "108";
  if (s.includes("인천")) return "112";
  if (s.includes("부산")) return "159";
  if (s.includes("대구")) return "143";
  if (s.includes("대전")) return "133";
  if (s.includes("광주")) return "156";
  if (s.includes("울산")) return "152";
  if (s.includes("제주")) return "184";
  return null;
}

/** -----------------------------
 *  메인: getDashboard
 * ------------------------------ */
exports.getDashboard = onCall({ region: "asia-northeast3" }, async (request) => {
  try {
    const { lat, lon, locationName } = request.data || {};
    if (typeof lat !== "number" || typeof lon !== "number") {
      throw new HttpsError("invalid-argument", "lat/lon is required");
    }

    const { nx, ny } = latLonToGrid(lat, lon);

    const addr = String(request.data?.addr ?? request.data?.locationName ?? "");
    const administrativeArea = String(request.data?.administrativeArea ?? "");

    const kmaNcst = await callKmaUltraNcst(nx, ny);
    const kmaUltra = await callKmaUltraFcst(nx, ny);
    const kmaVilage = await callKmaVilageFcst(nx, ny);

    const ncstItems = Array.isArray(kmaNcst?.items) ? kmaNcst.items : [];
    const ultraItems = Array.isArray(kmaUltra?.items) ? kmaUltra.items : [];
    const vilageItems = Array.isArray(kmaVilage?.items) ? kmaVilage.items : [];

    const hourlyFcst = mergeHourly(
      buildHourlyUltraRaw(ultraItems),
      buildHourlyFromVilage(vilageItems),
      24
    );

    // ✅ 2) 주간(단기 먼저)
    const weeklyShort = buildDailyFromVilage(vilageItems);
    const baseYmd = weeklyShort[0]?.date ?? ymdKst(new Date());

    // ✅ 3) 중기/대기질 병렬
    const tmFc = midTmFc(new Date());
    const tmFcYmd = tmFc.substring(0, 8);

    const landRegId = regIdLandFromAdmin(administrativeArea, String(locationName ?? ""), lon);
    const taRegId = resolveRegIdTa({
      administrativeArea,
      locationName, // request.data.locationName
      addr,         // request.data.addr (또는 locationName)
    });

    const midLandP = landRegId
      ? safe(callMidLand(landRegId, tmFc), null, "midLand")
      : Promise.resolve(null);

    const midTaP = taRegId
      ? safe(callMidTa(taRegId, tmFc), null, "midTa")
      : Promise.resolve(null);

    const airP = safe(
      buildAir(addr, administrativeArea),
      { air: { gradeText: "정보없음", pm10: null, pm25: null }, meta: { reason: "air_failed" } },
      "air"
    );

    // 특보도 safe로 (너는 현재 try/catch로 감싸고 있음):contentReference[oaicite:6]{index=6}
    const alertsP = safe((async () => {
      const todayYmd = ymdKst(new Date());
      const fromYmd = addDaysYmd(todayYmd, -3);

      const wrnItems = await callKmaWthrWrnList({
        fromTmFc: fromYmd,
        toTmFc: todayYmd,
      });

      const keywords = buildAlertKeywords(administrativeArea, addr);

      // ✅ 키워드 매칭 0이면 최신 특보 fallback
      const alerts = buildAlertsFromWrnList(wrnItems, { keywords });

      // 혹시 still empty면 그냥 최신 1개라도
      if (!alerts || alerts.length === 0) {
        return buildAlertsFromWrnList(wrnItems, { keywords: [] }).slice(0, 1);
      }

      return alerts;
    })(), [], "alerts");

    const [midLand, midTa, airRes, alerts] = await Promise.all([midLandP, midTaP, airP, alertsP]);

    // ✅ 4) weekly: mid가 있으면 append, 없으면 short 유지
    const weekly = (midLand || midTa)
      ? appendMidToWeekly(weeklyShort, midLand, midTa, baseYmd)
      : weeklyShort;

    return {
      updatedAt: new Date().toISOString(),
      locationName: String(locationName ?? ""),
      weatherNow: kmaNcst.items,
      hourlyFcst,
      weekly,
      alerts,
      air: airRes.air,
      meta: {
        nx,
        ny,
        addr,
        administrativeArea,
        tmFc,
        landRegId: landRegId ?? null,
        taRegId: taRegId ?? null,
        midLandOk: !!midLand,
        midTaOk: !!midTa,
        kmaNcstBase: { base_date: kmaNcst.base_date, base_time: kmaNcst.base_time },
        kmaUltraBase: { base_date: kmaUltra.base_date, base_time: kmaUltra.base_time },
        kmaVilageBase: { base_date: kmaVilage.base_date, base_time: kmaVilage.base_time },
        air: airRes.meta,
      },
    };
  } catch (e) {
    logger.error("getDashboard failed", summarizeErr(e));
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("internal", `getDashboard failed: ${String(e?.message ?? e)}`);
  }
});

exports.getChecklistForLocation = onCall({ region: "asia-northeast3" }, async (request) => {
  try {
    const { lat, lon, locationName = "", addr = "", administrativeArea = "" } = request.data || {};
    if (typeof lat !== "number" || typeof lon !== "number") {
      throw new HttpsError("invalid-argument", "lat/lon is required");
    }

    const db = admin.firestore();

    const dashboard = await buildDashboardData({ lat, lon, locationName, addr, administrativeArea });

    const nowMap = mapByCategory(dashboard?.weatherNow);
    const temp = toNum(nowMap.T1H);
    const pty  = toNum(nowMap.PTY);
    const pm25 = toNum(dashboard?.air?.pm25);
    const pop  = maxPopFromHourly(dashboard?.hourlyFcst ?? [], 6)
              ?? maxPopFromHourly(dashboard?.hourlyFcst ?? [], 12);

    const ctx = { temp, pty, pop, pm25 };

    const enabled = await fetchEnabledChecklistItems(db);

    const matched = enabled
      .filter(it => matchesChecklistRule(it, ctx))
      .sort((a, b) => (Number(b.priority ?? 0) - Number(a.priority ?? 0)));

    return {
      ctx,
      items: matched.map(it => ({
        id: it.id,
        title: it.title,
        message: it.message ?? null,
        priority: it.priority ?? 0,
        rules: it.rules ?? {},
      })),
    };
  } catch (e) {
    logger.error("getChecklistForLocation failed", summarizeErr(e));
    if (e instanceof HttpsError) throw e;
    throw new HttpsError(
      "internal",
      `getChecklistForLocation failed: ${String(e?.message ?? e)}`
    );
  }
});

function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

//  좋아요/댓글 알림 (notifications 컬렉션 감시)
exports.sendPushNotification = onDocumentCreated({
    document: "notifications/{notificationId}",
    region: "asia-northeast3"
}, async (event) => {
    const snap = event.data;
     if (!snap) return;
     const data = snap.data();
     if (!data) return;

    const receiverUid = data.receiverUid;
    const senderNickName = data.senderNickName || "누군가";
    const type = data.type || "like";
    const postTitle = data.postTitle || "게시글";

    if (!receiverUid || typeof receiverUid !== 'string') {
        console.error("❌ 에러: receiverUid 누락", data);
        return;
    }

    const bodyText = type === "like"
        ? `${senderNickName}님이 '${postTitle}' 글에 좋아요를 눌렀습니다.`
        : `${senderNickName}님이 '${postTitle}' 글에 댓글을 남겼습니다.`;

    try {
        const userDoc = await admin.firestore().collection("users").doc(receiverUid).get();
        const fcmToken = userDoc.data()?.fcmToken;

        if (!fcmToken) {
            console.log(`⚠️ 토큰 없음: ${receiverUid}`);
            return;
        }

        await getMessaging().send({
            notification: { title: "새로운 알림", body: bodyText },
            token: fcmToken,
            data: { postId: data.postId || "", type: type },
        });
        console.log(`✅ 푸시 성공: ${receiverUid}`);
    } catch (error) {
        console.error("❌ 전송 에러:", error);
    }
});

//  새 게시글 위치 기반 알림 (community 컬렉션 감시)
exports.sendPostNotification = onDocumentCreated({ // 이름을 'sendPostNotification'으로 수정!
    document: "community/{postId}", // 감시 대상도 'community'로 수정!
    region: "asia-northeast3"
}, async (event) => {
    const snapshot = event.data;
    if (!snapshot) return null;

    const postData = snapshot.data();
    if (postData.category !== "사건/이슈") return null;

    const place = postData.place;
    if (!place || place.lat === undefined || place.lng === undefined) return null;

    const postLat = Number(place.lat);
    const postLon = Number(place.lng);

    try {
        const usersSnapshot = await admin.firestore().collection('users').get();
        const targetTokens = new Set();

        usersSnapshot.forEach(doc => {
            const userData = doc.data();
            const token = userData.fcmToken;
            if (!token) return;

            const uLat = userData.lastLocation?.latitude || userData.latitude;
            const uLon = userData.lastLocation?.longitude || userData.longitude;

            const userLat = parseFloat(uLat);
            const userLon = parseFloat(uLon);

            if (!isNaN(userLat) && !isNaN(userLon)) {
                const distance = calculateDistance(postLat, postLon, userLat, userLon);
                if (distance <= 10.0) { // 10km 이내
                    targetTokens.add(token);
                }
            }
        });

        if (targetTokens.size > 0) {
            await getMessaging().sendEachForMulticast({
                notification: {
                    title: `주변 사건/이슈 제보`,
                    body: `'${postData.title}' 글이 근처에서 등록되었습니다.`
                },
                tokens: Array.from(targetTokens),
            });
            console.log(`📍 위치 알림 전송: ${targetTokens.size}개 성공`);
        }
    } catch (error) {
        console.error("❌ 위치 알림 에러:", error);
    }
});



/** -----------------------------
 *  2. 관리자 알림 발송 (Alarm 전용)
 * ------------------------------ */
exports.sendAdminNotification = onCall({ region: "asia-northeast3" }, async (request) => {
  const { title, body, topic } = request.data || {};

  if (!title || !body) {
    throw new HttpsError("invalid-argument", "제목과 내용을 모두 입력해주세요.");
  }

  try {
    // 1. FCM 발송
    await admin.messaging().send({
      notification: { title, body },
        //  관리자 알림 아이콘 설정을 위해 이 부분을 추가 jgh260106----s
        android: {
          notification: {
            icon: 'ic_notification', // 안드로이드 리소스 폴더에 저장할 이미지 파일명 (확장자 제외)
            color: '#000000',       // 아이콘 배경색 (선택사항)
          },
        },
        //  관리자 알림 아이콘 설정을 위해 이 부분을 추가 jgh260106----E
      data: {
        type: "admin_alarm",
        click_action: "FLUTTER_NOTIFICATION_CLICK"
      },
      topic: topic || "community_topic",
    });

    // 2. 발송 기록 저장 (이 부분이 성공해야 앱 하단 리스트에 나타납니다)
    await admin.firestore().collection("notifications").add({
      title: title,
      body: body,
      type: "admin_alarm",
      createdAt: FieldValue.serverTimestamp(), // ✅ 수정 완료
      isRead: false
    });

    return { success: true };
  } catch (e) {
    logger.error("sendAdminNotification failed", e);
    throw new HttpsError("internal", `발송 실패: ${e.message}`);
  }
});

exports.sendDailyAlarm = onSchedule(
  { schedule: "every day 10:09", timeZone: "Asia/Seoul", region: "asia-northeast3" },
  async () => {
    const db = admin.firestore();

    const currentTime = getHHmmKst();

    const now = new Date();
    const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
    const yyyy = kst.getUTCFullYear();
    const mm = String(kst.getUTCMonth() + 1).padStart(2, "0");
    const dd = String(kst.getUTCDate()).padStart(2, "0");
    const sentKey = `${yyyy}-${mm}-${dd} ${currentTime}`;

    // ✅ 0) 스케줄러가 도는지 확인하는 "시작 로그"
    logger.info("[weather-alarm] start", {
      nowKst: `${yyyy}-${mm}-${dd} ${currentTime}`,
      sentKey,
      region: "asia-northeast3",
    });

    const lockRef = db.collection("alarmLocks").doc(sentKey);
    try {
      await lockRef.create({ createdAt: FieldValue.serverTimestamp() });
      logger.info("[weather-alarm] lock acquired", { sentKey });
    } catch (e) {
      // 이미 있으면(=이미 누가 실행함) 그냥 종료
      logger.warn("[weather-alarm] lock exists -> skip", {
        sentKey,
        code: e?.code ?? null,
        msg: e?.message ?? String(e),
      });
      if (e.code === 6 || e.code === "already-exists") return;
      throw e;
    }

    // 대상 유저 조회
    const snap = await db.collection("users")
      .where("isAlramChecked", "==", true)
      .where("alarmTime", "==", currentTime)
      .get();

    logger.info("[weather-alarm] target query result", {
      sentKey,
      targetUserCount: snap.size,
      empty: snap.empty,
    });

    if (snap.empty) return;

    const usersSnapshot = await admin.firestore().collection("users").get();

    let totalUsers = 0;
    let tokenUsers = 0;
    const tokenMap = new Map(); // token -> [uid...]
    usersSnapshot.forEach(doc => {
      totalUsers++;
      const t = doc.data()?.fcmToken;
      if (!t) return;
      tokenUsers++;
      if (!tokenMap.has(t)) tokenMap.set(t, []);
      tokenMap.get(t).push(doc.id);
    });

    logger.info("[weather-alarm] token stats", {
      sentKey,
      totalUsers,
      tokenUsers,
      uniqueTokens: tokenMap.size,
    });

    const groupsByGrid = new Map();

    // ✅ 카운터들로 "왜 빠졌는지" 파악
    let skippedNoToken = 0;
    let skippedAlreadySent = 0;
    let skippedNoLatLon = 0;

    for (const doc of snap.docs) {
      const u = doc.data() || {};
      const token = u.fcmToken;
      if (!token) { skippedNoToken++; continue; }

      if (u.lastAlarmSentKey && String(u.lastAlarmSentKey) === sentKey) {
        skippedAlreadySent++;
        continue;
      }

      const ll = getUserLatLon(u);
      if (!ll) { skippedNoLatLon++; continue; }

      const { nx, ny } = latLonToGrid(ll.lat, ll.lon);
      const gk = `${nx},${ny}`;
      if (!groupsByGrid.has(gk)) groupsByGrid.set(gk, []);
      groupsByGrid.get(gk).push({
        ref: doc.ref,
        token,
        userData: u,
        nx,
        ny,
        lat: ll.lat,
        lon: ll.lon,
      });
    }

    logger.info("[weather-alarm] grouping summary", {
      sentKey,
      gridCount: groupsByGrid.size,
      skippedNoToken,
      skippedAlreadySent,
      skippedNoLatLon,
    });

    if (groupsByGrid.size === 0) return;

    const byMessage = new Map();
    const enabledChecklist = await fetchEnabledChecklistItems(db);

    logger.info("[weather-alarm] checklist loaded", {
      sentKey,
      enabledChecklistCount: enabledChecklist.length,
    });

    for (const [gk, entries] of groupsByGrid.entries()) {
      const first = entries[0];

      // ✅ 알림에는 "동(읍/면/리/가)"만 노출 + "내 위치" 금지
      const locationName = pickNotificationDongName(first.userData);

      const addr = String(first.userData?.addr ?? first.userData?.address ?? "");
      const administrativeArea = String(first.userData?.administrativeArea ?? first.userData?.adminArea ?? "");

      const dashboard = await safe(
        buildDashboardData({ lat: first.lat, lon: first.lon, locationName, addr, administrativeArea }),
        null,
        `weatherDashboard:${gk}`
      );

      if (!dashboard) {
        logger.warn("[weather-alarm] dashboard build failed -> skip grid", { sentKey, gk });
        continue;
      }

      const nowMap = mapByCategory(dashboard?.weatherNow);
      const temp = toNum(nowMap.T1H);
      const pty  = toNum(nowMap.PTY);
      const pm25 = toNum(dashboard?.air?.pm25);

      const pop = maxPopFromHourly(dashboard?.hourlyFcst ?? [], 6)
               ?? maxPopFromHourly(dashboard?.hourlyFcst ?? [], 12);

      const ctx = { temp, pty, pop, pm25 };

      let matched = enabledChecklist
        .filter(it => matchesChecklistRule(it, ctx))
        .sort((a, b) => (Number(b.priority ?? 0) - Number(a.priority ?? 0)));

      if (!matched.length) {
        matched = enabledChecklist
          .filter(it => it?.rules?.always === true)
          .sort((a,b) => Number(b.priority ?? 0) - Number(a.priority ?? 0))
          .slice(0, 3);
      }

      const checklistText = buildChecklistText(matched, 3);

      // ✅ msg는 여기서 딱 1번만
      const msg = buildWeatherAlarmMessage(dashboard, locationName, checklistText);

      // ✅ checklistText를 msg.body에 “추가로” 붙이지 말고(중복됨)
      // msg 안에서 이미 checklistText를 nowParts에 넣고 있음.
      // 그래도 body에 별도 섹션으로도 넣고 싶으면 아래처럼(원하면 유지)
      // ✅ checklistText는 buildWeatherAlarmMessage 내부에서 이미 반영됨(중복 방지)
      const body2 = msg.body;

      const mk = `${msg.title}||${body2}`;

      if (!byMessage.has(mk)) byMessage.set(mk, { title: msg.title, body: body2, entries: [] });

      const bucket = byMessage.get(mk);
      for (const e of entries) bucket.entries.push({ ref: e.ref, token: e.token });

    }

    logger.info("[weather-alarm] message buckets ready", {
      sentKey,
      bucketCount: byMessage.size,
      totalReceivers: [...byMessage.values()].reduce((acc, b) => acc + b.entries.length, 0),
    });

    if (byMessage.size === 0) return;

    for (const { title, body, entries } of byMessage.values()) {
      const chunkSize = 500;
      for (let i = 0; i < entries.length; i += chunkSize) {
        const chunk = entries.slice(i, i + chunkSize);
        const tokens = chunk.map(x => x.token);

        const res = await getMessaging().sendEachForMulticast({
          notification: { title, body },
          data: { type: "weather_alarm", sentKey },
          tokens,
        });

        const ok = res.responses.filter(r => r.success).length;
        const fail = res.responses.length - ok;

        logger.info("[weather-alarm] multicast result", {
          sentKey,
          tokens: tokens.length,
          ok,
          fail,
          titlePreview: String(title).slice(0, 40),
        });

        // (선택) 실패 사유 상위 몇 개만 찍기
        const topFail = [];
        for (let j = 0; j < res.responses.length; j++) {
          const r = res.responses[j];
          if (r.success) continue;
          const err = r.error;
          topFail.push({
            idx: j,
            code: err?.code ?? null,
            msg: err?.message ? String(err.message).slice(0, 120) : null,
          });
          if (topFail.length >= 5) break;
        }
        if (topFail.length) {
          logger.warn("[weather-alarm] multicast failures (top)", { sentKey, topFail });
        }

        const batch = db.batch();
        chunk.forEach((x, idx) => {
          const r = res.responses[idx];
          if (r.success) {
            batch.set(x.ref, { lastAlarmSentKey: sentKey }, { merge: true });
          }
        });
        await batch.commit();
      }
    }

    logger.info("[weather-alarm] done", { sentKey, now: currentTime });
  }
);