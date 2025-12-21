# Habit Tracker (Rails)

A Hotwire-first habit tracker focused on **time spent** (duration), not just completion.

## Features

- **Habits**: CRUD for habits (name, description, active, color)
- **Daily logs**: one log per habit per day, tracking `duration_minutes` (+ optional notes)
- **Dashboard analytics**: totals for today / week / month / all-time, plus per-habit rollups
- **UI**: neobrutalist styling (bold colors, thick borders, big shadows)

## Requirements

- Ruby (Rails 8.1)
- SQLite

## Setup

```bash
bundle install
bin/rails db:prepare
```

## Run (development)

```bash
bin/dev
```

Then visit `http://localhost:3000`.

## Test

```bash
bin/rails test
```

## Notes

- Logs are unique per `(habit_id, logged_on)` so logging the same day will update that day’s entry.
