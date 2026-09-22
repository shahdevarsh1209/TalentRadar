'use strict';

const CandidateProfile = require('../models/CandidateProfile');
const RecruiterProfile = require('../models/RecruiterProfile');
const Company = require('../models/Company');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../middleware/asyncHandler');
const { blurCoordinates } = require('../models/location');
const { PLACES, findPlace } = require('../seed/places.data');
const {
  sessionPayload,
  candidateCompletion,
  recruiterCompletion,
} = require('./authController');

/**
 * Builds the stored location document. A device fix keeps its precise point in a
 * non-selected field for distance maths only; what is published is a blurred
 * point plus area words.
 */
function buildLocation(input, { defaultRadiusKm = 2 } = {}) {
  const privacyRadiusKm = input.privacyRadiusKm ?? defaultRadiusKm;
  const location = {
    source: input.source,
    privacyRadiusKm,
    area: input.area || '',
    city: input.city || '',
    state: input.state || '',
    country: input.country || 'India',
    pincode: input.pincode || '',
    label: input.label || [input.area, input.city].filter(Boolean).join(', '),
    updatedAt: new Date(),
  };

  // A manual pick of a known area still gets its centre, so distances work.
  if (typeof input.latitude !== 'number' && input.source === 'manual') {
    const place = findPlace(input.area, input.city);
    if (place) {
      input = { ...input, latitude: place.latitude, longitude: place.longitude };
    }
  }

  if (typeof input.latitude === 'number' && typeof input.longitude === 'number') {
    location.precise = { type: 'Point', coordinates: [input.longitude, input.latitude] };
    location.approximate = {
      type: 'Point',
      coordinates: blurCoordinates(input.longitude, input.latitude, privacyRadiusKm),
    };
  }

  return location;
}

/** Candidate location: always privacy-blurred, radius defaults to 2 km. */
const setCandidateLocation = asyncHandler(async (req, res) => {
  const profile = await CandidateProfile.findOne({ userId: req.user._id });
  if (!profile) throw ApiError.notFound('We could not find your candidate profile.');

  profile.location = buildLocation(req.body, { defaultRadiusKm: 2 });
  profile.profileCompletion = candidateCompletion(profile);
  await profile.save();

  if (req.user.onboardingStage === 'email_verified' || req.user.onboardingStage === 'registered') {
    req.user.onboardingStage = 'location_set';
    await req.user.save();
  }

  const payload = await sessionPayload(req.user, { includeToken: false });
  res.json({ success: true, data: payload });
});

/**
 * Recruiter location is the COMPANY hiring location, never the recruiter's own
 * whereabouts, so it is stored on the company and published without blurring —
 * an office address is business information.
 */
const setHiringLocation = asyncHandler(async (req, res) => {
  const profile = await RecruiterProfile.findOne({ userId: req.user._id });
  if (!profile) throw ApiError.notFound('We could not find your hiring profile.');

  const { hiringRadiusKm, ...locationInput } = req.body;
  const location = buildLocation(locationInput, { defaultRadiusKm: 0.5 });

  profile.hiringLocations = [location];
  if (hiringRadiusKm) profile.hiringRadiusKm = hiringRadiusKm;

  const company = await Company.findById(profile.companyId);
  if (company) {
    company.officeLocations = [location];
    await company.save();
  }

  profile.profileCompletion = recruiterCompletion(profile, company);
  await profile.save();

  if (req.user.onboardingStage === 'email_verified' || req.user.onboardingStage === 'registered') {
    req.user.onboardingStage = 'location_set';
    await req.user.save();
  }

  const payload = await sessionPayload(req.user, { includeToken: false });
  res.json({ success: true, data: payload });
});

/** City / area suggestions for the manual picker, each with its centre point. */
const searchLocations = asyncHandler(async (req, res) => {
  const query = String(req.query.q || '').trim().toLowerCase();

  const results = [];
  PLACES.forEach((entry) => {
    const cityMatches = !query || entry.city.toLowerCase().includes(query);
    Object.entries(entry.areas).forEach(([area, [latitude, longitude]]) => {
      if (cityMatches || area.toLowerCase().includes(query)) {
        results.push({
          area,
          city: entry.city,
          state: entry.state,
          country: 'India',
          label: `${area}, ${entry.city}`,
          latitude,
          longitude,
        });
      }
    });
    if (cityMatches) {
      results.push({
        area: '',
        city: entry.city,
        state: entry.state,
        country: 'India',
        label: `${entry.city}, ${entry.state}`,
        latitude: entry.center[0],
        longitude: entry.center[1],
      });
    }
  });

  res.json({ success: true, data: { results: results.slice(0, 40) } });
});

module.exports = { setCandidateLocation, setHiringLocation, searchLocations, buildLocation };
