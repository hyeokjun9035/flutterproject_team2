/**
 * functions/index.js
 */
const { setGlobalOptions } = require("firebase-functions");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const axios = require("axios");

setGlobalOptions({ maxInstances: 10 });

/** -----------------------------
 *  공통 유틸
 * ------------------------------ */
function toNum(v) {
  const s = String(v ?? "").trim();
  if (!s || s === "-") return null;
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
  const res = await axios.get(url, { params, timeout: 8000 });
  return { items: res.data?.response?.body?.items?.item ?? [], base_date, base_time };
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
  const res = await axios.get(url, { params, timeout: 8000 });
  return { items: res.data?.response?.body?.items?.item ?? [], base_date, base_time };
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
  const res = await axios.get(url, { params, timeout: 8000 });
  return { items: res.data?.response?.body?.items?.item ?? [], base_date, base_time };
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
        temp: v.TMP != null ? Number(v.TMP) : null, // 단기예보는 TMP
      };
    })
    .filter(x => x.temp !== null)
    .sort((a, b) => (a._k < b._k ? -1 : 1));
}

function mergeHourly(ultra, vilage, take = 24) {
  const seen = new Set();
  const out = [];

  for (const x of ultra) {
    if (!x._k || seen.has(x._k)) continue;
    seen.add(x._k);
    out.push(x);
  }
  for (const x of vilage) {
    if (!x._k || seen.has(x._k)) continue;
    seen.add(x._k);
    out.push(x);
  }

  out.sort((a, b) => (a._k < b._k ? -1 : 1));
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
    if (!byDate.has(d)) byDate.set(d, { date: d, min: null, max: null, pop: 0, sky12: null, pty: 0 });
    const row = byDate.get(d);

    if (it.category === "TMN") row.min = toNum(it.fcstValue);
    if (it.category === "TMX") row.max = toNum(it.fcstValue);

    if (it.category === "POP") row.pop = Math.max(row.pop, Number(it.fcstValue ?? 0));
    if (it.category === "PTY") row.pty = Math.max(row.pty, Number(it.fcstValue ?? 0));

    if (it.category === "SKY") {
      if (it.fcstTime === "1200") row.sky12 = toNum(it.fcstValue);
      if (row.sky12 == null) row.sky12 = toNum(it.fcstValue);
    }
  }

  return [...byDate.values()]
    .sort((a, b) => (a.date < b.date ? -1 : 1))
    .slice(0, 3)
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
function regIdFromAdmin(adminArea) {
  const s = String(adminArea ?? "").replace(/\s/g, "");
  if (s.includes("서울") || s.includes("인천") || s.includes("경기")) return "11B00000";
  if (s.includes("강원")) return "11D10000"; // 영서/영동 세분은 나중에 개선 가능
  if (s.includes("충북")) return "11C10000";
  if (s.includes("대전") || s.includes("세종") || s.includes("충남")) return "11C20000";
  if (s.includes("전북")) return "11F10000";
  if (s.includes("광주") || s.includes("전남")) return "11F20000";
  if (s.includes("대구") || s.includes("경북")) return "11H10000";
  if (s.includes("부산") || s.includes("울산") || s.includes("경남")) return "11H20000";
  if (s.includes("제주")) return "11G00000";
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
  const res = await axios.get(url, { params, timeout: 8000 });
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
  const res = await axios.get(url, { params, timeout: 8000 });
  return res.data?.response?.body?.items?.item?.[0] ?? null;
}

function appendMidToWeekly(short3, midLand, midTa) {
  const base = short3[0]?.date;
  if (!base) return short3;

  const out = [...short3];

  // 오늘~모레(3일) 이후를 4~7일차 정도로 채워서 7일 카드 만들기
  for (let d = 3; d <= 7; d++) {
    out.push({
      date: addDaysYmd(base, d),
      min: midTa?.[`taMin${d}`] != null ? toNum(midTa[`taMin${d}`]) : null,
      max: midTa?.[`taMax${d}`] != null ? toNum(midTa[`taMax${d}`]) : null,
      pop: midLand?.[`rnSt${d}Pm`] != null ? toNum(midLand[`rnSt${d}Pm`]) : null,
      wfText: midLand?.[`wf${d}Pm`] ?? null, // "맑음" "구름많음" "비" 등 텍스트
      sky: null,
      pty: null,
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
  const res = await axios.get(url, { params, timeout: 8000 });
  return res.data?.response?.body?.items ?? [];
}

async function callAirRltmByStation(stationName) {
  const url = "http://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getMsrstnAcctoRltmMesureDnsty";
  const params = {
    serviceKey: process.env.AIRKOREA_SERVICE_KEY,
    returnType: "json",
    numOfRows: 1,
    pageNo: 1,
    stationName,
    dataTerm: "DAILY",
    ver: "1.3",
  };
  const res = await axios.get(url, { params, timeout: 8000 });
  return res.data?.response?.body?.items ?? [];
}

async function buildAir(addr) {
  if (!addr) return { air: { gradeText: "정보없음", pm10: null, pm25: null }, meta: { stationName: null } };

  const stations = await callAirMsrstnListByAddr(addr);
  for (const st of stations) {
    const stationName = st?.stationName;
    if (!stationName) continue;

    const msr = await callAirRltmByStation(stationName);
    const row = msr?.[0];
    if (!row) continue;

    const pm10 = toNum(row.pm10Value);
    const pm25 = toNum(row.pm25Value);
    const grade = String(row.khaiGrade ?? "").trim();

    if (pm10 != null || pm25 != null || (grade && grade !== "-")) {
      return {
        air: { gradeText: gradeTextFromKhai(grade), pm10, pm25 },
        meta: { stationName, dataTime: row.dataTime ?? null },
      };
    }
  }

  return { air: { gradeText: "정보없음", pm10: null, pm25: null }, meta: { stationName: null } };
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

    // addr: 에어코리아 조회용 ("인천광역시 부평구" 같은 형태가 안정적)
    const addr = String(request.data?.addr ?? request.data?.locationName ?? "");
    const administrativeArea = String(request.data?.administrativeArea ?? "");

    // 1) 기상청: 초단기실황(현재값)
    const kmaNcst = await callKmaUltraNcst(nx, ny);

    // 2) 기상청: 시간대별 (초단기 + 단기 merge)
    const kmaUltra = await callKmaUltraFcst(nx, ny);
    const kmaVilage = await callKmaVilageFcst(nx, ny);

    const hourlyFcst = mergeHourly(
      buildHourlyUltraRaw(kmaUltra.items),
      buildHourlyFromVilage(kmaVilage.items),
      24
    );

    // 3) 주간: 단기 3일 + 중기 덧붙이기(가능하면)
    const weeklyShort3 = buildDailyFromVilage(kmaVilage.items);
    let weekly = weeklyShort3;

    const regId = regIdFromAdmin(administrativeArea);
    if (regId) {
      const tmFc = midTmFc(new Date());
      const [midLand, midTa] = await Promise.all([
        callMidLand(regId, tmFc),
        callMidTa(regId, tmFc),
      ]);
      weekly = appendMidToWeekly(weeklyShort3, midLand, midTa);
    }

    // 4) 대기질
    const airRes = await buildAir(addr);

    // logger.info("getDashboard", { lat, lon, nx, ny, addr, administrativeArea, regId });

    return {
      updatedAt: new Date().toISOString(),
      locationName: String(locationName ?? ""),
      weatherNow: kmaNcst.items,
      hourlyFcst,
      weekly,
      alerts: [],
      air: airRes.air,
      meta: {
        nx,
        ny,
        addr,
        administrativeArea,
        regId: regId ?? null,
        kmaNcstBase: { base_date: kmaNcst.base_date, base_time: kmaNcst.base_time },
        kmaUltraBase: { base_date: kmaUltra.base_date, base_time: kmaUltra.base_time },
        kmaVilageBase: { base_date: kmaVilage.base_date, base_time: kmaVilage.base_time },
        air: airRes.meta,
      },
    };
  } catch (e) {
    logger.error("getDashboard failed", e);
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("internal", `getDashboard failed: ${String(e?.message ?? e)}`);
  }
});
