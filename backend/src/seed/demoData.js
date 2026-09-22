'use strict';

/**
 * Demo data for local development and client demos, so every screen has
 * something to show on a fresh database. Company names are fictional.
 *
 * Runs automatically with `npm run dev:memory`, or on demand with
 * `npm run seed:demo`. Never runs in production.
 *
 * Every demo account uses the password: Demo@1234
 */

const mongoose = require('mongoose');
const User = require('../models/User');
const Company = require('../models/Company');
const CandidateProfile = require('../models/CandidateProfile');
const RecruiterProfile = require('../models/RecruiterProfile');
const Job = require('../models/Job');
const { buildLocation } = require('../controllers/locationController');
const { resolveTitleCodes } = require('../services/jobTitleService');
const { findPlace } = require('./places.data');

const DEMO_PASSWORD = 'Demo@1234';
const DEMO_DOMAIN = 'demo.talentradar.app';

function place(area, city) {
  const found = findPlace(area, city);
  return { source: 'manual', ...found, label: `${found.area || found.city}, ${found.city}` };
}

function daysFromNow(days) {
  const date = new Date();
  date.setDate(date.getDate() + days);
  date.setHours(0, 0, 0, 0);
  return date;
}

const RECRUITERS = [
  {
    email: `riya.joshi@${DEMO_DOMAIN}`, hrName: 'Riya Joshi', designation: 'Hiring Manager',
    company: { name: 'BrightDesk Support', industry: 'Customer Experience', size: '201-500', website: 'https://brightdesk.example.com' },
    where: ['HSR Layout', 'Bengaluru'], hiring: ['JT_042', 'JT_040', 'JT_045'],
    jobs: [
      { titleCode: 'JT_042', workMode: 'onsite', openings: 4, experienceLevel: 'fresher', salaryMin: 22000, salaryMax: 28000, isWalkIn: true, walkIn: { day: 0, startTime: '10:00', endTime: '16:00', address: '27th Main, HSR Sector 2' }, description: 'Handle customer queries over chat and email for a fast-growing consumer app. Walk in with your resume — interviews happen on the spot.' },
      { titleCode: 'JT_040', workMode: 'hybrid', openings: 2, experienceLevel: '1_2', salaryMin: 25000, salaryMax: 32000, description: 'Troubleshoot product issues, write help-centre articles and work with the engineering team on bug reports.' },
    ],
  },
  {
    email: `arjun.menon@${DEMO_DOMAIN}`, hrName: 'Arjun Menon', designation: 'Talent Acquisition Lead',
    company: { name: 'LedgerLoop Fintech', industry: 'Financial Services', size: '51-200', website: 'https://ledgerloop.example.com' },
    where: ['Koramangala', 'Bengaluru'], hiring: ['JT_072', 'JT_004', 'JT_110'],
    jobs: [
      { titleCode: 'JT_072', workMode: 'hybrid', openings: 1, experienceLevel: '2_3', salaryMin: 60000, salaryMax: 85000, description: 'Plan and run user interviews and usability studies for our payments product. Two days a week at the Koramangala office.' },
      { titleCode: 'JT_004', workMode: 'remote', openings: 2, experienceLevel: '1_2', salaryMin: 50000, salaryMax: 80000, description: 'Build and ship features in our Flutter merchant app. Fully remote within India.' },
      { titleCode: 'JT_110', workMode: 'onsite', openings: 1, experienceLevel: '2_3', salaryMin: 35000, salaryMax: 45000, isWalkIn: true, walkIn: { day: 1, startTime: '11:00', endTime: '15:00', address: '80 Feet Road, Koramangala 4th Block' }, description: 'Manage reconciliations, GST filings and month-end close.' },
    ],
  },
  {
    email: `neha.patel@${DEMO_DOMAIN}`, hrName: 'Neha Patel', designation: 'HR Manager',
    company: { name: 'Kirana Kart Retail', industry: 'Retail & E-commerce', size: '501-1000', website: 'https://kiranakart.example.com' },
    where: ['Prahlad Nagar', 'Ahmedabad'], hiring: ['JT_040', 'JT_049', 'JT_091', 'JT_112'],
    jobs: [
      { titleCode: 'JT_040', workMode: 'hybrid', openings: 3, experienceLevel: '1_2', salaryMin: 24000, salaryMax: 30000, description: 'Support store teams on our ERP and billing software. Hybrid — three days at the Prahlad Nagar office.' },
      { titleCode: 'JT_049', workMode: 'onsite', openings: 1, experienceLevel: '3_5', salaryMin: 55000, salaryMax: 75000, description: 'Own the functional side of our ERP roll-out across 40 stores.' },
      { titleCode: 'JT_091', workMode: 'onsite', openings: 5, experienceLevel: 'fresher', salaryMin: 20000, salaryMax: 26000, isWalkIn: true, walkIn: { day: 0, startTime: '10:30', endTime: '17:00', address: 'Shop 12, Corporate Road, Prahlad Nagar' }, description: 'Grow our supplier network across Ahmedabad. Freshers welcome — walk in today.' },
    ],
  },
  {
    email: `vikram.shah@${DEMO_DOMAIN}`, hrName: 'Vikram Shah', designation: 'Founder',
    company: { name: 'Northwind Analytics', industry: 'Software', size: '11-50', website: 'https://northwind.example.com' },
    where: ['SG Highway', 'Ahmedabad'], hiring: ['JT_060', 'JT_008'],
    jobs: [
      { titleCode: 'JT_060', workMode: 'onsite', openings: 2, experienceLevel: 'lt_1', salaryMin: 30000, salaryMax: 40000, description: 'Build dashboards in Power BI and SQL for retail clients.' },
      { titleCode: 'JT_008', workMode: 'hybrid', openings: 1, experienceLevel: '3_5', salaryMin: 90000, salaryMax: 130000, description: 'Node.js and React across our analytics platform.' },
    ],
  },
];

const CANDIDATES = [
  { email: `priya.kulkarni@${DEMO_DOMAIN}`, name: 'Priya Kulkarni', titles: ['JT_042', 'JT_040'], experienceLevel: '2_3', workModes: ['onsite', 'hybrid'], where: ['Jayanagar', 'Bengaluru'], live: true, skills: ['Zendesk', 'Customer support', 'Excel'], openToWork: 'actively_looking' },
  { email: `nikhil.tandon@${DEMO_DOMAIN}`, name: 'Nikhil Tandon', titles: ['JT_045'], experienceLevel: 'lt_1', workModes: ['onsite'], where: ['Bellandur', 'Bengaluru'], live: false, skills: ['Hindi', 'Kannada', 'Voice process'], openToWork: 'actively_looking' },
  { email: `ananya.mehta@${DEMO_DOMAIN}`, name: 'Ananya Mehta', titles: ['JT_049', 'JT_040'], experienceLevel: '3_5', workModes: ['hybrid'], where: ['Vastrapur', 'Ahmedabad'], live: true, skills: ['SAP MM', 'Tally', 'Process mapping'], openToWork: 'open_to_opportunities' },
  { email: `rohan.desai@${DEMO_DOMAIN}`, name: 'Rohan Desai', titles: ['JT_091', 'JT_090'], experienceLevel: 'fresher', workModes: ['onsite'], where: ['Satellite', 'Ahmedabad'], live: true, skills: ['Gujarati', 'Field sales'], openToWork: 'actively_looking' },
  { email: `sana.khan@${DEMO_DOMAIN}`, name: 'Sana Khan', titles: ['JT_060', 'JT_064'], experienceLevel: '1_2', workModes: ['remote', 'hybrid'], where: ['Koramangala', 'Bengaluru'], live: false, skills: ['SQL', 'Power BI', 'Python'], openToWork: 'open_to_opportunities' },
  { email: `karthik.rao@${DEMO_DOMAIN}`, name: 'Karthik Rao', titles: ['JT_004', 'JT_012'], experienceLevel: '2_3', workModes: ['remote'], where: ['HSR Layout', 'Bengaluru'], live: false, skills: ['Flutter', 'Dart', 'Firebase'], openToWork: 'actively_looking' },
];

async function createUser(email, role) {
  const user = new User({ email, role, isEmailVerified: true, emailVerifiedAt: new Date(), onboardingStage: 'complete' });
  await user.setPassword(DEMO_PASSWORD);
  await user.save();
  return user;
}

/** Idempotent: does nothing if the demo accounts already exist. */
async function seedDemo() {
  if (await User.exists({ email: RECRUITERS[0].email })) {
    return { created: false };
  }

  let jobCount = 0;
  for (const spec of RECRUITERS) {
    const user = await createUser(spec.email, 'recruiter');
    const hiringLocation = buildLocation(place(...spec.where), { defaultRadiusKm: 0.5 });
    const company = await Company.create({
      ...spec.company,
      slug: Company.toSlug(spec.company.name),
      createdBy: user._id,
      officeLocations: [hiringLocation],
    });
    const hiringProfiles = await resolveTitleCodes(spec.hiring);
    await RecruiterProfile.create({
      userId: user._id,
      companyId: company._id,
      companyName: company.name,
      hrName: spec.hrName,
      email: spec.email,
      designation: spec.designation,
      isOfficialEmailDomain: true,
      hiringProfiles,
      hiringWorkModes: ['onsite', 'hybrid'],
      hiringLocations: [hiringLocation],
      hiringRadiusKm: 10,
      profileCompletion: 88,
    });

    for (const job of spec.jobs) {
      const [title] = await resolveTitleCodes([job.titleCode]);
      await Job.create({
        recruiterUserId: user._id,
        companyId: company._id,
        companyName: company.name,
        postedByName: spec.hrName,
        title,
        description: job.description,
        experienceLevel: job.experienceLevel,
        workMode: job.workMode,
        openings: job.openings,
        salaryMin: job.salaryMin,
        salaryMax: job.salaryMax,
        isWalkIn: Boolean(job.isWalkIn),
        walkIn: job.isWalkIn
          ? { ...job.walkIn, date: daysFromNow(job.walkIn.day) }
          : undefined,
        location: hiringLocation,
      });
      jobCount += 1;
    }
  }

  const endOfToday = new Date();
  endOfToday.setHours(23, 59, 59, 999);

  for (const spec of CANDIDATES) {
    const user = await createUser(spec.email, 'candidate');
    const jobTitles = await resolveTitleCodes(spec.titles);
    await CandidateProfile.create({
      userId: user._id,
      name: spec.name,
      email: spec.email,
      headline: jobTitles[0].name,
      jobTitles,
      experienceLevel: spec.experienceLevel,
      workModes: spec.workModes,
      openToWork: spec.openToWork,
      profileVisibility: 'recruiters_only',
      skills: spec.skills,
      availableUntil: spec.live ? endOfToday : null,
      location: buildLocation(place(...spec.where), { defaultRadiusKm: 2 }),
      profileCompletion: 100,
    });
  }

  return { created: true, recruiters: RECRUITERS.length, candidates: CANDIDATES.length, jobs: jobCount };
}

if (require.main === module) {
  const env = require('../config/env');
  const { connectDatabase } = require('../config/db');
  (async () => {
    if (env.nodeEnv === 'production') {
      console.error('Refusing to seed demo data in production.');
      process.exit(1);
    }
    await connectDatabase();
    const summary = await seedDemo();
    console.log(summary.created ? `Demo data created: ${JSON.stringify(summary)}` : 'Demo data already present.');
    await mongoose.disconnect();
  })().catch((err) => {
    console.error('Demo seeding failed:', err.message);
    process.exit(1);
  });
}

module.exports = { seedDemo, DEMO_PASSWORD, DEMO_DOMAIN };
