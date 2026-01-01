# feat: Detailed, Colorful, Interactive Analytics Dashboard

Transform the basic Insights page into a rich, interactive analytics dashboard with multiple chart types, time period navigation, habit comparisons, and real-time updates.

---

## Enhancement Summary

**Deepened on:** 2025-12-31
**Research agents used:** 9 review agents, 2 Context7 queries, 3 web searches
**Sections enhanced:** All major sections

### Key Improvements from Research

1. **Simplified architecture**: Extend existing `chart_controller.js` instead of creating 5 new controllers
2. **Fixed critical bugs**: Streak calculation logic bug, async import race conditions
3. **Performance optimizations**: SQL aggregation, Canvas heatmap vs 364 DOM elements, Chart.js decimation
4. **Cache strategy revised**: Version-based keys instead of `delete_matched`
5. **Security hardened**: Parameter allowlisting, Turbo Stream verification

### Critical Warnings from Reviewers

- **DHH**: "Skip caching entirely - your queries are simple indexed queries"
- **Kieran Rails**: "`delete_matched` is O(N) and can block Redis - use version-based invalidation"
- **Performance Oracle**: "N+1 query in `hours_by_habit` - fix with single aggregation query"
- **Pattern Specialist**: "Logic bug in streak calculation - dates logic is incorrect"

---

## Overview

The current Insights page shows a simple weekly bar chart of hours by day. This plan transforms it into a comprehensive analytics dashboard with:

- **Multiple chart types**: Bar, line, doughnut, and heatmap visualizations
- **Flexible time periods**: Week, month, and year views with navigation
- **Habit breakdown**: Distribution charts and per-habit metrics
- **Trend analysis**: Week-over-week comparisons and moving averages
- **Streak tracking**: Current and longest streak visualization
- **Real-time updates**: Live chart updates when habits are logged
- **Interactive filters**: Drill-down by habit, date, and time

---

## Problem Statement

Users currently see minimal analytics on the Insights page:
- Only one bar chart showing hours by day for a single week
- No ability to see monthly or yearly trends
- No per-habit breakdown or comparison
- No streak or consistency metrics
- No interactive filtering or drill-down capabilities
- Charts don't update in real-time

This limits users' ability to understand their habit patterns, identify trends, and stay motivated through visible progress.

---

## Proposed Solution

### Research Insight: Simplification (from DHH & Simplicity Reviews)

> "Your existing code is excellent Rails. Your plan is an attempt to turn it into something else... The best code is the code you do not write."

**Revised approach** - follow existing codebase patterns:

1. **Keep focused POROs** - Create `MonthSummary` and `YearSummary` following `WeekSummary` pattern (not a generic `PeriodSummary`)
2. **Extend existing chart controller** - Add `type` value to handle bar/doughnut/line (not 5 new controllers)
3. **Skip caching initially** - Queries are simple indexed SQL; add caching only if measured slow
4. **Use standard Turbo navigation** - Period switching via links, not custom Stimulus controllers
5. **Defer heatmap** - Build only if specifically requested

### Architecture Diagram (Simplified)

```
┌─────────────────────────────────────────────────────────────┐
│                    InsightsController                        │
│  - show (period param: week/month/year)                      │
│  - Uses WeekSummary, MonthSummary, or YearSummary           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│           WeekSummary / MonthSummary / YearSummary          │
│  (Focused POROs - one per period type)                      │
│  - initialize(user, date)                                    │
│  - total_hours, daily_average, active_days_count            │
│  - hours_by_day, hours_by_habit                             │
│  - chart_data (Chart.js format)                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              chart_controller.js (extended)                  │
│  - static values = { data: Object, type: String }           │
│  - Handles bar, doughnut, line via typeValue                │
└─────────────────────────────────────────────────────────────┘
```

---

## Technical Approach

### Database Query Optimization

#### Research Insight: N+1 Query Fix (from Performance Oracle)

The original `hours_by_habit` method has an N+1 query:

```ruby
# BAD: N+1 - executes 1 + N queries
def hours_by_habit
  user.habits.active.map do |habit|
    hours = habit.habit_logs.where(logged_on: date_range).sum(...)
  end
end
```

**Fixed implementation** - single query:

```ruby
# app/models/month_summary.rb (and similar for Year)

def hours_by_habit
  HabitLog
    .joins(:habit)
    .where(habits: { user_id: user.id, active: true })
    .where(logged_on: date_range)
    .group("habits.id", "habits.name", "habits.color_token")
    .sum("end_hour - start_hour")
    .map { |(id, name, color_token), hours|
      { habit_id: id, name: name, color_token: color_token, hours: hours.round(1) }
    }
    .select { |h| h[:hours] > 0 }
    .sort_by { |h| -h[:hours] }
end
```

#### Research Insight: Add Composite Index

```ruby
# db/migrate/XXXXXX_add_insights_index.rb
class AddInsightsIndex < ActiveRecord::Migration[8.0]
  def change
    # Optimizes date range queries for analytics
    add_index :habit_logs, [:logged_on, :habit_id],
              name: "index_habit_logs_on_logged_on_and_habit_id"
  end
end
```

### Caching Strategy

#### Research Insight: Skip for V1 (from DHH Review)

> "You are solving a performance problem you do not have... With proper indices, this is sub-millisecond for years of data."

**V1**: No caching. Simple indexed queries.

**V2 (if needed)**: Use version-based cache keys (from Kieran Rails Review):

```ruby
# AVOID: delete_matched is O(N) and can block Redis
# Rails.cache.delete_matched("period_summary/#{user_id}/*")

# PREFER: Version-based invalidation (O(1))
def cache_key(suffix)
  version = Rails.cache.fetch("summary_version/#{user.id}") { Time.current.to_i }
  "summary/v1/#{user.id}/#{version}/#{period_type}/#{start_date.iso8601}/#{suffix}"
end

# Invalidation - just delete the version key
def invalidate_caches
  Rails.cache.delete("summary_version/#{habit.user_id}")
end
```

---

## Implementation Phases

### Phase 1: Foundation - MonthSummary & Extended Chart Controller

**Goal**: Add month/year views following existing patterns.

#### Research Insight: Follow WeekSummary Pattern (from DHH)

> "If you need monthly data, create a `MonthSummary` with the same focused approach... Do not create some generic PeriodSummary that handles all periods through configuration."

#### `app/models/month_summary.rb`

```ruby
class MonthSummary
  attr_reader :user, :month_start

  def initialize(user, date = nil)
    @user = user
    @month_start = (date || Date.current).beginning_of_month
  end

  def month_end
    @month_end ||= month_start.end_of_month
  end

  def date_range
    month_start..month_end
  end

  def total_hours
    habit_logs.sum("end_hour - start_hour").round(1)
  end

  def daily_average
    return 0 if days_in_month.zero?
    (total_hours / active_days_count.to_f).round(1)
  end

  def active_days_count
    habit_logs.distinct.count(:logged_on)
  end

  # Fixed N+1 query (from Performance Oracle)
  def hours_by_day
    HabitLog.joins(:habit)
            .where(habits: { user_id: user.id })
            .where(logged_on: date_range)
            .group(:logged_on)
            .sum("end_hour - start_hour")
  end

  # Fixed N+1 query
  def hours_by_habit
    HabitLog
      .joins(:habit)
      .where(habits: { user_id: user.id, active: true })
      .where(logged_on: date_range)
      .group("habits.id", "habits.name", "habits.color_token")
      .sum("end_hour - start_hour")
      .map { |(id, name, color_token), hours|
        { habit_id: id, name: name, color_token: color_token, hours: hours.round(1) }
      }
      .select { |h| h[:hours] > 0 }
      .sort_by { |h| -h[:hours] }
  end

  def chart_data
    {
      labels: days.map { |d| d.day.to_s },
      datasets: [{
        label: "Hours",
        data: days.map { |d| (hours_by_day[d] || 0).round(1) },
        backgroundColor: "var(--accent-primary)",
        borderColor: "#000",
        borderWidth: 2
      }]
    }
  end

  def doughnut_chart_data
    habits = hours_by_habit
    {
      labels: habits.map { |h| h[:name] },
      datasets: [{
        data: habits.map { |h| h[:hours] },
        backgroundColor: habits.map { |h| "var(--habit-color-#{h[:color_token]})" },
        borderColor: "#000",
        borderWidth: 2
      }]
    }
  end

  # Navigation
  def previous_month
    month_start - 1.month
  end

  def next_month
    month_start + 1.month
  end

  def can_navigate_next?
    next_month.beginning_of_month <= Date.current.beginning_of_month
  end

  private

  def habit_logs
    HabitLog.joins(:habit)
            .where(habits: { user_id: user.id })
            .where(logged_on: date_range)
  end

  def days
    @days ||= (month_start..month_end).to_a
  end

  def days_in_month
    (month_end - month_start).to_i + 1
  end
end
```

#### `app/controllers/insights_controller.rb`

```ruby
class InsightsController < ApplicationController
  ALLOWED_PERIODS = %w[week month year].freeze  # Security: allowlist

  def show
    @period_type = validated_period_type
    @date = parse_date(params[:date])
    @summary = build_summary
  end

  private

  # Research Insight: Explicit allowlisting (from Security Sentinel)
  def validated_period_type
    ALLOWED_PERIODS.include?(params[:period]) ? params[:period] : "week"
  end

  def parse_date(param)
    Date.parse(param)
  rescue ArgumentError, TypeError
    Date.current
  end

  def build_summary
    case @period_type
    when "week" then WeekSummary.new(current_user, @date)
    when "month" then MonthSummary.new(current_user, @date)
    when "year" then YearSummary.new(current_user, @date)
    end
  end
end
```

#### Research Insight: Extend Existing Chart Controller (from DHH & Simplicity Reviews)

> "For a doughnut chart, you literally change one line... Do not make a separate controller."

```javascript
// app/javascript/controllers/chart_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    data: Object,
    type: { type: String, default: "bar" }  // NEW: type value
  }

  // Research Insight: Guard async imports (from Frontend Races Review)
  #isConnected = false
  #chart = null

  async connect() {
    this.#isConnected = true

    const { Chart } = await import("chart.js/auto")

    // Guard against disconnect during async import
    if (!this.#isConnected || !this.element.isConnected) return

    this.#chart = new Chart(this.canvasTarget, {
      type: this.typeValue,  // Dynamic type
      data: this.dataValue,
      options: this.chartOptions
    })
  }

  disconnect() {
    this.#isConnected = false
    if (this.#chart) {
      this.#chart.destroy()
      this.#chart = null
    }
  }

  // Research Insight: Use update() for Turbo Stream updates (from Architecture Review)
  dataValueChanged() {
    if (this.#chart && this.element.isConnected) {
      this.#chart.data = this.dataValue
      this.#chart.update('none')  // No animation on update
    }
  }

  get chartOptions() {
    const baseOptions = {
      responsive: true,
      maintainAspectRatio: false,
      // Research Insight: Disable animations for performance (from Context7)
      animation: { duration: 0 },
      plugins: {
        legend: { display: this.typeValue === "doughnut" }
      }
    }

    if (this.typeValue === "bar" || this.typeValue === "line") {
      baseOptions.scales = { y: { beginAtZero: true } }
    }

    if (this.typeValue === "doughnut") {
      baseOptions.cutout = "60%"
    }

    return baseOptions
  }
}
```

#### `app/views/insights/show.html.erb`

```erb
<div class="nb-page">
  <%# Header with period selector - simple links, no JS controller %>
  <div class="nb-page-header flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
    <h1 class="text-2xl font-black">Insights</h1>
    <div class="flex gap-2">
      <%= link_to "Week", insights_path(period: "week"),
          class: "nb-btn #{@period_type == 'week' ? 'bg-accent-primary' : ''}" %>
      <%= link_to "Month", insights_path(period: "month"),
          class: "nb-btn #{@period_type == 'month' ? 'bg-accent-primary' : ''}" %>
      <%= link_to "Year", insights_path(period: "year"),
          class: "nb-btn #{@period_type == 'year' ? 'bg-accent-primary' : ''}" %>
    </div>
  </div>

  <%# Stats summary cards %>
  <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mt-6">
    <div class="nb-card text-center">
      <span class="nb-label">Total Hours</span>
      <div class="text-3xl font-black"><%= @summary.total_hours %></div>
    </div>
    <div class="nb-card text-center">
      <span class="nb-label">Daily Avg</span>
      <div class="text-3xl font-black"><%= @summary.daily_average %></div>
    </div>
    <div class="nb-card text-center">
      <span class="nb-label">Active Days</span>
      <div class="text-3xl font-black"><%= @summary.active_days_count %></div>
    </div>
    <div class="nb-card text-center">
      <span class="nb-label">Top Habit</span>
      <div class="text-xl font-black truncate">
        <%= @summary.hours_by_habit.first&.dig(:name) || "—" %>
      </div>
    </div>
  </div>

  <%# Period navigation %>
  <div class="flex justify-between items-center mt-6">
    <%= link_to "← Previous", insights_path(period: @period_type, date: @summary.respond_to?(:previous_month) ? @summary.previous_month : @summary.previous_week_start),
        class: "nb-btn" %>
    <span class="font-bold">
      <%= case @period_type
          when "week" then "Week of #{@summary.week_start.strftime('%b %d, %Y')}"
          when "month" then @summary.month_start.strftime('%B %Y')
          when "year" then @summary.respond_to?(:year_start) ? @summary.year_start.year : Date.current.year
          end %>
    </span>
    <% if @summary.can_navigate_next? %>
      <%= link_to "Next →", insights_path(period: @period_type, date: @summary.respond_to?(:next_month) ? @summary.next_month : @summary.next_week_start),
          class: "nb-btn" %>
    <% else %>
      <span class="nb-btn opacity-50 cursor-not-allowed">Next →</span>
    <% end %>
  </div>

  <%# Charts grid %>
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
    <%# Hours bar chart - uses extended chart controller %>
    <div class="nb-card">
      <h2 class="nb-label mb-4">Hours by Day</h2>
      <div class="relative h-64"
           data-controller="chart"
           data-chart-type-value="bar"
           data-chart-data-value="<%= @summary.chart_data.to_json %>">
        <canvas data-chart-target="canvas"></canvas>
      </div>
    </div>

    <%# Habit distribution - same controller, different type %>
    <div class="nb-card">
      <h2 class="nb-label mb-4">Time by Habit</h2>
      <% if @summary.hours_by_habit.any? %>
        <div class="relative h-64"
             data-controller="chart"
             data-chart-type-value="doughnut"
             data-chart-data-value="<%= @summary.doughnut_chart_data.to_json %>">
          <canvas data-chart-target="canvas"></canvas>
        </div>
      <% else %>
        <div class="h-64 flex items-center justify-center text-gray-400">
          No habits logged this period
        </div>
      <% end %>
    </div>
  </div>

  <%# Habit breakdown table %>
  <div class="nb-card mt-6">
    <h2 class="nb-label mb-4">Habit Breakdown</h2>
    <% if @summary.hours_by_habit.any? %>
      <div class="space-y-3">
        <% @summary.hours_by_habit.each do |item| %>
          <div class="flex items-center gap-4">
            <div class="w-4 h-4 rounded border-2 border-black flex-shrink-0"
                 style="background: var(--habit-color-<%= item[:color_token] %>)"></div>
            <span class="font-bold flex-1"><%= item[:name] %></span>
            <span class="font-mono"><%= item[:hours] %>h</span>
          </div>
        <% end %>
      </div>
    <% else %>
      <p class="text-gray-400">No habits logged this period</p>
    <% end %>
  </div>
</div>
```

**Acceptance Criteria - Phase 1**:
- [ ] MonthSummary model created following WeekSummary pattern
- [ ] YearSummary model created following same pattern
- [ ] InsightsController uses allowlisted period param
- [ ] chart_controller.js extended with `type` value
- [ ] Period navigation links working (no new JS controllers)
- [ ] Stats cards showing: total hours, daily average, active days, top habit
- [ ] Bar and doughnut charts rendering via single controller
- [ ] Tests passing for MonthSummary and YearSummary

---

### Phase 2: Streak Calculations

#### Research Insight: Fix Logic Bug (from Pattern Recognition Specialist)

The original streak calculation has a logic bug:

```ruby
# BUG: Incorrect break condition
dates.each do |date|
  break if date < expected - 1.day  # Premature exit
  if date == expected || date == expected - 1.day
    streak += 1
    ...
  end
end
```

**Fixed implementation**:

```ruby
# app/models/concerns/streak_calculator.rb
module StreakCalculator
  extend ActiveSupport::Concern

  def current_streak
    dates = logged_dates_set
    return 0 if dates.empty?

    # Start from today or yesterday (allow grace period)
    start = dates.include?(Date.current) ? Date.current : Date.current - 1.day
    return 0 unless dates.include?(start)

    streak = 0
    current = start
    while dates.include?(current)
      streak += 1
      current -= 1.day
      break if streak > 365  # Safety limit
    end
    streak
  end

  def longest_streak
    dates = logged_dates.to_a.sort
    return 0 if dates.empty?

    max_streak = 1
    current = 1

    dates.each_cons(2) do |prev, curr|
      if curr == prev + 1.day
        current += 1
        max_streak = [max_streak, current].max
      else
        current = 1
      end
    end

    max_streak
  end

  private

  def logged_dates_set
    @logged_dates_set ||= logged_dates.to_set
  end

  # Research Insight: Bound to recent dates (from Performance Oracle)
  def logged_dates
    HabitLog.joins(:habit)
            .where(habits: { user_id: user.id })
            .where(logged_on: (Date.current - 365.days)..Date.current)
            .distinct
            .pluck(:logged_on)
  end
end
```

```ruby
# Include in summary models
class WeekSummary
  include StreakCalculator
  # ...
end
```

**Acceptance Criteria - Phase 2**:
- [ ] StreakCalculator concern created with fixed logic
- [ ] current_streak and longest_streak methods working
- [ ] Streaks displayed in stats cards
- [ ] Performance: Streak calculation bounded to 365 days

---

### Phase 3: Comparison Metrics (Optional)

```ruby
# app/models/month_summary.rb

def comparison_with_previous
  prev = MonthSummary.new(user, previous_month)
  return nil if prev.total_hours.zero?

  change = ((total_hours - prev.total_hours) / prev.total_hours * 100).round
  { change: change, direction: change >= 0 ? :up : :down, previous_hours: prev.total_hours }
end
```

```erb
<%# Show comparison in stats card %>
<% if @summary.respond_to?(:comparison_with_previous) && (comparison = @summary.comparison_with_previous) %>
  <span class="text-sm <%= comparison[:direction] == :up ? 'text-green-600' : 'text-red-600' %>">
    <%= comparison[:direction] == :up ? '↑' : '↓' %>
    <%= comparison[:change].abs %>% vs last <%= @period_type %>
  </span>
<% end %>
```

---

### Phase 4: Heatmap (Deferred)

#### Research Insight: Use Canvas, Not DOM (from Performance Oracle)

> "For 364 cells, rebuilding the entire DOM on every render is inefficient... Consider canvas rendering - 1 DOM element instead of 364."

If/when heatmap is needed, use Canvas:

```javascript
// app/javascript/controllers/heatmap_controller.js (DEFERRED)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { data: Object, year: Number }

  connect() {
    this.render()
  }

  render() {
    const canvas = this.canvasTarget
    const ctx = canvas.getContext('2d')
    const cellSize = 12
    const gap = 2

    // Canvas rendering - 1 DOM element vs 364
    for (let week = 0; week < 52; week++) {
      for (let day = 0; day < 7; day++) {
        const hours = this.getHoursForDate(week, day)
        ctx.fillStyle = this.getLevelColor(hours)
        ctx.fillRect(
          week * (cellSize + gap),
          day * (cellSize + gap),
          cellSize,
          cellSize
        )
      }
    }
  }

  getLevelColor(hours) {
    if (hours === 0) return '#eee'
    if (hours < 1) return '#c6e48b'
    if (hours < 2) return '#7bc96f'
    if (hours < 4) return '#239a3b'
    return '#196127'
  }
}
```

---

## Acceptance Criteria

### Functional Requirements
- [ ] Users can toggle between week, month, and year views via links
- [ ] Users can navigate to previous/next periods
- [ ] Bar chart shows hours aggregated appropriately for each view
- [ ] Doughnut chart shows time distribution across habits
- [ ] Stats cards show: total hours, daily average, active days, streaks
- [ ] Current and longest streak calculated correctly (fixed logic)

### Non-Functional Requirements
- [ ] Page loads in under 2 seconds with 1000+ HabitLogs
- [ ] No N+1 queries (single aggregation query for hours_by_habit)
- [ ] Composite index added for date range queries
- [ ] Charts render smoothly (animation disabled for performance)

### Quality Gates
- [ ] Tests for MonthSummary and YearSummary models
- [ ] Tests for StreakCalculator with edge cases
- [ ] Verified: no new Stimulus controllers except extending chart_controller

---

## File Changes Summary (Simplified)

### New Files
- `app/models/month_summary.rb` - Following WeekSummary pattern
- `app/models/year_summary.rb` - Following WeekSummary pattern
- `app/models/concerns/streak_calculator.rb` - Fixed streak logic
- `db/migrate/XXXX_add_insights_index.rb` - Composite index
- `test/models/month_summary_test.rb`
- `test/models/year_summary_test.rb`

### Modified Files
- `app/controllers/insights_controller.rb` - Period param with allowlist
- `app/views/insights/show.html.erb` - Period tabs, multi-chart layout
- `app/javascript/controllers/chart_controller.js` - Add `type` value

### Files NOT Created (Per Simplification Review)
- ~~`app/models/period_summary.rb`~~ - Use focused summaries instead
- ~~`app/javascript/controllers/doughnut_chart_controller.js`~~ - Extend chart_controller
- ~~`app/javascript/controllers/filter_controller.js`~~ - Use standard links
- ~~`app/javascript/controllers/period_selector_controller.js`~~ - Use standard links
- ~~`app/javascript/controllers/heatmap_controller.js`~~ - Deferred

---

## References

### Research Sources
- [DHH Rails Review](agent:dhh-rails-reviewer) - Simplification recommendations
- [Kieran Rails Review](agent:kieran-rails-reviewer) - Cache invalidation patterns
- [Performance Oracle](agent:performance-oracle) - N+1 fixes, indexing
- [Pattern Recognition](agent:pattern-recognition-specialist) - Streak bug fix
- [Frontend Races Review](agent:julik-frontend-races-reviewer) - Async import guards

### External References
- [Chart.js Performance Guide](https://www.chartjs.org/docs/latest/general/performance.html) - Disable animations, decimation
- [Turbo Frames Lazy Loading](https://turbo.hotwired.dev/reference/frames) - `loading="lazy"` attribute
- [Rails Caching Guide](https://guides.rubyonrails.org/caching_with_rails.html) - Version-based keys
- [Evil Martians Dashboard Tips](https://evilmartians.com/chronicles/5-tips-for-activerecord-dashboards) - SQL aggregation patterns
- [Cal-Heatmap Library](https://github.com/wa0x6e/cal-heatmap) - If canvas heatmap needed later

### Internal References
- Current insights implementation: `app/views/insights/show.html.erb`
- Chart controller pattern: `app/javascript/controllers/chart_controller.js`
- WeekSummary model (pattern to follow): `app/models/week_summary.rb`
- Color system: `app/assets/tailwind/application.css:6-166`
