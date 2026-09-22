/* eslint-disable no-console */
'use strict';

/**
 * End-to-end check of the jobs, discovery, saved, connections and chat APIs
 * against a running server seeded with demo data (`npm run dev:memory`).
 *
 *   node scripts/api-smoke-test.js
 */

const BASE = process.env.API_BASE || 'http://localhost:4000/api/v1';
const PASSWORD = 'Demo@1234';
const DOMAIN = 'demo.talentradar.app';

let pass = 0;
let fail = 0;
const bodies = [];

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
  bodies.push(JSON.stringify(json));
  return { status: res.status, json, data: json.data };
}

function check(label, condition, extra) {
  if (condition) {
    pass += 1;
    console.log(`  PASS  ${label}`);
  } else {
    fail += 1;
    console.log(`  FAIL  ${label}${extra !== undefined ? ` -> ${JSON.stringify(extra).slice(0, 400)}` : ''}`);
  }
}

async function login(name) {
  const res = await call('POST', '/auth/login', { email: `${name}@${DOMAIN}`, password: PASSWORD });
  if (res.status !== 200) throw new Error(`login ${name} failed: ${JSON.stringify(res.json)}`);
  return { token: res.data.token, userId: res.data.user.userId };
}

(async () => {
  const priya = await login('priya.kulkarni'); // candidate, Jayanagar, Bengaluru
  const karthik = await login('karthik.rao'); // candidate, HSR Layout
  const riya = await login('riya.joshi'); // recruiter, HSR Layout
  const arjun = await login('arjun.menon'); // recruiter, Koramangala

  console.log('\n== Jobs tab (candidate) ==');
  const jobs = await call('GET', '/jobs', null, priya.token);
  check('lists open jobs', jobs.status === 200 && jobs.data.jobs.length > 0, jobs.json);
  const cities = new Set(jobs.data.jobs.filter((job) => job.workMode !== 'remote').map((job) => job.location.city));
  check('nearby jobs are local only (Bengaluru)', cities.size === 1 && cities.has('Bengaluru'), [...cities]);
  const distances = jobs.data.jobs.filter((job) => job.workMode !== 'remote').map((job) => job.distanceKm);
  check('nearby jobs sorted nearest first', distances.every((d, i) => i === 0 || d >= distances[i - 1]), distances);
  check('remote roles included after local ones', jobs.data.jobs.some((job) => job.workMode === 'remote'));
  check('meta reports nearby count and location', jobs.data.meta.hasLocation === true && jobs.data.meta.nearbyCount > 0, jobs.data.meta);
  const walkIn = jobs.data.jobs.find((job) => job.walkInToday);
  check('walk-in today flagged', Boolean(walkIn), jobs.data.jobs.map((j) => j.title.name));
  check('profile-matching title flagged', jobs.data.jobs.some((job) => job.matchesProfile));

  const walkins = await call('GET', '/jobs?filter=walkins', null, priya.token);
  check('walk-ins filter', walkins.data.jobs.length > 0 && walkins.data.jobs.every((job) => job.isWalkIn));
  const remote = await call('GET', '/jobs?filter=remote', null, priya.token);
  check('remote filter', remote.data.jobs.length > 0 && remote.data.jobs.every((job) => job.workMode === 'remote'));
  const search = await call('GET', '/jobs?q=support', null, priya.token);
  check('search by title', search.data.jobs.length > 0 && search.data.jobs.every((job) => /support/i.test(job.title.name + job.companyName + job.title.category)), search.data.jobs.map((j) => j.title.name));

  const detail = await call('GET', `/jobs/${walkIn.jobId}`, null, priya.token);
  check('job detail with poster', detail.status === 200 && detail.data.postedBy.name === 'Riya Joshi', detail.json);

  console.log('\n== Saved ==');
  await call('PUT', '/saved', { kind: 'job', refId: walkIn.jobId }, priya.token);
  let saved = await call('GET', '/saved', null, priya.token);
  check('job saved', saved.data.jobs.some((job) => job.jobId === walkIn.jobId));
  const again = await call('GET', '/jobs', null, priya.token);
  check('jobs list shows saved flag', again.data.jobs.find((job) => job.jobId === walkIn.jobId).saved === true);
  await call('DELETE', `/saved/job/${walkIn.jobId}`, null, priya.token);
  saved = await call('GET', '/saved', null, priya.token);
  check('job unsaved', !saved.data.jobs.some((job) => job.jobId === walkIn.jobId));
  const badSave = await call('PUT', '/saved', { kind: 'job', refId: 'nope' }, priya.token);
  check('bad reference rejected', badSave.status === 422);

  console.log('\n== I\'m interested -> chat ==');
  const interest = await call('POST', `/jobs/${walkIn.jobId}/interest`, null, priya.token);
  check('interest recorded and chat opened', interest.status === 201 && Boolean(interest.data.conversationId), interest.json);
  const twice = await call('POST', `/jobs/${walkIn.jobId}/interest`, null, priya.token);
  check('second tap is idempotent', twice.status === 200 && twice.data.alreadyInterested === true && twice.data.conversationId === interest.data.conversationId);
  const riyaBadges = await call('GET', '/me/badges', null, riya.token);
  check('recruiter has an unread chat', riyaBadges.data.unreadChats === 1, riyaBadges.data);
  const riyaConvos = await call('GET', '/conversations', null, riya.token);
  const convo = riyaConvos.data.conversations.find((c) => c.conversationId === interest.data.conversationId);
  check('recruiter sees conversation with candidate', convo?.person?.name === 'Priya Kulkarni' && convo.unreadCount === 1, riyaConvos.data);
  const interests = await call('GET', `/jobs/${walkIn.jobId}/interests`, null, riya.token);
  check('recruiter sees interested candidate', interests.data.candidates.some((c) => c.name === 'Priya Kulkarni'));
  const notOwner = await call('GET', `/jobs/${walkIn.jobId}/interests`, null, arjun.token);
  check('other recruiter cannot see interests', notOwner.status === 404);

  console.log('\n== Messages & interview invite ==');
  const convoId = interest.data.conversationId;
  const msgs = await call('GET', `/conversations/${convoId}/messages`, null, riya.token);
  check('auto intro message present', msgs.data.messages.length === 1 && /interested/.test(msgs.data.messages[0].text));
  const readBadges = await call('GET', '/me/badges', null, riya.token);
  check('reading clears unread', readBadges.data.unreadChats === 0, readBadges.data);
  const reply = await call('POST', `/conversations/${convoId}/messages`, { text: 'Hi Priya, can you come in today?' }, riya.token);
  check('recruiter replies', reply.status === 201);
  const empty = await call('POST', `/conversations/${convoId}/messages`, { text: '   ' }, riya.token);
  check('empty message rejected', empty.status === 422);
  const tomorrow = new Date(Date.now() + 24 * 3600 * 1000).toISOString();
  const invite = await call('POST', `/conversations/${convoId}/invites`, { title: 'Customer Support Executive', round: 'Round 1', scheduledAt: tomorrow, mode: 'in_person', location: 'HSR Layout office' }, riya.token);
  check('recruiter sends interview invite', invite.status === 201 && invite.data.message.invite.status === 'pending', invite.json);
  const candInvite = await call('POST', `/conversations/${convoId}/invites`, { title: 'x x', scheduledAt: tomorrow }, priya.token);
  check('candidate cannot send invites', candInvite.status === 403);
  const selfRespond = await call('POST', `/messages/${invite.data.message.messageId}/invite-response`, { action: 'accept' }, riya.token);
  check('sender cannot answer own invite', selfRespond.status === 400);
  const accept = await call('POST', `/messages/${invite.data.message.messageId}/invite-response`, { action: 'accept' }, priya.token);
  check('candidate accepts invite', accept.data?.message?.invite?.status === 'accepted', accept.json);
  const after = await call('GET', `/conversations/${convoId}/messages?after=${encodeURIComponent(reply.data.message.createdAt)}`, null, priya.token);
  check('polling returns only newer messages incl. system note', after.data.messages.length === 2 && after.data.messages[1].kind === 'system', after.data.messages.map((m) => m.kind));
  const outsider = await call('GET', `/conversations/${convoId}/messages`, null, karthik.token);
  check('non-participant cannot read chat', outsider.status === 404);

  console.log('\n== Talent near you (recruiter) ==');
  const nearby = await call('GET', '/candidates/nearby', null, riya.token);
  const names = nearby.data.candidates.map((c) => c.name);
  check('finds nearby Bengaluru candidates', names.includes('Priya Kulkarni') && names.includes('Karthik Rao'), names);
  check('excludes Ahmedabad candidates', !names.includes('Ananya Mehta') && !names.includes('Rohan Desai'), names);
  check('distance rounded to 0.5 km', nearby.data.candidates.every((c) => c.distanceKm === null || (c.distanceKm * 2) % 1 === 0), nearby.data.candidates.map((c) => c.distanceKm));
  check('available-today count', nearby.data.meta.availableToday >= 1, nearby.data.meta);
  const liveOnly = await call('GET', '/candidates/nearby?availableToday=true', null, riya.token);
  check('available-today filter', liveOnly.data.candidates.every((c) => c.availableToday));
  const match = await call('GET', '/candidates/nearby?matchOnly=true', null, riya.token);
  check('match-only filter', match.data.candidates.length > 0 && match.data.candidates.every((c) => c.matchesHiring));
  const candNearby = await call('GET', '/candidates/nearby', null, priya.token);
  check('candidates cannot browse candidates', candNearby.status === 403);

  console.log('\n== Quick profile & insights ==');
  const quick = await call('GET', `/candidates/${priya.userId}`, null, riya.token);
  check('recruiter opens quick profile', quick.status === 200 && quick.data.candidate.skills.includes('Zendesk') && quick.data.candidate.canMessage === true, quick.json);
  const insights = await call('GET', '/candidates/me/insights', null, priya.token);
  check('profile view counted', insights.data.recruitersViewedLast3Days === 1, insights.data);
  await call('GET', `/candidates/${priya.userId}`, null, riya.token);
  const insights2 = await call('GET', '/candidates/me/insights', null, priya.token);
  check('repeat views same day not double-counted', insights2.data.recruitersViewedLast3Days === 1);
  const peer = await call('GET', `/candidates/${priya.userId}`, null, karthik.token);
  check('candidate cannot view recruiters-only candidate', peer.status === 404);

  console.log('\n== Go live & privacy ==');
  const off = await call('PUT', '/candidates/me/availability', { available: false }, karthik.token);
  check('go offline', off.data.profile.availableToday === false);
  const on = await call('PUT', '/candidates/me/availability', { available: true }, karthik.token);
  check('go live (available today)', on.data.profile.availableToday === true);
  const stealth = await call('PUT', '/candidates/me/privacy', { stealthMode: true }, priya.token);
  check('stealth on', stealth.data.profile.stealthMode === true && stealth.data.profile.availableToday === false, stealth.data.profile);
  const hidden = await call('GET', '/candidates/nearby', null, riya.token);
  check('stealth candidate hidden from radar', !hidden.data.candidates.some((c) => c.name === 'Priya Kulkarni'));
  const hiddenProfile = await call('GET', `/candidates/${priya.userId}`, null, arjun.token);
  check('stealth candidate profile hidden', hiddenProfile.status === 404);
  const notLooking = await call('PUT', '/candidates/me/privacy', { stealthMode: false, openToWork: 'not_looking' }, priya.token);
  check('"not looking" forces stealth back on', notLooking.data.profile.stealthMode === true);
  await call('PUT', '/candidates/me/privacy', { stealthMode: false, openToWork: 'actively_looking' }, priya.token);
  const closed = await call('PUT', '/candidates/me/privacy', { openToConnect: false }, karthik.token);
  check('open-to-connect off', closed.data.profile.openToConnect === false);
  const blocked = await call('POST', '/conversations', { participantId: karthik.userId }, arjun.token);
  check('recruiter cannot message closed candidate', blocked.status === 403, blocked.json);
  await call('PUT', '/candidates/me/privacy', { openToConnect: true }, karthik.token);

  console.log('\n== Connections ==');
  const request = await call('POST', '/connections', { recipientId: karthik.userId, message: 'Hi Karthik, we have a Flutter role.' }, arjun.token);
  check('recruiter sends connection request', request.status === 201 && request.data.status === 'pending_sent', request.json);
  const incoming = await call('GET', '/connections', null, karthik.token);
  const pending = incoming.data.incoming.find((item) => item.person.name === 'Arjun Menon');
  check('candidate sees incoming request with note', Boolean(pending) && /Flutter/.test(pending.message), incoming.data);
  const badges = await call('GET', '/me/badges', null, karthik.token);
  check('pending request counted in badge', badges.data.pendingRequests === 1);
  const accepted = await call('POST', `/connections/${pending.connectionId}/respond`, { action: 'accept' }, karthik.token);
  check('accept opens a conversation', accepted.data.status === 'accepted' && Boolean(accepted.data.conversationId));
  const firstMsg = await call('GET', `/conversations/${accepted.data.conversationId}/messages`, null, karthik.token);
  check('request note becomes first message', firstMsg.data.messages[0]?.text.includes('Flutter'));
  const self = await call('POST', '/connections', { recipientId: karthik.userId }, karthik.token);
  check('cannot connect with self', self.status === 400);

  console.log('\n== Post a role (recruiter) ==');
  const today = new Date().toISOString().slice(0, 10);
  const posted = await call('POST', '/jobs', { titleCode: 'JT_045', workMode: 'onsite', openings: 6, experienceLevel: 'fresher', salaryMin: 18000, salaryMax: 22000, isWalkIn: true, walkIn: { date: today, startTime: '09:30', endTime: '13:00' }, description: 'Voice process, Kannada preferred.' }, riya.token);
  check('recruiter posts a walk-in', posted.status === 201 && posted.data.job.walkInToday === true && posted.data.job.walkIn.address.length > 0, posted.json);
  const past = await call('POST', '/jobs', { titleCode: 'JT_045', workMode: 'onsite', isWalkIn: true, walkIn: { date: '2020-01-01', startTime: '09:30', endTime: '13:00' } }, riya.token);
  check('past walk-in date rejected', past.status === 422 && past.json.error.details.some((d) => d.field === 'walkIn.date'), past.json);
  const badTimes = await call('POST', '/jobs', { titleCode: 'JT_045', workMode: 'onsite', isWalkIn: true, walkIn: { date: today, startTime: '14:00', endTime: '13:00' } }, riya.token);
  check('end before start rejected', badTimes.status === 422);
  const badSalary = await call('POST', '/jobs', { titleCode: 'JT_045', workMode: 'onsite', salaryMin: 50000, salaryMax: 20000 }, riya.token);
  check('min > max salary rejected', badSalary.status === 422);
  const candPost = await call('POST', '/jobs', { titleCode: 'JT_045', workMode: 'onsite' }, priya.token);
  check('candidates cannot post roles', candPost.status === 403);
  const seen = await call('GET', '/jobs?filter=walkins', null, karthik.token);
  check('new walk-in visible to nearby candidate', seen.data.jobs.some((job) => job.jobId === posted.data.job.jobId));
  const mine = await call('GET', '/recruiters/me/jobs', null, riya.token);
  check('recruiter sees own roles', mine.data.jobs.some((job) => job.jobId === posted.data.job.jobId));
  await call('PATCH', `/jobs/${posted.data.job.jobId}/status`, { status: 'closed' }, riya.token);
  const gone = await call('GET', '/jobs?filter=walkins', null, karthik.token);
  check('closed role leaves the listings', !gone.data.jobs.some((job) => job.jobId === posted.data.job.jobId));
  const hijack = await call('PATCH', `/jobs/${posted.data.job.jobId}/status`, { status: 'open' }, arjun.token);
  check('another recruiter cannot reopen it', hijack.status === 404);

  console.log('\n== Profile editing ==');
  const edit = await call('PUT', '/candidates/me/profile', { headline: 'Support lead in the making', skills: ['Zendesk', 'Freshdesk', 'Zendesk'] }, priya.token);
  check('candidate edits headline and skills (deduped)', edit.data.profile.headline === 'Support lead in the making' && edit.data.profile.skills.length === 2, edit.data.profile);
  const company = await call('PUT', '/companies/mine', { industry: 'Customer Experience', size: '201-500', website: 'https://brightdesk.example.com', description: 'Support for consumer apps.' }, riya.token);
  check('recruiter completes company profile', company.status === 200 && company.data.companyDetails.description.length > 0, company.json);
  const badSite = await call('PUT', '/companies/mine', { website: 'not a url' }, riya.token);
  check('invalid website rejected', badSite.status === 422);

  console.log('\n== Search: who is hiring for this role? ==');
  const all = await call('GET', '/search?q=support', null, priya.token);
  check('candidate search returns jobs, companies and recruiters',
    all.status === 200 && ['jobs', 'companies', 'recruiters'].every((key) => key in all.data.results), all.json);
  check('candidate is not offered a candidate search', !('candidates' in all.data.results), Object.keys(all.data.results));

  const hiringRecruiters = await call('GET', '/search?q=support&type=recruiters', null, priya.token);
  const found = hiringRecruiters.data.results.recruiters[0];
  check('recruiter result says who is hiring and for what',
    Boolean(found && found.hiringNow && found.totalOpenings > 0 && found.openRoles.length > 0), found);
  check('recruiter result carries the ids needed to open it',
    Boolean(found && found.userId && found.companyId && found.openRoles[0].jobId), found);
  check('recruiter result has no personal location, only a hiring area',
    Boolean(found) && !('precise' in found) && typeof found.area === 'string', found);

  const companies = await call('GET', '/search?q=support&type=companies', null, priya.token);
  check('companies hiring for the role are found', companies.data.results.companies.some((item) => item.hiringNow), companies.data.results.companies);

  const byTitle = await call('GET', '/search?type=recruiters&titleCode=JT_042', null, priya.token);
  check('search by job-title code works', byTitle.status === 200 && byTitle.data.counts.recruiters >= 1, byTitle.json);
  const noMatch = await call('GET', '/search?q=zzzzzzzz&type=companies', null, priya.token);
  check('a narrowed search that matches nothing returns nothing', noMatch.data.counts.companies === 0, noMatch.data.counts);

  console.log('\n== Search: who can do this job? (recruiter) ==');
  const people = await call('GET', '/search?type=candidates&q=support', null, riya.token);
  check('recruiter searches candidates', people.status === 200 && people.data.results.candidates.length > 0, people.json);
  check('candidate results carry skills and connection state',
    people.data.results.candidates.every((card) => Array.isArray(card.skills) && typeof card.connectionStatus === 'string'));
  const bySkill = await call('GET', '/search?type=candidates&skill=Zendesk', null, riya.token);
  check('filter by skill narrows the result', bySkill.data.counts.candidates < people.data.counts.candidates + 1, bySkill.data.counts);
  const recruiterTypes = await call('GET', '/search?type=companies', null, riya.token);
  check('a recruiter asking for companies gets their own allowed types',
    !('companies' in recruiterTypes.data.results), Object.keys(recruiterTypes.data.results));

  console.log('\n== Recruiter and company profiles ==');
  const profile = await call('GET', `/recruiters/${riya.userId}`, null, priya.token);
  check('candidate can open a recruiter profile', profile.status === 200 && profile.data.recruiter.name.length > 0, profile.json);
  check('profile lists declared roles with their live state',
    profile.data.roles.length > 0 && profile.data.roles.some((role) => role.hiringNow), profile.data.roles);
  check('a candidate may always message a recruiter', profile.data.canMessage === true);
  const companyId = profile.data.recruiter.companyId;
  const companyView = await call('GET', `/companies/${companyId}`, null, priya.token);
  check('company profile lists open roles and who to ask',
    companyView.status === 200 && companyView.data.jobs.length > 0 && companyView.data.recruiters.length > 0, companyView.json);
  const missing = await call('GET', '/recruiters/000000000000000000000000', null, priya.token);
  check('an unknown recruiter is a clean 404', missing.status === 404, missing.json);

  console.log('\n== Hiring status is derived, never stored twice ==');
  const liveJob = (await call('GET', '/recruiters/me/jobs', null, riya.token))
    .data.jobs.find((job) => job.status === 'open');
  const beforeClose = await call('GET', `/recruiters/${riya.userId}`, null, priya.token);
  const openingsBefore = beforeClose.data.totalOpenings;
  await call('PATCH', `/jobs/${liveJob.jobId}/status`, { status: 'closed' }, riya.token);
  const afterClose = await call('GET', `/recruiters/${riya.userId}`, null, priya.token);
  check('closing a role lowers the openings on the profile',
    afterClose.data.totalOpenings === openingsBefore - liveJob.openings,
    { openingsBefore, after: afterClose.data.totalOpenings, closed: liveJob.openings });
  const afterSearch = await call('GET', `/search?type=recruiters&q=${encodeURIComponent(liveJob.title.name)}`, null, priya.token);
  const stillListed = afterSearch.data.results.recruiters.find((item) => item.userId === riya.userId);
  check('the closed title is no longer offered as hiring in search',
    !stillListed || !stillListed.openRoles.some((role) => role.code === liveJob.title.code),
    stillListed && stillListed.openRoles);
  const afterCompany = await call('GET', `/companies/${companyId}`, null, priya.token);
  check('the company profile agrees with the recruiter profile',
    afterCompany.data.jobs.every((job) => job.jobId !== liveJob.jobId), afterCompany.data.jobs.length);
  await call('PATCH', `/jobs/${liveJob.jobId}/status`, { status: 'open' }, riya.token);
  const reopened = await call('GET', `/recruiters/${riya.userId}`, null, priya.token);
  check('reopening restores it everywhere', reopened.data.totalOpenings === openingsBefore, reopened.data.totalOpenings);

  console.log('\n== Blocking hides both ways ==');
  const blockRes = await call('PUT', '/blocks', { userId: riya.userId, blocked: true }, priya.token);
  check('candidate blocks a recruiter', blockRes.status === 200, blockRes.json);
  const blindSearch = await call('GET', '/search?q=support&type=recruiters', null, priya.token);
  check('the blocked recruiter is gone from my search',
    !blindSearch.data.results.recruiters.some((item) => item.userId === riya.userId));
  const blindProfile = await call('GET', `/recruiters/${riya.userId}`, null, priya.token);
  check('their profile is no longer reachable', blindProfile.status === 404, blindProfile.json);
  const theirSearch = await call('GET', '/search?type=candidates', null, riya.token);
  check('and I am gone from theirs, though they did not block me',
    !theirSearch.data.results.candidates.some((card) => card.userId === priya.userId));
  const blockedChat = await call('POST', '/conversations', { participantId: riya.userId }, priya.token);
  check('a blocked pair cannot open a chat', blockedChat.status === 403, blockedChat.json);
  const blockList = await call('GET', '/blocks', null, priya.token);
  check('the block is listed so it can be undone', blockList.data.blocked.some((row) => row.userId === riya.userId), blockList.json);
  await call('PUT', '/blocks', { userId: riya.userId, blocked: false }, priya.token);
  const restored = await call('GET', `/recruiters/${riya.userId}`, null, priya.token);
  check('unblocking restores visibility', restored.status === 200);
  const selfBlock = await call('PUT', '/blocks', { userId: priya.userId, blocked: true }, priya.token);
  check('you cannot block yourself', selfBlock.status === 400, selfBlock.json);

  console.log('\n== Reporting ==');
  const report = await call('POST', '/reports', { subjectKind: 'person', subjectId: riya.userId, reason: 'spam', details: 'Test report.' }, priya.token);
  check('a report is accepted', report.status === 201, report.json);
  const badReason = await call('POST', '/reports', { subjectKind: 'person', subjectId: riya.userId, reason: 'whatever' }, priya.token);
  check('an unknown reason is rejected', badReason.status === 422, badReason.json);

  console.log('\n== Privacy guarantee ==');
  const leaked = bodies.some((body) => body.includes('"coordinates"') || body.includes('"precise"'));
  check('no response in this run contained coordinates', !leaked);

  console.log(`\n=== ${pass} passed, ${fail} failed ===`);
  process.exit(fail === 0 ? 0 : 1);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
