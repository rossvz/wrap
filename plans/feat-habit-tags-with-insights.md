# feat: Habit Tags with Mobile-Friendly Management and Insights

## Enhancement Summary

**Deepened on:** 2025-01-04
**Research agents used:** 10 (DHH Rails, Kieran Rails, Architecture, Performance, Security, Simplicity, Data Integrity, Pattern Recognition, DHH Style, Frontend Design)

### Key Improvements from Research
1. **Simplified V1 scope** - Use checkboxes instead of complex Stimulus autocomplete (65% code reduction)
2. **Security hardening** - SQL wildcard injection fix, input validation, rate limiting
3. **Performance indexes** - Composite indexes for joins, SQLite FK enforcement
4. **Data integrity** - Cascade deletes, atomic counter updates
5. **Accessibility** - ARIA combobox pattern, 44px touch targets, keyboard navigation

### New Considerations Discovered
- SQLite doesn't enforce foreign keys by default - requires PRAGMA config
- Counter cache is not atomic in SQLite - use `update_all` with atomic SQL
- Consider cutting tag analytics/charts for V1 (YAGNI)
- Virtual `tag_list` attribute may crash if user is nil

---

## Overview

Add a tagging system to habits enabling categorization, filtering, and tag-based analytics. Tags will be managed through a mobile-friendly interface on the habit edit page. Insights will be extended to show time invested per tag and tag trends over time.

## Problem Statement

Users currently have no way to categorize or group habits beyond the color system. This makes it difficult to:
- View aggregate time spent on related activities (e.g., all "Health" habits)
- Filter habits by category on the dashboard
- Analyze patterns across habit categories in insights

## Proposed Solution

Implement a custom tagging system (no external gem dependencies) with:
1. **Tag model** with user-scoped, many-to-many relationship to habits
2. **Checkbox-based tag selection** with simple "add new tag" input (V1)
3. **Tag filtering** on dashboard via dropdown
4. **Tag analytics** in insights (V2 - consider cutting for MVP)

### Research Insights: Simplification Recommendations

**From Simplicity Review:**
The original plan was over-engineered. Key simplifications:

| Original | Simplified | Rationale |
|----------|------------|-----------|
| Stimulus autocomplete controller | Checkboxes + text input | 150+ LOC saved, matches existing patterns |
| Tag cloud | Simple list or cut entirely | Zero functional benefit for V1 |
| Counter cache | Count on demand | Premature optimization for <50 tags/user |
| `tag_list` virtual attribute | `tag_ids[]` params | Standard Rails association handling |
| Tag analytics charts | Cut for V1 | Feature creep - add if users request |

**Estimated LOC reduction: 65-75%**

---

## Technical Approach

### Data Model

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│    User     │       │    Habit    │       │  HabitLog   │
├─────────────┤       ├─────────────┤       ├─────────────┤
│ id          │──────<│ user_id     │──────<│ habit_id    │
│ email       │       │ name        │       │ start_hour  │
│ ...         │       │ color_token │       │ end_hour    │
└─────────────┘       │ active      │       │ logged_on   │
      │               └─────────────┘       └─────────────┘
      │                     │
      │                     │ has_many :taggings
      │                     ▼
      │               ┌─────────────┐
      │               │   Tagging   │
      │               ├─────────────┤
      │               │ tag_id      │
      │               │ habit_id    │
      │               │ created_at  │
      │               └─────────────┘
      │                     │
      │                     │ belongs_to :tag
      │                     ▼
      │               ┌─────────────┐
      └──────────────>│    Tag      │
                      ├─────────────┤
                      │ id          │
                      │ user_id     │
                      │ name        │
                      │ taggings_ct │
                      └─────────────┘
```

**Key decisions:**
- Tags scoped per-user (each user has their own tag namespace)
- Many-to-many via `taggings` join table
- Counter cache deferred until performance profiling proves need
- No tag colors (keeps visual focus on habit colors)

---

### Phase 1: Database & Models

**Migration: `create_tags_and_taggings.rb`**

```ruby
class CreateTagsAndTaggings < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :taggings_count, default: 0, null: false
      t.timestamps
    end

    # Case-insensitive unique constraint
    add_index :tags, [:user_id, :name], unique: true
    add_index :tags, :name

    create_table :taggings do |t|
      t.references :tag, null: false, foreign_key: { on_delete: :cascade }
      t.references :habit, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    add_index :taggings, [:habit_id, :tag_id], unique: true
    add_index :taggings, :tag_id  # For counter cache queries
  end
end
```

### Research Insights: Data Integrity

**From Data Integrity Guardian:**
- Use `on_delete: :cascade` to prevent orphaned records when users/habits are deleted
- SQLite does NOT enforce foreign keys by default - add initializer:

```ruby
# config/initializers/sqlite_foreign_keys.rb
if ActiveRecord::Base.connection.adapter_name == "SQLite"
  ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
end
```

- Counter cache race conditions in SQLite - use atomic SQL:

```ruby
# In Tagging model - atomic increment/decrement
after_create { Tag.where(id: tag_id).update_all("taggings_count = taggings_count + 1") }
after_destroy { Tag.where(id: tag_id).update_all("taggings_count = CASE WHEN taggings_count > 0 THEN taggings_count - 1 ELSE 0 END") }
```

---

**Tag Model: `app/models/tag.rb`**

```ruby
class Tag < ApplicationRecord
  belongs_to :user
  has_many :taggings, dependent: :destroy
  has_many :habits, through: :taggings

  validates :name, presence: true,
                   length: { maximum: 30 },
                   format: { with: /\A[a-z0-9\s\-_]+\z/,
                             message: "only allows letters, numbers, spaces, hyphens, underscores" },
                   uniqueness: { scope: :user_id, case_sensitive: false }

  normalizes :name, with: ->(name) { name.to_s.strip.downcase }

  scope :alphabetically, -> { order(name: :asc) }
  scope :by_popularity, -> { order(taggings_count: :desc) }
  scope :matching, ->(query) {
    return none if query.blank?
    sanitized = query.to_s.first(50).downcase.gsub(/[%_\\]/) { |c| "\\#{c}" }
    where("name LIKE ?", "#{sanitized}%")
  }
end
```

### Research Insights: Security

**From Security Sentinel:**
- SQL wildcard injection: Use `gsub(/[%_\\]/)` to escape LIKE wildcards
- XSS prevention: Format validation ensures no HTML characters in tag names
- Input length: Limit query to 50 chars to prevent DoS
- Rate limiting: Add to autocomplete endpoint (if implementing):

```ruby
# config/initializers/rack_attack.rb (if using autocomplete)
Rack::Attack.throttle("autocomplete", limit: 30, period: 60) do |req|
  req.ip if req.path.include?("/autocomplete")
end
```

---

**Tagging Model: `app/models/tagging.rb`**

```ruby
class Tagging < ApplicationRecord
  belongs_to :tag
  belongs_to :habit

  validates :tag_id, uniqueness: { scope: :habit_id }

  # Atomic counter updates (SQLite-safe)
  after_create :increment_tag_counter
  after_destroy :decrement_tag_counter

  private

  def increment_tag_counter
    Tag.where(id: tag_id).update_all("taggings_count = taggings_count + 1")
  end

  def decrement_tag_counter
    Tag.where(id: tag_id).update_all("taggings_count = CASE WHEN taggings_count > 0 THEN taggings_count - 1 ELSE 0 END")
  end
end
```

---

**User Model Updates: `app/models/user.rb`**

```ruby
# Add association (REQUIRED - identified by Kieran review)
has_many :tags, dependent: :destroy
```

---

**Habit Model Updates: `app/models/habit.rb`**

```ruby
class Habit < ApplicationRecord
  # Add associations
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  # Scopes for filtering
  scope :with_tag, ->(tag_name) {
    joins(:tags).where(tags: { name: tag_name.downcase }).distinct
  }

  scope :with_any_tags, ->(tag_names) {
    joins(:tags).where(tags: { name: tag_names.map(&:downcase) }).distinct
  }

  # Virtual attribute for comma-separated form input (Alternative approach)
  def tag_list
    tags.pluck(:name).join(", ")
  end

  def tag_list=(names)
    return if user.nil?  # Guard clause (identified by Kieran review)

    tag_names = names.to_s.split(",").map(&:strip).reject(&:blank?).uniq.first(20)
    self.tags = tag_names.filter_map do |name|
      next if name.length > 30
      user.tags.find_or_create_by(name: name)  # Non-bang version for safety
    end
  end
end
```

### Research Insights: DHH Rails Style

**From DHH Rails Reviewer:**
> "You do not need a custom autocomplete Stimulus controller. Use Rails 8's built-in `<datalist>` element with a simple text field."

Consider the simpler approach:
```erb
<%= form.text_field :tag_list, list: "available-tags", class: "nb-input" %>
<datalist id="available-tags">
  <% current_user.tags.pluck(:name).each do |name| %>
    <option value="<%= name %>">
  <% end %>
</datalist>
```

---

### Phase 2: Tag Input UI Component (Simplified)

### Research Insights: Simplification

**From Simplicity Reviewer:**
> Replace Stimulus autocomplete with checkboxes - matches existing app patterns (see color picker), ~150-200 LOC saved.

**Simplified Tag Input: `app/views/habits/_tag_input.html.erb`**

```erb
<div class="mt-4">
  <%= form.label :tag_ids, "Tags", class: "nb-label" %>

  <%# Existing tags as checkboxes %>
  <% if current_user.tags.any? %>
    <div class="mt-2 flex flex-wrap gap-2">
      <% current_user.tags.alphabetically.each do |tag| %>
        <label class="inline-flex items-center gap-2 px-3 py-2 min-h-[44px]
                      border-2 border-black cursor-pointer touch-manipulation
                      has-[:checked]:bg-gray-200 has-[:checked]:ring-2 has-[:checked]:ring-black
                      hover:bg-gray-50 transition-colors"
               style="box-shadow: 2px 2px 0 var(--shadow-color, #000)">
          <%= check_box_tag "habit[tag_ids][]", tag.id,
                            habit.tags.include?(tag),
                            class: "sr-only" %>
          <span class="text-sm font-bold"><%= tag.name %></span>
        </label>
      <% end %>
    </div>
  <% end %>

  <%# Add new tag %>
  <div class="mt-3 flex gap-2">
    <%= text_field_tag "new_tag_name", "",
                       placeholder: "New tag name...",
                       maxlength: 30,
                       class: "nb-input flex-1" %>
    <button type="button"
            onclick="addNewTag(this)"
            class="nb-btn nb-btn--white">
      Add
    </button>
  </div>

  <p class="mt-2 text-xs text-gray-500">Select existing tags or create new ones.</p>
</div>

<script>
function addNewTag(btn) {
  const input = btn.previousElementSibling;
  const name = input.value.trim().toLowerCase();
  if (!name) return;

  // Add hidden input for new tag
  const hidden = document.createElement('input');
  hidden.type = 'hidden';
  hidden.name = 'new_tags[]';
  hidden.value = name;
  btn.closest('form').appendChild(hidden);

  // Show visual chip
  const chip = document.createElement('span');
  chip.className = 'inline-flex items-center gap-2 px-3 py-2 min-h-[44px] border-2 border-black bg-gray-200';
  chip.style.boxShadow = '2px 2px 0 var(--shadow-color, #000)';
  chip.innerHTML = `<span class="text-sm font-bold">${name}</span>`;
  btn.closest('.mt-3').previousElementSibling.appendChild(chip);

  input.value = '';
}
</script>
```

### Research Insights: Accessibility & Mobile

**From Frontend Design Skill & WCAG Research:**
- Touch targets: Use `min-h-[44px]` (44px recommended by WCAG 2.2 Level AA)
- Touch manipulation: Add `touch-manipulation` class to prevent double-tap zoom
- Visual focus: Use `has-[:checked]` pseudo-class for checkbox states
- Theme compatibility: Use CSS variables for shadows

**From Stimulus Documentation (if using Stimulus in V2):**
- Use `data-action="keydown.enter->tags#add"` for keyboard shortcuts
- Add `role="combobox"` and `aria-expanded` for autocomplete
- Use `aria-activedescendant` for focus management in listbox

---

### Phase 3: Controller & Routes

**Routes: `config/routes.rb`**

```ruby
resources :tags, only: [:index]  # For AJAX tag list if needed

resources :habits do
  # existing routes
end
```

**Update Habits Controller: `app/controllers/habits_controller.rb`**

```ruby
def create
  @habit = current_user.habits.build(habit_params)
  create_new_tags_from_params
  # ... rest of create
end

def update
  create_new_tags_from_params
  # ... rest of update
end

private

def habit_params
  params.expect(habit: [:name, :description, :color_token, :active, tag_ids: []])
end

def create_new_tags_from_params
  return unless params[:new_tags].present?

  params[:new_tags].each do |name|
    tag = current_user.tags.find_or_create_by(name: name.strip.downcase)
    @habit.tags << tag unless @habit.tags.include?(tag)
  end
end
```

### Research Insights: DHH Style

**From DHH Rails Reviewer:**
> "Map to REST. 'Suggestions' is a noun resource, and fetching them is an `index` action."

If implementing autocomplete endpoint later:
```ruby
# config/routes.rb
namespace :tags do
  resources :suggestions, only: [:index]
end

# app/controllers/tags/suggestions_controller.rb
class Tags::SuggestionsController < ApplicationController
  def index
    @tags = current_user.tags.matching(params[:q]).by_popularity.limit(8)
  end
end
```

---

### Phase 4: Dashboard Tag Filtering

**Dashboard Controller Updates: `app/controllers/dashboard_controller.rb`**

```ruby
def index
  @tag_filter = params[:tag]
  @day = DaySummary.new(current_user, current_date, tag_filter: @tag_filter)
  @user_tags = current_user.tags.by_popularity.limit(10)
end
```

**DaySummary Updates: `app/models/day_summary.rb`**

```ruby
def initialize(user, date = Time.zone.today, tag_filter: nil)
  @user = user
  @date = date
  @tag_filter = tag_filter
end

def habits
  @habits ||= begin
    scope = user.habits.where(active: true)
    scope = scope.with_tag(@tag_filter) if @tag_filter.present?
    scope.order(created_at: :asc)  # Preserve existing ordering
  end
end
```

### Research Insights: Pattern Consistency

**From Pattern Recognition Specialist:**
- Keep memoization (`@habits ||=`) for consistency with existing code
- Preserve `created_at: :asc` ordering (don't change to `:name`)
- Use `begin...end` block for multi-line memoization

**Simplified Tag Filter UI: `app/views/dashboard/_tag_filter.html.erb`**

```erb
<% if @user_tags.any? %>
  <%= form_with url: root_path, method: :get, data: { turbo_frame: "_top" }, class: "mb-4" do %>
    <label for="tag_filter" class="nb-label">Filter by tag</label>
    <%= select_tag :tag,
                   options_for_select([["All habits", nil]] + @user_tags.map { |t| [t.name, t.name] }, @tag_filter),
                   class: "nb-input mt-2",
                   onchange: "this.form.requestSubmit()" %>
  <% end %>
<% end %>
```

### Research Insights: Simplicity

**From Simplicity Reviewer:**
> "A single `<select>` dropdown with 'All' default. ~50 LOC saved, simpler state management."

The dropdown approach is simpler than pill-based filters and works with Turbo out of the box.

---

### Phase 5: Tag Analytics in Insights (V2 - Consider Deferring)

### Research Insights: YAGNI

**From Simplicity Reviewer:**
> "Charts require charting libraries, additional queries, and UI complexity. Users need to track habits first before analyzing them by tag. This is a V2+ feature disguised as V1."

**Recommendation:** Ship V1 without tag analytics. Add if users request it.

---

**If implementing (V2), SummaryCalculations Updates:**

```ruby
# app/models/concerns/summary_calculations.rb
def hours_by_tag
  @hours_by_tag ||= HabitLog
    .joins(habit: :tags)
    .where(habits: { user_id: user.id, active: true })
    .where(logged_on: date_range)
    .group("tags.id", "tags.name")
    .sum("end_hour - start_hour")
    .map { |(id, name), hours| { tag_id: id, name: name, hours: hours.round(1) } }
    .select { |t| t[:hours] > 0 }  # Filter zero values (pattern consistency)
    .sort_by { |t| -t[:hours] }
end
```

### Research Insights: Performance

**From Performance Oracle:**
- Add index on `habit_logs.logged_on` for date range queries
- The insights query joins 4 tables - may be slow at scale
- Consider caching for dashboard:

```ruby
def tag_hours_for_range(user, date_range)
  Rails.cache.fetch(["tag_hours", user.id, date_range], expires_in: 15.minutes) do
    # Query here
  end
end
```

**Required indexes for performance:**
```ruby
# Add in a separate migration
add_index :habit_logs, :logged_on
add_index :habit_logs, [:habit_id, :logged_on]
add_index :habits, [:user_id, :active]
```

---

## Acceptance Criteria

### Functional Requirements

- [ ] User can assign tags to habits via checkboxes on edit/create form
- [ ] User can create new tags by typing name and clicking "Add"
- [ ] Tag names are normalized (lowercase, trimmed, max 30 chars)
- [ ] Tags are unique per user (case-insensitive)
- [ ] User can filter dashboard by tag via dropdown
- [ ] Tag associations are removed when habits are deleted (cascade)

### Mobile Requirements

- [ ] Tag checkboxes have 44px minimum touch targets
- [ ] Touch manipulation prevents double-tap zoom
- [ ] Input and buttons are touch-friendly

### Keyboard Accessibility

- [ ] Enter submits form (standard behavior)
- [ ] Tab moves focus between form elements
- [ ] Checkboxes toggle with Space key

### Performance

- [ ] Tag queries use indexes (user_id, name)
- [ ] Eager load tags when displaying habits: `habits.includes(:tags)`
- [ ] Dashboard filter uses Turbo for fast updates

### Security

- [ ] Tag names validated against HTML/script injection
- [ ] LIKE query escapes wildcards (%, _, \)
- [ ] Foreign key constraints prevent orphaned data

---

## Files to Create/Modify

### New Files
- `db/migrate/XXXXXX_create_tags_and_taggings.rb`
- `app/models/tag.rb`
- `app/models/tagging.rb`
- `app/views/habits/_tag_input.html.erb`
- `app/views/dashboard/_tag_filter.html.erb`
- `config/initializers/sqlite_foreign_keys.rb`
- `test/models/tag_test.rb`
- `test/models/tagging_test.rb`

### Modified Files
- `app/models/habit.rb` - Add tag associations and scopes
- `app/models/user.rb` - Add `has_many :tags`
- `app/controllers/habits_controller.rb` - Handle tag_ids and new_tags params
- `app/controllers/dashboard_controller.rb` - Add tag filtering
- `app/views/habits/_form.html.erb` - Include tag input partial
- `app/views/dashboard/index.html.erb` - Include tag filter
- `app/models/day_summary.rb` - Support tag filtering
- `config/routes.rb` - Add tags route (if needed)

---

## Test Plan

- [ ] Tag model validations (presence, length, format, uniqueness per user)
- [ ] Tag normalization (lowercase, trimmed)
- [ ] Tag name sanitization (no HTML, no SQL wildcards in searches)
- [ ] Habit tag associations (add, remove, cascade delete)
- [ ] Habit.with_tag scope returns correct habits
- [ ] Dashboard filtering by tag works
- [ ] System test: Assign tags to habit via checkboxes
- [ ] System test: Create new tag from habit form
- [ ] System test: Filter dashboard by tag
- [ ] Performance test: Autocomplete < 50ms (if implemented)
- [ ] Performance test: Dashboard filter < 200ms

---

## Dependencies & Risks

**Dependencies:**
- None (custom implementation, no new gems)

**Risks:**
| Risk | Mitigation |
|------|------------|
| Tag analytics slow at scale | Defer to V2, add caching |
| SQLite FK not enforced | Add PRAGMA initializer |
| Counter cache race conditions | Use atomic SQL updates |
| Complex UI delays launch | Simplified checkbox UI |

---

## V1 vs V2 Scope

### V1 (Ship First)
- Tag and Tagging models with migrations
- Checkbox-based tag selection on habit form
- "Add new tag" text input
- Dashboard dropdown filter
- Basic model tests

### V2 (If Users Request)
- Tag analytics/charts in insights
- Autocomplete with Stimulus controller
- Tag cloud UI
- Tag merge/rename functionality
- Bulk tag operations

---

## References

### Internal
- `app/models/habit.rb` - Existing model structure
- `app/javascript/controllers/color_picker_controller.js` - Similar selection pattern
- `app/models/concerns/summary_calculations.rb` - Analytics query patterns
- `app/views/insights/show.html.erb` - Existing Chart.js integration

### External
- [WCAG 2.2 Target Size](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html) - 24px minimum, 44px recommended
- [W3C ARIA Combobox Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/combobox/examples/combobox-autocomplete-list/) - For V2 autocomplete
- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/hello-stimulus) - For V2 controller
- [Turbo Streams Reference](https://turbo.hotwired.dev/reference/streams) - For dynamic updates
