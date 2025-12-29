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
  if (v === undefined || v === null) return null;
  const s = String(v).trim();
  if (!s || s === "-" ) return null;
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
function regIdLandFromAdmin(adminArea) {
  const s = String(adminArea ?? "").replace(/\s/g, "");
  if (s.includes("서울") || s.includes("인천") || s.includes("경기")) return "11B00000";
  if (s.includes("강원")) return "11D10000";
  if (s.includes("충북")) return "11C10000";
  if (s.includes("대전") || s.includes("세종") || s.includes("충남")) return "11C20000";
  if (s.includes("전북")) return "11F10000";
  if (s.includes("광주") || s.includes("전남")) return "11F20000";
  if (s.includes("대구") || s.includes("경북")) return "11H10000";
  if (s.includes("부산") || s.includes("울산") || s.includes("경남")) return "11H20000";
  if (s.includes("제주")) return "11G00000";
  return null;
}

// ✅ 기온용(regIdTa) - 최소 시작(서울/인천은 공식 예시가 많이 잡힘)
function regIdTaFromAdmin(adminArea) {
  const s = String(adminArea ?? "").replace(/\s/g, "");
  if (s.includes("서울")) return "11B10101";   // 예시로 널리 사용 :contentReference[oaicite:3]{index=3}
  if (s.includes("인천")) return "11B20201";   // 예시로 널리 사용 :contentReference[oaicite:4]{index=4}

  // 아래는 지역별 대표 지점 코드가 필요해요.
  // (일단 null로 두면 min/max는 --로 안전하게 표시됨)
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

function appendMidToWeekly(short3, midLand, midTa, baseYmd) {

  const out = [...short3];

  // 오늘~모레(3일) 이후를 4~7일차 정도로 채워서 7일 카드 만들기
  for (let d = 3; d <= 7; d++) {
    const taMin = midTa?.[`taMin${d}`];
    const taMax = midTa?.[`taMax${d}`];

    const rnAm = midLand?.[`rnSt${d}Am`];
    const rnPm = midLand?.[`rnSt${d}Pm`];
    const wfAm = midLand?.[`wf${d}Am`];
    const wfPm = midLand?.[`wf${d}Pm`];

    out.push({
      date: addDaysYmd(baseYmd, d),
      min: toNum(taMin),
      max: toNum(taMax),
      pop: pickMax(rnAm, rnPm),                 // ✅ 오전/오후 중 큰 값
      wfText: (wfPm ?? wfAm) ?? null,           // ✅ PM 우선, 없으면 AM
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
    numOfRows: 10,
    pageNo: 1,
    stationName,
    dataTerm: "DAILY",
    ver: "1.3",
  };
  const res = await axios.get(url, { params, timeout: 8000 });
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

    const kmaNcst = await callKmaUltraNcst(nx, ny);
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

    // ✅ 중기: tmFc(06/18) + regId 분리
    const tmFc = midTmFc(new Date());

    const landRegId = regIdLandFromAdmin(administrativeArea);      // 육상용(기존)
    const taRegId = regIdTaFromAdmin(administrativeArea);      // ✅ 기온용(추가)

    let midLand = null;
    let midTa = null;

    if (landRegId) midLand = await callMidLand(landRegId, tmFc);
    if (taRegId) midTa = await callMidTa(taRegId, tmFc);

    // ✅ baseYmd: 단기 3일의 첫 날짜(없으면 오늘로)
    const baseYmd = weeklyShort3[0]?.date ?? ymdKst(new Date());

    weekly = appendMidToWeekly(weeklyShort3, midLand, midTa, baseYmd);

    const airRes = await buildAir(addr, administrativeArea);

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
    logger.error("getDashboard failed", e);
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("internal", `getDashboard failed: ${String(e?.message ?? e)}`);
  }
});
