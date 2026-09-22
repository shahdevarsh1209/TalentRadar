/* End-to-end exercise of the registration module against a running API. */
const BASE = 'http://localhost:4000/api/v1';
const stamp = Date.now();

async function call(method, path, body, token) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  return { status: res.status, json };
}

let pass = 0;
let fail = 0;
function check(label, condition, extra) {
  if (condition) {
    pass += 1;
    console.log(`  PASS  ${label}`);
  } else {
    fail += 1;
    console.log(`  FAIL  ${label}${extra ? ` -> ${JSON.stringify(extra)}` : ''}`);
  }
}

(async () => {
  console.log('\n== Candidate registration ==');
  const candidateEmail = `aditi.sharma.${stamp}@gmail.com`;

  const bad = await call('POST', '/auth/register/candidate', {
    name: 'A',
    email: 'not-an-email',
    jobTitleCodes: [],
    workModes: [],
  });
  check('rejects invalid payload with field details', bad.status === 422 && bad.json.error.details.length >= 3, bad.json);

  const reg = await call('POST', '/auth/register/candidate', {
    name: '  Aditi   Sharma ',
    email: candidateEmail.replace('aditi.sharma', 'Aditi.Sharma'),
    password: 'StrongPass123',
    jobTitleCodes: ['JT_040', 'JT_049', 'JT_050'],
    experienceLevel: '1_2',
    workModes: ['hybrid', 'onsite'],
    openToWork: 'actively_looking',
    profileVisibility: 'recruiters_only',
  });
  check('creates candidate', reg.status === 201, reg.json);
  check('trims and collapses name', reg.json.data?.profile?.name === 'Aditi Sharma', reg.json.data?.profile?.name);
  check('normalises gmail case + dots', reg.json.data?.user?.email === `aditisharma${stamp}@gmail.com`, reg.json.data?.user?.email);
  check('stores 3 job titles by code', reg.json.data?.profile?.jobTitles?.length === 3, reg.json.data?.profile?.jobTitles);
  check('stores multiple work modes incl. hybrid', (reg.json.data?.profile?.workModes || []).includes('hybrid'), reg.json.data?.profile?.workModes);
  check('issues verification code', Boolean(reg.json.data?.verification?.devCode), reg.json.data?.verification);
  check('email starts unverified', reg.json.data?.user?.isEmailVerified === false);
  check('location not set at registration', reg.json.data?.profile?.location?.isSet === false, reg.json.data?.profile?.location);

  const token = reg.json.data.token;
  const userId = reg.json.data.user.userId;
  const code = reg.json.data.verification.devCode;

  console.log('\n== Duplicate handling ==');
  const dup = await call('POST', '/auth/register/candidate', {
    name: 'Aditi Sharma',
    email: candidateEmail,
    password: 'StrongPass123',
    jobTitleCodes: ['JT_040'],
    workModes: ['remote'],
  });
  check('same email + same role -> EMAIL_EXISTS', dup.status === 409 && dup.json.error.code === 'EMAIL_EXISTS', dup.json.error);

  const dupOther = await call('POST', '/auth/register/recruiter', {
    companyName: 'ABC Technologies',
    hrName: 'Riya Joshi',
    email: candidateEmail,
    password: 'StrongPass123',
    hiringProfileCodes: ['JT_001'],
  });
  check('same email + other role -> EMAIL_EXISTS_OTHER_ROLE', dupOther.status === 409 && dupOther.json.error.code === 'EMAIL_EXISTS_OTHER_ROLE', dupOther.json.error);

  console.log('\n== Email verification ==');
  const wrong = await call('POST', '/auth/verify-email', { userId, code: '000000' });
  check('wrong code rejected with attempts left', wrong.status === 400 && /attempt/i.test(wrong.json.error.message), wrong.json.error);

  const resend = await call('POST', '/auth/resend-code', { userId });
  check('resend blocked inside cooldown', resend.status === 429, resend.json.error);

  const verified = await call('POST', '/auth/verify-email', { userId, code });
  check('correct code verifies email', verified.status === 200 && verified.json.data.user.isEmailVerified === true, verified.json.error);
  check('onboarding stage advances', verified.json.data?.user?.onboardingStage === 'email_verified', verified.json.data?.user);

  console.log('\n== Candidate location (privacy) ==');
  const loc = await call('PUT', '/candidates/me/location', {
    source: 'device',
    latitude: 12.9121,
    longitude: 77.6446,
    area: 'HSR Layout',
    city: 'Bengaluru',
    state: 'Karnataka',
  }, token);
  check('accepts device location', loc.status === 200, loc.json.error);
  const publicLoc = loc.json.data?.profile?.location;
  check('publishes area words only', publicLoc?.area === 'HSR Layout' && publicLoc?.city === 'Bengaluru', publicLoc);
  check('never returns exact coordinates', JSON.stringify(loc.json).includes('77.6446') === false, 'precise coords leaked');
  check('stage advances to location_set', loc.json.data?.user?.onboardingStage === 'location_set');

  console.log('\n== Login ==');
  const badLogin = await call('POST', '/auth/login', { email: candidateEmail, password: 'wrongpass' });
  check('bad password rejected', badLogin.status === 401, badLogin.json.error);
  const goodLogin = await call('POST', '/auth/login', { email: candidateEmail, password: 'StrongPass123' });
  check('login returns token + profile', goodLogin.status === 200 && Boolean(goodLogin.json.data.token) && goodLogin.json.data.profile.jobTitles.length === 3, goodLogin.json.error);
  const roleMismatch = await call('POST', '/auth/login', { email: candidateEmail, password: 'StrongPass123', role: 'recruiter' });
  check('role mismatch explained', roleMismatch.status === 409 && roleMismatch.json.error.code === 'ROLE_MISMATCH', roleMismatch.json.error);

  console.log('\n== Recruiter registration ==');
  const hrEmail = `riya.joshi.${stamp}@abctechnologies.com`;
  const hr = await call('POST', '/auth/register/recruiter', {
    companyName: 'ABC Technologies Pvt Ltd',
    hrName: 'Riya Joshi',
    email: hrEmail,
    password: 'StrongPass123',
    designation: 'Talent Acquisition Manager',
    hiringProfileCodes: ['JT_001', 'JT_004', 'JT_049', 'JT_022', 'JT_091'],
    hiringWorkModes: ['onsite', 'hybrid'],
  });
  check('creates recruiter', hr.status === 201, hr.json);
  check('creates company record', Boolean(hr.json.data?.company?.companyId), hr.json.data?.company);
  check('flags official email domain', hr.json.data?.profile?.isOfficialEmailDomain === true);
  check('stores 5 hiring profiles', hr.json.data?.profile?.hiringProfiles?.length === 5);

  const hrToken = hr.json.data.token;
  const hrCode = hr.json.data.verification.devCode;
  await call('POST', '/auth/verify-email', { userId: hr.json.data.user.userId, code: hrCode });

  // Second recruiter, same company, different spelling of the name.
  const hr2 = await call('POST', '/auth/register/recruiter', {
    companyName: 'ABC Technologies',
    hrName: 'Manish Kumar',
    email: `manish.${stamp}@abctechnologies.com`,
    password: 'StrongPass123',
    hiringProfileCodes: ['JT_001'],
  });
  check('second recruiter joins existing company', hr2.json.data?.company?.companyId === hr.json.data?.company?.companyId, {
    first: hr.json.data?.company?.companyId,
    second: hr2.json.data?.company?.companyId,
  });

  console.log('\n== Hiring location (company, not personal) ==');
  const hrLoc = await call('PUT', '/recruiters/me/hiring-location', {
    source: 'manual',
    city: 'Ahmedabad',
    area: 'Prahlad Nagar',
    state: 'Gujarat',
    hiringRadiusKm: 10,
  }, hrToken);
  check('stores hiring location', hrLoc.status === 200 && hrLoc.json.data.profile.hiringLocations[0].city === 'Ahmedabad', hrLoc.json.error);
  check('hiring radius stored', hrLoc.json.data?.profile?.hiringRadiusKm === 10);

  console.log('\n== Guards ==');
  const crossRole = await call('PUT', '/candidates/me/location', { source: 'manual', city: 'Pune' }, hrToken);
  check('recruiter cannot use candidate endpoint', crossRole.status === 403, crossRole.json.error);
  const noAuth = await call('GET', '/auth/me');
  check('unauthenticated /me rejected', noAuth.status === 401, noAuth.json.error);
  const notFound = await call('GET', '/nope');
  check('unknown route returns friendly 404', notFound.status === 404 && Boolean(notFound.json.error.message), notFound.json);
  const badTitle = await call('POST', '/auth/register/candidate', {
    name: 'Test User',
    email: `x.${stamp}@example.com`,
    password: 'StrongPass123',
    jobTitleCodes: ['JT_DOES_NOT_EXIST'],
    workModes: ['remote'],
  });
  check('unknown job-title code rejected', badTitle.status === 422, badTitle.json.error);

  console.log('\n== Stealth / not-looking ==');
  const quiet = await call('POST', '/auth/register/candidate', {
    name: 'Quiet Candidate',
    email: `quiet.${stamp}@example.com`,
    password: 'StrongPass123',
    jobTitleCodes: ['JT_070'],
    workModes: ['remote'],
    openToWork: 'not_looking',
  });
  check('not-looking implies stealth mode', quiet.json.data?.profile?.stealthMode === true, quiet.json.data?.profile);

  console.log(`\n=== ${pass} passed, ${fail} failed ===`);
  process.exit(fail === 0 ? 0 : 1);
})();
