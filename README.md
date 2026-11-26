# V Templates – Volamp HR Letter Studio

Online HR letter generator for Volamp Elektrikals Pvt. Ltd.
Offer, appointment, confirmation, increment, promotion, transfer, warning, show cause, termination,
resignation acceptance, relieving, experience, salary certificate, NOC and internship letters –
with approved templates, signatures, stamps, an employee list and a numbered letter register.

## How it is built
| Layer    | Tool                          |
|----------|-------------------------------|
| Frontend | `index.html` (HTML + JavaScript) |
| Hosting  | Vercel (auto-deploys from this GitHub repo) |
| Database | Supabase (PostgreSQL) + Supabase Auth login |

## Files
- `index.html` – the complete app
- `supabase-setup.sql` – creates all database tables, security rules and the reference-number function

## Setup (one time)
1. **Supabase** → New project → SQL Editor → paste `supabase-setup.sql` → Run.
2. **Supabase** → Authentication → Sign In / Providers → turn **OFF** "Allow new users to sign up".
3. **Supabase** → Authentication → Users → Add user → Create new user (tick Auto Confirm) for each HR person.
4. **Supabase** → Connect (top bar) or Project Settings → API Keys → copy the **Project URL** and the **publishable / anon key**.
5. Paste both at the top of the `<script>` section in `index.html`, commit to GitHub.
6. **Vercel** → Add New → Project → import this repo → Deploy.

Every change committed to GitHub goes live on Vercel automatically in about a minute.

## Database tables
| Table        | What it stores |
|--------------|----------------|
| settings     | Letterhead details, logo, reference prefix, next letter number |
| signatories  | Authorised signatories with signature and stamp images |
| templates    | Letter templates with approval status |
| employees    | Employee master |
| letters      | Register of every letter issued (ref no., details, who issued it) |

Note: the publishable/anon key is safe to keep in the code – Row Level Security only allows logged-in users
to read or write data, and public sign-up is switched off.
