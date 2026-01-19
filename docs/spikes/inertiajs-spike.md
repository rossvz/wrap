# InertiaJS Technical Spike

## Executive Summary

This document evaluates InertiaJS as a potential solution for managing frontend complexity in Wrap, specifically the dashboard's `time_block_controller.js` (470+ lines of drag-to-create interaction code).

**Verdict: Inertia would NOT solve the core complexity issues, but could provide incremental DX improvements.**

The dashboard's complexity stems from **DOM-level drag interactions and touch event handling** — problems that exist regardless of framework choice. However, Inertia could simplify state management and eliminate some Turbo Stream coordination pain.

---

## What is InertiaJS?

Inertia is a **"modern monolith" glue layer** that connects server-side frameworks (Rails, Laravel, etc.) to JavaScript UI frameworks (React, Vue, Svelte).

```
Traditional Rails:  Controller → ERB → HTML (Turbo for updates)
With Inertia:       Controller → JSON props → React/Vue/Svelte Component
```

### Key Characteristics

| Feature | Description |
|---------|-------------|
| No API needed | Controllers return `inertia: { component: 'Dashboard', props: {...} }` |
| SPA navigation | Page transitions via XHR, updates DOM without full reload |
| Server routing | Routes stay in Rails, no client-side router |
| Shared state | Props flow server → client; client can POST back |
| Partial reloads | Request only specific props to refresh |

### How It Works

```ruby
# app/controllers/dashboard_controller.rb
def index
  render inertia: 'Dashboard', props: {
    day: DaySummarySerializer.new(@day),
    habits: HabitSerializer.many(@habits),
    tags: current_user.tags
  }
end
```

```jsx
// app/frontend/pages/Dashboard.jsx
export default function Dashboard({ day, habits, tags }) {
  const [selectedHours, setSelectedHours] = useState(null);

  const handleDragComplete = (start, end) => {
    setSelectedHours({ start, end });
    // Modal opens with local state, no server round-trip
  };

  const submitTimeBlock = (habitId) => {
    router.post('/habit_logs', {
      habit_log: {
        habit_id: habitId,
        start_hour: selectedHours.start,
        end_hour: selectedHours.end,
        logged_on: day.date
      }
    });
  };

  return (
    <TimelineGrid
      hours={day.hours}
      timeBlocks={day.timeBlocks}
      onDragComplete={handleDragComplete}
    />
  );
}
```

---

## Current Architecture Pain Points

### 1. DOM Positioning Fragility (`time_block_controller.js:323-344`)

```javascript
// Current: Manual rect calculations, scroll-aware positioning
const containerRect = this.timelineTarget.getBoundingClientRect();
const startRect = startSlot.getBoundingClientRect();
const scrollTop = this.timelineTarget.scrollTop;
const top = startRect.top - containerRect.top + scrollTop;
```

**Problem**: Position calculations break when layout changes, CSS updates, or Turbo replaces the timeline.

**Would Inertia help?** ❌ No — this is DOM geometry math that any framework requires.

---

### 2. Turbo Stream Coordination (`time_block_controller.js:55-57`)

```javascript
// Current: Must rebuild state after Turbo replaces the timeline
timelineTargetConnected() {
  this.buildHourSlotMap();
}
```

**Problem**: Every CRUD operation replaces the entire timeline via Turbo Stream, forcing:
- Hour slot map rebuild
- Event listener re-attachment
- Potential scroll position loss

**Would Inertia help?** ✅ Yes — React/Vue manage their own DOM. State persists across renders. No manual reconnection needed.

---

### 3. Touch vs. Mouse Event Duplication (`time_block_controller.js:108-300`)

~200 lines of nearly-duplicate code handling:
- Mouse: `startDrag`, `handleMouseMove`, `handleMouseUp`
- Touch: `startTouchDrag`, `handleTouchMove`, `handleTouchEnd`, `activateTouchDrag`, hold timeout logic

**Would Inertia help?** ⚠️ Partially — Could use libraries like `@use-gesture/react` or `vue-use-gesture` which unify pointer events. But the core complexity (distinguishing scroll from drag on mobile) remains.

---

### 4. Modal State Coupling (`time_block_controller.js:347-397`)

```javascript
// Current: Modal state lives in DOM, coordinated via classes
this.modalTarget.classList.remove("hidden");
this.modalTarget.classList.add("flex");
```

**Problem**: State split between:
- Controller instance (`selectedStartHour`, `selectedEndHour`)
- DOM (`hidden` class on modal)
- Turbo events (`turbo:submit-end` closes modal)

**Would Inertia help?** ✅ Yes — Modal open/close becomes component state:

```jsx
const [modalOpen, setModalOpen] = useState(false);
const [selection, setSelection] = useState(null);
// All in one place, predictable
```

---

### 5. Form Submission Gymnastics (`time_block_controller.js:399-437`)

```javascript
// Current: Programmatically create and submit form
const form = document.createElement("form");
form.method = "POST";
form.action = "/habit_logs";
// ...build hidden inputs...
document.body.appendChild(form);
form.requestSubmit();
```

**Would Inertia help?** ✅ Yes — Direct POST with JSON:

```jsx
router.post('/habit_logs', { habit_log: { ... } });
```

---

## Benefits Analysis

### What Inertia Would Improve

| Area | Current Pain | Inertia Solution |
|------|--------------|------------------|
| State persistence | Rebuilding after Turbo Stream | React state survives re-renders |
| Modal coordination | DOM classes + Turbo events | `useState` for open/selection |
| Form submissions | Programmatic form creation | `router.post()` with JSON |
| Component reuse | ERB partials, limited composition | Full component model |
| Type safety | None (vanilla JS) | TypeScript with props typing |
| Testing | System tests or manual | Jest/Vitest component tests |

### What Inertia Would NOT Improve

| Area | Why It's Framework-Agnostic |
|------|----------------------------|
| Drag interaction math | `getBoundingClientRect()` required regardless |
| Touch hold detection | Scroll vs. drag disambiguation is platform-specific |
| Timeline rendering performance | 18 hours × N blocks is the same work |
| Scroll position | Any framework needs explicit restoration |

---

## Cost Analysis

### Migration Effort

1. **Add build tooling**: Replace importmap with Vite/esbuild + React/Vue
2. **Install inertia-rails gem**: `gem 'inertia_rails'`
3. **Create adapter**: Serializers for DaySummary, Habit, HabitLog
4. **Rewrite views**: ERB → JSX/Vue components (5 dashboard partials)
5. **Port Stimulus**: `time_block_controller.js` → React hook or Vue composable
6. **Update tests**: System tests may need adjustment

**Estimated complexity**: Significant. ~2-3 weeks for dashboard alone.

### Ongoing Costs

- **Bundle size**: React + Inertia ≈ 45KB gzipped (vs. ~10KB for Stimulus + Turbo)
- **Build complexity**: Vite config, asset pipeline changes
- **Two paradigms**: Other pages still use Turbo/Stimulus (or must also migrate)
- **Learning curve**: Team must know React/Vue patterns

---

## Alternative: Targeted Refactoring

Before adopting Inertia, consider these targeted improvements:

### 1. Extract Drag Logic to Reusable Module

```javascript
// app/javascript/lib/timeline_drag.js
export function createDragHandler(container, options) {
  // Unified pointer events (mouse + touch)
  // Returns { start, end } on completion
}
```

### 2. Use PointerEvents API (Modern Browsers)

```javascript
// Replaces separate mouse/touch handlers
element.addEventListener('pointerdown', handlePointerDown);
element.addEventListener('pointermove', handlePointerMove);
element.addEventListener('pointerup', handlePointerUp);
```

### 3. Add Turbo Stream Morph (Rails 7.1+)

```erb
<%= turbo_stream.morph "timeline", partial: "dashboard/timeline" %>
```

Morph preserves DOM state instead of replacing, reducing reconnection issues.

### 4. State Management with Stimulus Values

```javascript
// Keep selection state in Stimulus values (persists across Turbo updates)
static values = {
  selectedStart: Number,
  selectedEnd: Number,
  modalOpen: Boolean
}
```

---

## Proof of Concept Recommendation

If you want to evaluate Inertia hands-on, here's a minimal spike:

### Scope: Habit List Page (Not Dashboard)

The Habits index page is simpler — CRUD without complex drag interactions. Good for evaluating:
- Inertia installation / Rails integration
- Component model vs. ERB
- Form handling
- Turbo Stream replacement

### Implementation Steps

1. **Add dependencies**
   ```bash
   bundle add inertia_rails
   npm init -y
   npm install @inertiajs/react react react-dom vite @vitejs/plugin-react
   ```

2. **Configure Vite**
   ```js
   // vite.config.js
   import { defineConfig } from 'vite'
   import react from '@vitejs/plugin-react'
   import rails from 'vite-plugin-rails'

   export default defineConfig({
     plugins: [rails(), react()]
   })
   ```

3. **Create Habits component**
   ```jsx
   // app/frontend/pages/Habits/Index.jsx
   import { Link, router } from '@inertiajs/react'

   export default function HabitsIndex({ habits }) {
     const deleteHabit = (id) => {
       if (confirm('Delete?')) router.delete(`/habits/${id}`)
     }

     return (
       <div className="nb-page">
         {habits.map(habit => (
           <HabitCard key={habit.id} habit={habit} onDelete={deleteHabit} />
         ))}
       </div>
     )
   }
   ```

4. **Update controller**
   ```ruby
   # app/controllers/habits_controller.rb
   def index
     render inertia: 'Habits/Index', props: {
       habits: current_user.habits.active.map { |h| HabitSerializer.new(h) }
     }
   end
   ```

### Evaluation Criteria

After building the POC, assess:

| Question | Notes |
|----------|-------|
| Was setup straightforward? | Vite + Rails integration can be tricky |
| Is the component cleaner than ERB? | Compare complexity |
| How do flash messages work? | Inertia has shared data patterns |
| Can we mix with existing Turbo pages? | Or must we migrate everything? |
| Does it break existing tests? | System tests especially |

---

## Recommendations

### For This Codebase

**Don't migrate to Inertia yet.** The complexity is localized to `time_block_controller.js`, and Inertia wouldn't simplify the core drag logic.

Instead:
1. **Refactor `time_block_controller.js`** using PointerEvents API
2. **Try `turbo_stream.morph`** to reduce DOM replacement issues
3. **Extract drag logic** to a tested, reusable module
4. **Consider Inertia** only if you're adding significantly more interactive features

### When Inertia Makes Sense

- Building **data-heavy dashboards** with lots of filtering/sorting
- Need **real-time collaborative features** (Inertia + ActionCable)
- Team already knows **React/Vue** and prefers component model
- Want to share components with a **mobile app** (React Native)

---

## References

- [InertiaJS Documentation](https://inertiajs.com/)
- [inertia_rails gem](https://github.com/inertiajs/inertia-rails)
- [Vite Ruby](https://vite-ruby.netlify.app/)
- [PointerEvents API](https://developer.mozilla.org/en-US/docs/Web/API/Pointer_events)
- [Turbo Streams Morph](https://turbo.hotwired.dev/handbook/streams#morphing)
