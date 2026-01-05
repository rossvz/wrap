---
title: "Auto-Save Tags with Stimulus Controller"
date: 2026-01-05
category: ui-bugs
tags:
  - rails-8
  - stimulus
  - ajax
  - tagging
  - xss
  - idor
  - hotwire
  - rest
components:
  - app/controllers/taggings_controller.rb
  - app/javascript/controllers/tag_input_controller.js
  - app/views/habits/_tag_input.html.erb
  - app/models/tag.rb
  - app/models/tagging.rb
root_cause: "Tags appeared selected visually but required form submission to persist"
severity: medium
pr: "#25"
---

# Auto-Save Tags with Stimulus Controller

## Problem Statement

Users editing habits could select tags via checkboxes, but the tags weren't actually saved until clicking "Update Habit". This created a confusing UX where visual state didn't match persisted state.

**User flow issue:**
1. User edits a habit
2. User checks a tag checkbox (visual feedback shows tag selected)
3. User navigates away without clicking "Update Habit"
4. Tag association is lost - user expected it was saved

## Solution Overview

Implemented auto-save for tags on existing habits using a RESTful `TaggingsController` and Stimulus controller, while gracefully falling back to form submission for new habits.

| Habit State | Save Behavior | Implementation |
|-------------|---------------|----------------|
| Existing (persisted) | Auto-save via AJAX | `POST/DELETE /habits/:id/taggings` |
| New (not persisted) | Form submission | Hidden inputs in form |

## Key Files

| File | Purpose |
|------|---------|
| `app/controllers/taggings_controller.rb` | RESTful create/destroy for tag associations |
| `app/javascript/controllers/tag_input_controller.js` | Stimulus controller with conditional auto-save |
| `app/views/habits/_tag_input.html.erb` | Tag selection UI with persisted check |
| `config/routes.rb` | Nested `taggings` resource under `habits` |

## Implementation Details

### RESTful Routes

```ruby
resources :habits do
  resources :taggings, only: %i[create destroy]
end
```

Creates:
- `POST /habits/:habit_id/taggings` - Associate a tag
- `DELETE /habits/:habit_id/taggings/:id` - Remove association

### TaggingsController

```ruby
class TaggingsController < ApplicationController
  before_action :set_habit

  def create
    tag = find_or_create_tag
    return render json: { error: "Invalid tag" }, status: :unprocessable_entity unless tag

    tagging = @habit.taggings.find_or_create_by(tag: tag)
    render json: { tag: { id: tag.id, name: tag.name } }, status: :created
  end

  def destroy
    tagging = @habit.taggings.find_by(tag_id: params[:id])
    tagging&.destroy
    head :no_content
  end

  private

  def set_habit
    @habit = current_user.habits.find(params[:habit_id])  # IDOR protection
  end

  def find_or_create_tag
    if params[:tag_id].present?
      current_user.tags.find_by(id: params[:tag_id])  # IDOR protection
    elsif params[:tag_name].present?
      name = params[:tag_name].to_s.strip.downcase
      return nil if name.blank? || name.length > 30
      current_user.tags.find_or_create_by(name: name)
    end
  end
end
```

### Stimulus Controller

Key behaviors:
- `persistedValue` controls auto-save vs deferred save
- `toggle()` handles checkbox changes with immediate persistence
- `addNewTagForForm()` adds hidden inputs for new habits

```javascript
static values = { habitId: Number, persisted: Boolean }

async toggle(event) {
  const checkbox = event.target
  const tagId = checkbox.value

  if (checkbox.checked) {
    await fetch(`/habits/${this.habitIdValue}/taggings`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body: JSON.stringify({ tag_id: tagId })
    })
  } else {
    await fetch(`/habits/${this.habitIdValue}/taggings/${tagId}`, {
      method: "DELETE",
      headers: { "X-CSRF-Token": document.querySelector("[name='csrf-token']").content }
    })
  }
}
```

### View Partial with Conditional Behavior

```erb
<% persisted = habit.persisted? %>
<div data-controller="tag-input"
     data-tag-input-habit-id-value="<%= habit.id %>"
     data-tag-input-persisted-value="<%= persisted %>">

  <%= check_box_tag "habit[tag_ids][]", tag.id,
                    @habit_tag_ids.include?(tag.id),
                    data: persisted ? { action: "change->tag-input#toggle" } : {} %>

  <p class="text-xs text-gray-500">
    <%= persisted ? "Tags save automatically." : "Tags will be saved with the habit." %>
  </p>
</div>
```

## Security Fixes Applied

### XSS Prevention

**Before (vulnerable):**
```javascript
chip.innerHTML = `<span>${name}</span>`
```

**After (secure):**
```javascript
const textSpan = document.createElement("span")
textSpan.textContent = name  // Safe: escapes HTML
```

### IDOR Prevention

All tag lookups scoped through `current_user`:

```ruby
# In TaggingsController
current_user.tags.find_by(id: params[:tag_id])

# In HabitsController
permitted[:tag_ids] = current_user.tags.where(id: permitted[:tag_ids]).pluck(:id)
```

## Prevention Strategies

### UX Clarity
- Always communicate save timing with help text
- Use visual feedback (checkmarks, spinners) for async saves
- Different messaging for new vs existing records

### Security Checklist
- Never use `innerHTML` with user input - use `textContent`
- Always scope queries through `current_user`
- Validate on both client (UX) and server (security)

### Rails Conventions
- RESTful controllers for join tables
- `counter_cache: true` over manual callbacks
- Stimulus controllers over inline JavaScript
- `inverse_of` on associations

## Testing Recommendations

```ruby
# Authorization test
test "cannot use other user tag on own habit" do
  other_tag = other_user.tags.create!(name: "private")
  post habit_taggings_url(@habit), params: { tag_id: other_tag.id }, as: :json
  assert_response :unprocessable_entity
end

# Idempotency test
test "create is idempotent" do
  @habit.taggings.create!(tag: @tag)
  assert_no_difference("Tagging.count") do
    post habit_taggings_url(@habit), params: { tag_id: @tag.id }, as: :json
  end
  assert_response :created
end
```

## Related Documentation

- [Customizable Push Notification Times](../feature-implementation/customizable-push-notification-times.md) - Similar form handling patterns
- [Timezone Handling](../logic-errors/timezone-handling-client-server-sync.md) - Stimulus controller patterns

## References

- PR #25: feat(habits): Add tagging system for habit categorization
- Commits: `ab2a80f`, `fd8c410`, `28607a6`, `bfebda0`
