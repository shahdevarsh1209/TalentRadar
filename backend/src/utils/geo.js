'use strict';

/** Great-circle distance in km between two GeoJSON points ([lng, lat]). */
function distanceKm(pointA, pointB) {
  const a = pointA?.coordinates;
  const b = pointB?.coordinates;
  if (!Array.isArray(a) || !Array.isArray(b)) return null;

  const toRad = (deg) => (deg * Math.PI) / 180;
  const [lng1, lat1] = a;
  const [lng2, lat2] = b;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

/**
 * Distance shown to another person. Rounded to half a kilometre with a 0.5 km
 * floor, so repeated lookups cannot be used to triangulate someone's home.
 */
function displayDistance(km, { precise = false } = {}) {
  if (km === null || km === undefined || Number.isNaN(km)) return null;
  if (precise) return Math.max(0.1, Math.round(km * 10) / 10);
  return Math.max(0.5, Math.round(km * 2) / 2);
}

module.exports = { distanceKm, displayDistance };
