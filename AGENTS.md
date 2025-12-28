# AGENTS.md

Guidelines for AI coding agents working in this Rails 8.1 habit-tracking application.

## Commands

```bash
# Development
bin/dev                    # Start Rails + Tailwind watcher

# Testing
bin/rails test             # Run all tests
bin/rails test test/models/habit_test.rb           # Single test file
bin/rails test test/models/habit_test.rb:10        # Specific test by line
bin/rails test:system      # System tests (requires browser)

# Linting
bin/rubocop                # Check style
bin/rubocop -a             # Auto-fix violations

# Security
bin/brakeman --no-pager    # Static analysis for vulnerabilities
bin/bundler-audit          # Check gems for known CVEs

# Database
bin/rails db:prepare       # Create/migrate as needed
bin/rails db:migrate       # Run pending migrations
```

## Architecture Overview

Hotwire-first app for tracking habit duration (not just completion). Users log time blocks against habits.

### Core Models

- **User**: email_address, name, theme. Has many habits, sessions, magic_links.
- **Habit**: name, description, color_token (1-8), active. Belongs to user, has many habit_logs.
- **HabitLog**: logged_on (date), start_hour/end_hour (decimal 0-24). Belongs to habit.
- **DaySummary**: PORO aggregating habit data for a given date (not persisted).

### Key Domain Concepts

- **Time blocks**: Decimal hours (9.5 = 9:30am, 14.0 = 2pm). Duration = end_hour - start_hour.
- **Color tokens**: 1-8 mapped to CSS variables for theming.
- **Authentication**: Magic link-based (no passwords). See `Authentication` concern.

### Routes

```ruby
root "dashboard#index"                    # Timeline view
resources :habits                         # CRUD
resources :habits/:habit_id/logs          # Nested logs
resources :habit_logs, only: [:create]    # Standalone create for timeline
resource :settings, only: [:show, :update]
```

## Code Style (Rubocop Rails Omakase)

### Ruby

- **Indentation**: 2 spaces, no tabs
- **Strings**: Double quotes preferred
- **Method definitions**: Use parentheses for arguments
- **Private methods**: Indented under `private` keyword
- **Line length**: 120 characters max
- **Trailing commas**: In multi-line arrays/hashes

### Naming

- Models: singular (Habit, HabitLog)
- Controllers: plural (HabitsController)
- Tables: plural snake_case (habit_logs)
- Methods: snake_case
- Constants: SCREAMING_SNAKE_CASE
- Boolean methods: end with `?` (e.g., `empty?`, `authenticated?`)

### Controllers

- Use `before_action` for common setup
- Scope queries to `current_user` for security: `current_user.habits.find(params[:id])`
- Use `params.expect()` for strong parameters (Rails 8+ style)
- Respond to both HTML and Turbo Stream formats

```ruby
def habit_params
  params.expect(habit: [:name, :description, :color_token, :active])
end
```

### Models

- Keep validations at the top
- Use scopes for common queries
- Callbacks: prefer `before_validation` over `before_save` when setting defaults
- Association options: `dependent: :destroy` on parent relationships

```ruby
class HabitLog < ApplicationRecord
  belongs_to :habit
  validates :logged_on, presence: true
  scope :for_date, ->(date) { where(logged_on: date) }
end
```

### Views

- Use partials with underscores: `_form.html.erb`, `_header.html.erb`
- ERB helpers: `form_with`, `link_to`, `turbo_frame_tag`
- Tailwind CSS with neobrutalist styling (bold colors, thick borders, shadows)
- Component classes prefixed: `nb-card`, `nb-btn`, `nb-input`

### JavaScript (Stimulus)

- Controllers in `app/javascript/controllers/`
- Import from `@hotwired/stimulus`
- Use `static targets` and `static values`
- Bind event handlers in `connect()`, cleanup in `disconnect()`
- Target naming: camelCase (e.g., `colorButton`, `startHourInput`)

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "colorButton"]
  static values = { date: String }

  connect() {
    this.handleClick = this.handleClick.bind(this)
  }
}
```

## Testing Conventions

- Use Minitest (not RSpec)
- Fixtures in `test/fixtures/*.yml`
- Integration tests: use `sign_in_as(user)` helper for auth
- Test naming: `test "descriptive behavior"`

```ruby
class HabitLogTest < ActiveSupport::TestCase
  test "duration_hours calculates correctly" do
    log = HabitLog.new(start_hour: 9, end_hour: 11)
    assert_equal 2, log.duration_hours
  end
end
```

## Turbo Stream Patterns

Controllers return turbo_stream for AJAX updates:

```ruby
respond_to do |format|
  format.turbo_stream
  format.html { redirect_to dashboard_path }
end
```

Views in `app/views/[controller]/[action].turbo_stream.erb`:

```erb
<%= turbo_stream.replace "timeline", partial: "dashboard/timeline", locals: { day: @day } %>
<%= turbo_stream.replace "flash", partial: "shared/flash" %>
```

## Error Handling

- Model validations for user input errors
- `find` raises `ActiveRecord::RecordNotFound` (returns 404)
- Use `create!`/`update!` when failure should raise
- Flash messages: `:notice` for success, `:alert` for errors

## File Organization

```
app/
  controllers/concerns/    # Authentication, shared behavior
  javascript/controllers/  # Stimulus controllers
  models/                  # ActiveRecord + POROs (DaySummary)
  views/
    [controller]/          # Templates
    layouts/               # Application layout
    shared/                # Reusable partials (_flash.html.erb)
```

## Security Notes

- All routes require authentication by default (see `Authentication` concern)
- Use `allow_unauthenticated_access` to skip
- Always scope queries: `current_user.habits.find()` not `Habit.find()`
- Strong parameters via `params.expect()`
