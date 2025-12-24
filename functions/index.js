/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const { onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const axios = require("axios");

// (1) 위경도 -> 기상청 격자(nx, ny) 변환 (널리 쓰는 LCC 변환)
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

  let ra = Math.tan(Math.PI * 0.25 + (lat) * DEGRAD * 0.5);
  ra = re * sf / Math.pow(ra, sn);

  let theta = lon * DEGRAD - olon;
  if (theta > Math.PI) theta -= 2.0 * Math.PI;
  if (theta < -Math.PI) theta += 2.0 * Math.PI;
  theta *= sn;

  const x = Math.floor(ra * Math.sin(theta) + XO + 0.5);
  const y = Math.floor(ro - ra * Math.cos(theta) + YO + 0.5);
  return { nx: x, ny: y };
}

// (2) 기상청 base_time 간단 규칙(실황: 매시 40분쯤 이후 데이터가 안정적)
// 실제 운영하면서 30~60분 정도 오프셋 튜닝해도 됨
function kmaNcstBase(dt) {
  const d = new Date(dt);
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  let hh = kst.getUTCHours();
  const mm = kst.getUTCMinutes();

  // mm < 40이면 한 시간 전 데이터로
  if (mm < 40) hh -= 1;
  if (hh < 0) {
    hh = 23;
    kst.setUTCDate(kst.getUTCDate() - 1);
  }
  const y = kst.getUTCFullYear();
  const m = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const day = String(kst.getUTCDate()).padStart(2, "0");
  const base_date = `${y}${m}${day}`;
  const base_time = `${String(hh).padStart(2, "0")}00`;
  return { base_date, base_time };
}

async function callKmaUltraNcst(nx, ny) {
  const { base_date, base_time } = kmaNcstBase(new Date());
  const url = "http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst"; // :contentReference[oaicite:8]{index=8}
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
  const items = res.data?.response?.body?.items?.item ?? [];
  return { items, base_date, base_time };
}

function kmaFcstBase(dt) {
    const d = new Date(dt);
    const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
    let hh = kst.getUTCHours();
    const mm = kst.getUTCMinutes();

    // 초단기예보는 보통 30분 발표 + 실제 반영 지연이 있으니
    // 45분 전이면 한 시간 전 회차(…30)로 잡는 게 안정적
    if (mm < 45) hh -= 1;
    if (hh < 0) {
      hh = 23;
      kst.setUTCDate(kst.getUTCDate() - 1);
    }
    const y = kst.getUTCFullYear();
    const m = String(kst.getUTCMonth() + 1).padStart(2, "0");
    const day = String(kst.getUTCDate()).padStart(2, "0");
    const base_date = `${y}${m}${day}`;
    const base_time = `${String(hh).padStart(2, "0")}30`;
    return { base_date, base_time };
  }

  async function callKmaUltraFcst(nx, ny) {
    const { base_date, base_time } = kmaFcstBase(new Date());
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
    const items = res.data?.response?.body?.items?.item ?? [];
    return { items, base_date, base_time };
  }

  function buildHourlyFcst(items) {
    // fcstDate+fcstTime별로 SKY/PTY/T1H(or TMP) 묶기
    const byKey = new Map();
    for (const it of items) {
      const key = `${it.fcstDate}${it.fcstTime}`;
      if (!byKey.has(key)) byKey.set(key, { fcstDate: it.fcstDate, fcstTime: it.fcstTime });
      byKey.get(key)[it.category] = it.fcstValue;
    }

    const list = [...byKey.values()]
      .map((v, idx) => {
        const hh = Number(String(v.fcstTime).slice(0, 2));
        return {
          timeLabel: idx === 0 ? "NOW" : `${hh}시`,
          sky: v.SKY != null ? Number(v.SKY) : null,
          pty: v.PTY != null ? Number(v.PTY) : null,
          temp: v.T1H != null ? Number(v.T1H) : (v.TMP != null ? Number(v.TMP) : null),
          _k: `${v.fcstDate}${v.fcstTime}`,
        };
      })
      .filter(x => x.temp !== null)          // temp 없는 슬롯 제거
      .sort((a, b) => (a._k < b._k ? -1 : 1))
      .slice(0, 8)                           // 6~8개 정도만 UI에 충분
      .map(({ _k, ...rest }) => rest);

    return list;
  }

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
      addr, // 예: "인천광역시 부평구"
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

  function toNum(v) {
    const s = String(v ?? "").trim();
    if (!s || s === "-" ) return null;
    const n = Number(s);
    return Number.isFinite(n) ? n : null;
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

      // ✅ 데이터가 하나라도 있으면 채택
      if (pm10 != null || pm25 != null || (grade && grade !== "-")) {
        return {
          air: {
            gradeText: gradeTextFromKhai(grade),
            pm10,
            pm25,
          },
          meta: { stationName, dataTime: row.dataTime ?? null },
        };
      }
    }

    return { air: { gradeText: "정보없음", pm10: null, pm25: null }, meta: { stationName: null } };
  }

exports.getDashboard = onCall({ region: "asia-northeast3" }, async (request) => {
  const { lat, lon, locationName } = request.data || {};
  if (typeof lat !== "number" || typeof lon !== "number") {
    throw new Error("lat/lon is required");
  }

  const { nx, ny } = latLonToGrid(lat, lon);

  // ✅ Flutter에서 locationName을 "인천광역시 부평구" 같은 addr로 쓰고 있다면 이걸 그대로 사용 가능
  const addr = (request.data?.addr ?? request.data?.locationName ?? "").toString();

//  logger.info("getDashboard", { lat, lon, nx, ny, locationName, addr });

  // 1) 실황
  const kmaNcst = await callKmaUltraNcst(nx, ny);

  // 2) 시간대별 예보
  const kmaFcst = await callKmaUltraFcst(nx, ny);
  const hourlyFcst = buildHourlyFcst(kmaFcst.items);

  // 3) 대기질
  const airRes = await buildAir(addr);

  return {
    updatedAt: new Date().toISOString(),

    // ✅ Flutter 파서가 기대하는 형태로 반환
    weatherNow: kmaNcst.items,   // [{category, obsrValue}, ...]
    hourlyFcst: hourlyFcst,      // [{timeLabel, sky, pty, temp}, ...]
    alerts: [],
    air: airRes.air,             // {gradeText, pm10, pm25}

    // (선택) 디버그용: 지금 실제로 뭐가 잡혔는지 확인하기 좋음
    meta: {
      nx,
      ny,
      addr,
      kmaNcstBase: { base_date: kmaNcst.base_date, base_time: kmaNcst.base_time },
      kmaFcstBase: { base_date: kmaFcst.base_date, base_time: kmaFcst.base_time },
      air: airRes.meta, // stationName, dataTime
    },
  };
});



// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
