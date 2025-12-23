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

exports.getDashboard = onCall({ region: "asia-northeast3" }, async (request) => {
  const { lat, lon, locationName } = request.data || {};
  if (typeof lat !== "number" || typeof lon !== "number") {
    throw new Error("lat/lon is required");
  }

  const { nx, ny } = latLonToGrid(lat, lon);

  logger.info("getDashboard", { lat, lon, nx, ny, locationName });

  // 1) 기상청: 초단기실황
  const kma = await callKmaUltraNcst(nx, ny);

  // TODO) 2) 초단기예보(getUltraSrtFcst), 3) 단기예보(getVilageFcst), 4) 기상특보 API도 같은 방식으로 추가

  // 2) 에어코리아: (권장) getTMStdrCrdnt -> getNearbyMsrstnList -> getMsrstnAcctoRltmMesureDnsty
  // 여기서는 구조만 두고, 먼저 기상청부터 붙인 다음 단계적으로 추가 추천

  return {
    updatedAt: new Date().toISOString(),
    locationName: locationName || "",
    nx, ny,
    weatherNow: kma.items,      // 지금 네 파서가 기대하는 [{category, obsrValue}] 형태
    hourlyFcst: [],             // 다음 단계에서 채우기
    alerts: [],
    air: { gradeText: "정보없음", pm10: null, pm25: null },
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
