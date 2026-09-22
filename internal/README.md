# Internal AWS Workshop

A two-day, hands-on workshop. Over both days you build the same small piece of infrastructure twice - first by clicking through the AWS console, then by describing it in Terraform.

| | Day 1 | Day 2 |
|---|---|---|
| **How** | AWS Management Console, plus the AWS CLI to inspect what you built | Terraform |
| **You learn** | What the services are, where they live, what they are called | How to describe the same thing in code and deploy it repeatably |
| **Result** | A working API, built by hand | The same working API, built from a file you can hand to a colleague |
| **Guide** | [day1/README.md](day1/README.md) | [day2/README.md](day2/README.md) |

Day 1 does not need Day 2, but Day 2 leans on Day 1 throughout: every Terraform resource is introduced as "this is the thing you clicked yesterday".

---

## What we build

A **Feedback Portal** - the backend of a team retro board. Someone submits feedback over HTTP, it lands in S3 as a JSON file, and can be read back.

```
   ┌──────────┐   ① POST /feedback    ┌─────────────────────┐
   │   curl   │ ────────────────────► │     API Gateway     │
   │    or    │                       │      (HTTP API)     │
   │  browser │ ◄──────────────────── └──────────┬──────────┘
   └──────────┘   ④ { "id": "…" }                │
                                                 │ ② invoke
                                                 ▼
                                      ┌─────────────────────┐
                                      │       Lambda        │
                                      │     handler.py      │
                                      └──────────┬──────────┘
                                                 │
                                                 │ ③ PutObject
                                                 ▼
                                      ┌─────────────────────┐
                                      │         S3          │
                                      │ feedback/<id>.json  │
                                      └─────────────────────┘
```

Three endpoints:

| Method | Path | Does |
|---|---|---|
| `POST` | `/feedback` | Store new feedback (`team`, `rating` 1-5, `comment`) and return its id |
| `GET` | `/feedback` | List all feedback, newest first |
| `GET` | `/feedback/{id}` | Read one piece of feedback |

The same `handler.py` runs on both days. On Day 1 you paste it into the console editor, on Day 2 Terraform zips and uploads it.

---

## Account access

| | |
|---|---|
| SSO start URL | https://nl.awsapps.com/start/#/ |
| Account | `654654436000` |
| Permission set | `WriteAccess` |
| Region | `eu-west-1` (Ireland) |

Everyone works in the **same** account. That is why every resource name ends in your first name - `nl-dev-feedback-manual-tino`, not `feedback-bucket`. Day 1 resources use `manual`, Day 2 resources use `tf`, so both sets can exist side by side and you can compare them.

---

## Costs

Everything here is either free-tier or fractions of a cent: S3 storage for a handful of small JSON files, a few dozen Lambda invocations, a few dozen API Gateway requests. There is no always-on compute and no database.

Still, clean up at the end of Day 2 - see the cleanup section in each day's guide.

---

## Repository layout

```
internal/
├── README.md                    ← you are here
├── day1/
│   ├── README.md                ← Day 1 guide (console)
│   └── lambda-src/handler.py    ← the code you paste into the console
└── day2/
    ├── README.md                ← Day 2 guide (Terraform)
    ├── docs/
    │   ├── cheatsheet.md        ← Terraform and AWS CLI commands
    │   └── best-practices.md    ← what we deliberately did not do
    ├── lambda-src/api/handler.py
    ├── terraform/               ← your working directory on Day 2
    └── solutions/               ← the finished .tf files
```
