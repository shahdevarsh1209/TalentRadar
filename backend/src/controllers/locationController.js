'use strict';

const CandidateProfile = require('../models/CandidateProfile');
const RecruiterProfile = require('../models/RecruiterProfile');
const Company = require('../models/Company');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../middleware/asyncHandler');
const { blurCoordinates } = require('../models/location');
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

/**
 * Manual-entry fallback for a denied location permission. Static for now; the
 * client only needs the shape to stay the same when this hits a places API.
 */
const CITY_DIRECTORY = [
  { city: 'Bengaluru', state: 'Karnataka', areas: ['HSR Layout', 'Koramangala', 'Indiranagar', 'Whitefield', 'Bellandur', 'Jayanagar', 'Marathahalli', 'Electronic City'] },
  { city: 'Ahmedabad', state: 'Gujarat', areas: ['Satellite', 'Bodakdev', 'Prahlad Nagar', 'SG Highway', 'Maninagar', 'Vastrapur', 'Navrangpura'] },
  { city: 'Mumbai', state: 'Maharashtra', areas: ['Andheri East', 'Bandra Kurla Complex', 'Powai', 'Lower Parel', 'Thane', 'Navi Mumbai'] },
  { city: 'Pune', state: 'Maharashtra', areas: ['Hinjewadi', 'Kharadi', 'Baner', 'Viman Nagar', 'Magarpatta'] },
  { city: 'Hyderabad', state: 'Telangana', areas: ['HITEC City', 'Gachibowli', 'Madhapur', 'Kondapur', 'Banjara Hills'] },
  { city: 'Delhi', state: 'Delhi', areas: ['Connaught Place', 'Saket', 'Dwarka', 'Rohini', 'Nehru Place'] },
  { city: 'Gurugram', state: 'Haryana', areas: ['Cyber City', 'Golf Course Road', 'Udyog Vihar', 'Sohna Road'] },
  { city: 'Noida', state: 'Uttar Pradesh', areas: ['Sector 62', 'Sector 125', 'Sector 16', 'Greater Noida'] },
  { city: 'Chennai', state: 'Tamil Nadu', areas: ['OMR', 'Guindy', 'T Nagar', 'Velachery', 'Ambattur'] },
  { city: 'Kolkata', state: 'West Bengal', areas: ['Salt Lake Sector V', 'New Town', 'Park Street', 'Howrah'] },
  { city: 'Jaipur', state: 'Rajasthan', areas: ['Malviya Nagar', 'Vaishali Nagar', 'C Scheme', 'Mansarovar'] },
  { city: 'Indore', state: 'Madhya Pradesh', areas: ['Vijay Nagar', 'Palasia', 'Rau', 'Scheme 78'] },
  { city: 'Surat', state: 'Gujarat', areas: ['Adajan', 'Vesu', 'Piplod', 'Katargam'] },
  { city: 'Kochi', state: 'Kerala', areas: ['Infopark', 'Kakkanad', 'Edappally', 'Fort Kochi'] },
  { city: 'Chandigarh', state: 'Chandigarh', areas: ['IT Park', 'Sector 17', 'Mohali', 'Panchkula'] },
];

const searchLocations = asyncHandler(async (req, res) => {
  const query = String(req.query.q || '').trim().toLowerCase();

  const results = [];
  CITY_DIRECTORY.forEach((entry) => {
    const cityMatches = !query || entry.city.toLowerCase().includes(query);
    entry.areas.forEach((area) => {
      if (cityMatches || area.toLowerCase().includes(query)) {
        results.push({
          area,
          city: entry.city,
          state: entry.state,
          country: 'India',
          label: `${area}, ${entry.city}`,
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
      });
    }
  });

  res.json({ success: true, data: { results: results.slice(0, 40) } });
});

module.exports = { setCandidateLocation, setHiringLocation, searchLocations, buildLocation };
