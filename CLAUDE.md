# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Development server (Rails + Tailwind watcher)
bin/dev

# Run all tests
bin/rails test

# Run a single test file
bin/rails test test/models/habit_test.rb

# Run a specific test by line number
bin/rails test test/models/habit_test.rb:10

# Run system tests (requires browser)
bin/rails test:system

# Linting
bin/rubocop
bin/rubocop -a  # auto-fix

# Security scanning
bin/brakeman --no-pager
bin/bundler-audit

# Database
bin/rails db:prepare
bin/rails db:migrate
```

## Architecture

Rails 8.1 Hotwire-first habit tracker focused on duration/time tracking (not just completion).

### Models

- **Habit**: name, description, color, active flag. Has many HabitLogs.
- **HabitLog**: Time blocks with `start_hour`/`end_hour` (decimal 0-24, supports half-hours like 9.5). One habit can have multiple logs per day. Scopes: `for_date(date)`, `ordered_by_time`, `most_recent_first`.

### Key Patterns

- **Time blocks**: HabitLogs use decimal hours (9.5 = 9:30am, 14.0 = 2pm). Duration calculated as `end_hour - start_hour`.
- **Turbo Streams**: Controllers render turbo_stream responses for AJAX updates (flash messages, form resets, list refreshes).
- **Dashboard**: Shows today's timeline of logged time blocks with aggregate stats (today/week/all-time hours).

### Routes

- `GET /` → Dashboard (timeline view)
- `resources :habits` → CRUD for habits
- `resources :habits/:habit_id/logs` → Nested logs management
- `POST /habit_logs` → Standalone create for dashboard timeline

### Frontend

- Tailwind CSS with neobrutalist styling (bold colors, thick borders, shadows)
- Stimulus controllers in `app/javascript/controllers/`
- Importmap for JS dependencies (no Node/npm)
