'use strict';

/**
 * Canonical vocabulary shared by the API, the Flutter client and the future
 * matching engine. Values are stored, labels are presentation only — renaming a
 * label never requires a data migration.
 */

const ROLES = ['candidate', 'recruiter'];

const EXPERIENCE_LEVELS = [
  { value: 'fresher', label: 'Fresher', minYears: 0, maxYears: 0 },
  { value: 'lt_1', label: 'Less than 1 year', minYears: 0, maxYears: 1 },
  { value: '1_2', label: '1–2 years', minYears: 1, maxYears: 2 },
  { value: '2_3', label: '2–3 years', minYears: 2, maxYears: 3 },
  { value: '3_5', label: '3–5 years', minYears: 3, maxYears: 5 },
  { value: '5_8', label: '5–8 years', minYears: 5, maxYears: 8 },
  { value: '8_12', label: '8–12 years', minYears: 8, maxYears: 12 },
  { value: '12_plus', label: '12+ years', minYears: 12, maxYears: 50 },
];

const WORK_MODES = ['remote', 'onsite', 'hybrid'];

const OPEN_TO_WORK = ['actively_looking', 'open_to_opportunities', 'not_looking'];

const PROFILE_VISIBILITY = ['everyone', 'recruiters_only', 'connections_only', 'private'];

const MAX_JOB_TITLES = 5;
const MAX_HIRING_PROFILES = 10;

const EXPERIENCE_VALUES = EXPERIENCE_LEVELS.map((level) => level.value);

module.exports = {
  ROLES,
  EXPERIENCE_LEVELS,
  EXPERIENCE_VALUES,
  WORK_MODES,
  OPEN_TO_WORK,
  PROFILE_VISIBILITY,
  MAX_JOB_TITLES,
  MAX_HIRING_PROFILES,
};
