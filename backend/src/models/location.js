'use strict';

const mongoose = require('mongoose');

/**
 * Two-tier location. `precise` is used only for server-side distance maths and
 * is never serialised to another user; `area`, plus a coordinate that has been
 * deliberately jittered inside `privacyRadiusKm`, is the only thing that leaves
 * the server. Candidates therefore cannot be traced to a home address.
 */
const pointSchema = new mongoose.Schema(
  {
    type: { type: String, enum: ['Point'], default: 'Point' },
    // GeoJSON order: [longitude, latitude].
    coordinates: { type: [Number], required: true },
  },
  { _id: false }
);

const locationSchema = new mongoose.Schema(
  {
    source: { type: String, enum: ['device', 'manual', 'unset'], default: 'unset' },
    precise: { type: pointSchema, default: undefined, select: false },
    approximate: { type: pointSchema, default: undefined },
    privacyRadiusKm: { type: Number, default: 2, min: 0.5, max: 25 },
    area: { type: String, trim: true, default: '' },
    city: { type: String, trim: true, default: '' },
    state: { type: String, trim: true, default: '' },
    country: { type: String, trim: true, default: 'India' },
    pincode: { type: String, trim: true, default: '' },
    label: { type: String, trim: true, default: '' },
    updatedAt: { type: Date, default: null },
  },
  { _id: false }
);

/** Offsets a point by up to `radiusKm` so a stored coordinate is never a home. */
function blurCoordinates(longitude, latitude, radiusKm = 2) {
  const angle = Math.random() * 2 * Math.PI;
  // sqrt keeps the sample uniform across the disc rather than clustered centrally.
  const distanceKm = Math.sqrt(Math.random()) * radiusKm;
  const deltaLat = distanceKm / 110.574;
  const deltaLng = distanceKm / (111.32 * Math.cos((latitude * Math.PI) / 180) || 1);
  return [
    Number((longitude + deltaLng * Math.cos(angle)).toFixed(5)),
    Number((latitude + deltaLat * Math.sin(angle)).toFixed(5)),
  ];
}

/** Public projection: area words only, never the precise point. */
function publicLocation(loc) {
  if (!loc) return null;
  return {
    area: loc.area || '',
    city: loc.city || '',
    state: loc.state || '',
    country: loc.country || '',
    pincode: loc.pincode || '',
    label: loc.label || '',
    source: loc.source || 'unset',
    privacyRadiusKm: loc.privacyRadiusKm ?? 2,
    isSet: Boolean(loc.source && loc.source !== 'unset'),
  };
}

module.exports = { pointSchema, locationSchema, blurCoordinates, publicLocation };
