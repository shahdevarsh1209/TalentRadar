# TalentRadar

Hyper-local professional networking and job discovery: registration, onboarding,
and the working app for both roles — candidate and HR / recruiter.

The Flutter app lives at the repository root.

```
lib/        Flutter app (Android first, iOS and web supported)
test/       Unit, widget, layout and end-to-end tests
```

> **The API lives in a separate repository.** This repo is the Flutter client
> only. The app talks to a Node.js + Express + MongoDB service that serves
> `/api/v1` — registration, job titles, jobs, discovery, chat and privacy. You
> need that service running for anything past the welcome screen to work.
> The `backend/` folder on a working copy is untracked here and is ignored by
> git; move it to its own repository before you lose it.

## Running it

```bash
flutter pub get
flutter run
```

The app points at `http://10.0.2.2:4000/api/v1` on the Android emulator and at
`http://localhost:4000/api/v1` everywhere else (including `flutter run -d chrome`).
Override that for a real device or a deployed API:

```bash
flutter run --dart-define=TR_API_BASE_URL=https://api.example.com/api/v1
```

Cleartext HTTP is allowed only for `10.0.2.2`, `localhost` and `127.0.0.1`
(`android/app/src/main/res/xml/network_security_config.xml`). Any other host must
use HTTPS.

### Demo data

The API seeds 4 recruiters (with 10 roles between them, including walk-ins) and
6 candidates across Bengaluru and Ahmedabad, so every screen has something real
to show. Every demo account's password is `Demo@1234`, for example
`riya.joshi@demo.talentradar.app` (recruiter) or
`priya.kulkarni@demo.talentradar.app` (candidate).

## User flows

```
Candidate:  Welcome → Join TalentRadar (role) → Candidate profile form
            → Verify email (OTP) → Discover opportunities near you (location)
            → Welcome to TalentRadar 👋 → Radar

Recruiter:  Welcome → Join TalentRadar (role) → Hiring profile form
            → Verify email (OTP) → Where are you hiring? (company location)
            → Your hiring profile is ready → Explore nearby talent
```

Required at registration. Everything else is left for profile completion.

| Candidate                               | HR / Recruiter                       |
| --------------------------------------- | ------------------------------------ |
| Full name, email, job title(s) (max 5), work mode(s) | Company name, HR name, email, hiring profile(s) (max 10) |
| Optional: password, experience, open-to-work, visibility | Optional: password, designation, work modes offered |

Once inside, the app is a working product for both roles:

| Tab | Candidate | Recruiter |
| --- | --- | --- |
| **Radar** | Nearby roles and walk-ins on a hatched area map; "N recruiters viewed you" | Nearby discoverable candidates on the same map, with filters |
| **Jobs / Roles** | Every open role nearby, filterable by walk-ins/remote, with search | Every role you have posted, with an interest count and Close/Reopen |
| **Search** | Three tabs — Jobs, Companies, Recruiters — so "who is hiring for this role?" is answerable | Candidates and Jobs, filterable by skill, availability and distance |
| **Centre button** | "I'm available today" — a lime dot until midnight | Post a role or walk-in interview |
| **Chats** | Conversations, polled live; interview invites with Accept/Reschedule/Decline | Same, plus sending interview invites |
| **Me** | Edit profile, area, saved items, Privacy & stealth mode, blocked accounts, Help Center | Edit hiring profile, company profile, hiring location, saved candidates, blocked accounts, Help Center |

Every person and company in the app opens their own page. Tapping a recruiter —
in a chat header, a search result, Saved, Requests, or the "Posted by" line on a
role — opens the **recruiter profile**: who they are, the roles they have open
right now with the number of seats, and Message / Connect / Save / Report /
Block. Their company name opens the **company profile**, with every open role
and the recruiters to ask about it. There are no cards that lead nowhere.

A candidate tapping **"I'm interested"** / **"Meet in person"** on a role opens a
chat with the recruiter, seeded with an automatic introduction. A recruiter's
**Message** / **Invite** on a candidate card does the same in the other direction.
Connection requests carry a note and, once accepted, open a chat too.

## Design decisions worth knowing

**Job titles come from a master list, not free text.** Profiles, job postings and
hiring profiles all store a code (`JT_001`) rather than typed text, so a
candidate's "Software Support Executive" and a recruiter's are the same record —
which is what job search, candidate search and the match flags all join on.

**Location has two tiers, everywhere it appears.** A device fix is never
serialised. The published point is offset within a privacy radius (2 km for
candidates), plus area words and a *rounded* distance. This applies to job
listings and the "Talent near you" radar as much as to registration — no API
response ever contains a candidate's coordinates, and the API test suites assert
this on every run.

**"Hiring Now" is derived, never stored.** A recruiter's declared hiring
profiles are what they say they recruit for; whether a title is *live* is worked
out from their open jobs each time it is asked for. Close the last role for a
title and it stops reading as active on the recruiter profile, the company
profile, search and the radar at the same moment. A title they have declared but
have nothing open for shows honestly under "Also recruits for".

**Search asks a different question for each role.** One endpoint serves both: a
candidate gets Jobs, Companies and Recruiters, a recruiter gets Candidates and
Jobs. Filters are part of the same query object on the client, so a filter cannot
be shown as applied without being in the request that ran. Typing is debounced.

**Availability, stealth and visibility are separate, composable switches.**
"I'm available today" clears itself after midnight. Stealth mode and "not
looking" both remove a candidate from recruiter discovery, and choosing "not
looking" switches stealth on. "Open to connect" is separate again: it controls
whether a recruiter can *message* a candidate at all, independent of whether
they can be found — turning it off on a still-discoverable profile answers
"found me, but won't reply".

**Blocking cuts both ways, in one place.** A block hides both people from each
other everywhere — search, radar, chat, saved — because the server applies it
before every other visibility rule rather than each screen filtering for itself.
It outranks an accepted connection, and neither side can tell from the other's
absence that it happened. It is undone from Me → Blocked accounts.

**Errors never leak.** Every API failure is `{ success: false, error: { code,
message, details } }` with presentable copy. The app switches on `code` (for
example `NETWORK_UNAVAILABLE`, `EMAIL_EXISTS`, `RATE_LIMITED`,
`HIRING_LOCATION_REQUIRED`) and never shows raw backend text.

## Tests

```bash
flutter analyze
flutter test                                   # unit, widget and layout tests

# End-to-end: drives the real UI against a running API
flutter test test/e2e --dart-define=TR_E2E=true
```

`test/home_layout_test.dart` and `test/discovery_layout_test.dart` render every
post-registration screen (both roles) at 320×568 and 412×892, at 1.0× and 1.3×
text scale, with deliberately long fake names, titles and companies, and fail on
any layout overflow. Shared fixtures live in `test/support/fakes.dart`.

The end-to-end suites drive the real widgets against the real API:
`home_flow_test.dart` saves a walk-in, expresses interest, chats, goes live,
toggles stealth, posts a role and sends and accepts an interview invite;
`discovery_flow_test.dart` follows the whole chain — search a role, see which
companies and recruiters are hiring for it, open the recruiter, open their
company, message them, and reopen their profile from the chat header.

## Not built yet

- **Real email delivery.** Verification codes are returned by the API in
  development and shown in the app; wire a mail provider before production.
- **Google, phone OTP and forgot-password.** The buttons are present and show a
  "coming soon" message.
- **Company verification.** The status field and copy exist; there is no review
  workflow behind it.
- **Places API.** Manual location uses a fixed list of ~15 Indian cities with
  hand-set coordinates. The response shape stays the same when a real places
  provider replaces it.
- **Live push for chat.** Messages are polled every 4 seconds while a chat is
  open, and the nav badge every 20 seconds — simple and reliable, but not a
  socket. Swapping one in only touches `ChatScreen` and `badgesProvider`.
- **Events / meetups.** Designed but not built.
- **A notifications centre.** The nav badges are real; there is no list, no read
  state for it, and no push delivery.
- **Delete account.** Not implemented. Logging out is the only exit.
