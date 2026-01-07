import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="time-block"
// Handles drag-to-create new time blocks on the dashboard timeline
export default class extends Controller {
  static targets = [
    "timeline",
    "selection",
    "modal",
    "newHabitName",
    "startHourInput",
    "endHourInput",
  ];
  static values = {
    date: String,
    hourHeight: { type: Number, default: 60 },
    startHour: { type: Number, default: 6 },
    endHour: { type: Number, default: 24 },
    touchHoldDelay: { type: Number, default: 200 }, // ms to hold before drag activates
    touchMoveThreshold: { type: Number, default: 10 }, // px movement to cancel hold
  };

  // Called once when controller is first instantiated (before targets connect)
  initialize() {
    this.hourSlots = new Map();
  }

  connect() {
    this.isDragging = false;
    this.dragStartHour = null;
    this.selectedStartHour = null;
    this.selectedEndHour = null;

    // Touch hold state (for distinguishing scroll from drag on mobile)
    this.touchHoldTimeout = null;
    this.touchStartX = null;
    this.touchStartY = null;
    this.pendingDragHandle = null;

    // Bind event handlers
    this.handleMouseMove = this.handleMouseMove.bind(this);
    this.handleMouseUp = this.handleMouseUp.bind(this);
    this.handleTouchMove = this.handleTouchMove.bind(this);
    this.handleTouchEnd = this.handleTouchEnd.bind(this);
    this.handleTouchHoldCheck = this.handleTouchHoldCheck.bind(this);
    this.handleTouchCancelHold = this.handleTouchCancelHold.bind(this);
  }

  disconnect() {
    this.cleanupListeners();
  }

  // Called by Stimulus when the timeline target element is (re)connected to the DOM
  // This handles Turbo Stream replacements that swap out the timeline content
  timelineTargetConnected() {
    this.buildHourSlotMap();
  }

  buildHourSlotMap() {
    this.hourSlots.clear();
    const slots = this.timelineTarget.querySelectorAll(
      ".timeline-hour[data-hour]"
    );
    slots.forEach((slot) => {
      const hour = parseInt(slot.dataset.hour, 10);
      if (!isNaN(hour)) {
        this.hourSlots.set(hour, slot);
      }
    });
  }

  // Get hour from click Y position by checking actual slot positions
  getHourFromY(clientY) {
    for (const [hour, slot] of this.hourSlots) {
      const slotRect = slot.getBoundingClientRect();
      if (clientY >= slotRect.top && clientY < slotRect.bottom) {
        return hour;
      }
    }

    // Boundary checks
    const firstSlot = this.hourSlots.get(this.startHourValue);
    const lastSlot = this.hourSlots.get(this.endHourValue - 1);

    if (firstSlot && clientY < firstSlot.getBoundingClientRect().top) {
      return this.startHourValue;
    }
    if (lastSlot && clientY >= lastSlot.getBoundingClientRect().bottom) {
      return this.endHourValue - 1;
    }

    return this.startHourValue;
  }

  // Get starting hour from the element that was clicked/touched
  getHourFromElement(element) {
    const hourElement = element.closest("[data-hour]");
    if (hourElement) {
      const hour = parseInt(hourElement.dataset.hour, 10);
      if (!isNaN(hour)) {
        return hour;
      }
    }
    return null;
  }

  // Mouse events (desktop - works on hour-content area)
  startDrag(event) {
    // Don't start drag if clicking on an existing time block (it's a link now)
    if (event.target.closest("[data-time-block]")) return;

    event.preventDefault();
    this.isDragging = true;

    const hourFromElement = this.getHourFromElement(event.target);
    this.dragStartHour =
      hourFromElement !== null
        ? hourFromElement
        : this.getHourFromY(event.clientY);
    this.selectedStartHour = this.dragStartHour;
    this.selectedEndHour = this.dragStartHour + 1;

    this.showSelection();
    this.updateSelection();

    document.addEventListener("mousemove", this.handleMouseMove);
    document.addEventListener("mouseup", this.handleMouseUp);
  }

  handleMouseMove(event) {
    if (!this.isDragging) return;
    event.preventDefault();

    const currentHour = this.getHourFromY(event.clientY);

    if (currentHour >= this.dragStartHour) {
      this.selectedStartHour = this.dragStartHour;
      this.selectedEndHour = Math.max(currentHour + 1, this.dragStartHour + 1);
    } else {
      this.selectedStartHour = currentHour;
      this.selectedEndHour = this.dragStartHour + 1;
    }

    this.selectedStartHour = Math.max(
      this.startHourValue,
      this.selectedStartHour
    );
    this.selectedEndHour = Math.min(this.endHourValue, this.selectedEndHour);

    this.updateSelection();
  }

  handleMouseUp(event) {
    if (!this.isDragging) return;

    this.cleanupListeners();
    this.isDragging = false;

    if (this.selectedEndHour - this.selectedStartHour < 1) {
      this.selectedEndHour = this.selectedStartHour + 1;
    }

    this.openModal();
  }

  // Touch events (mobile - only triggered from drag-handle)
  // Uses a hold delay to distinguish intentional drags from scrolls
  startTouchDrag(event) {
    if (event.target.closest("[data-time-block]")) return;

    const dragHandle = event.target.closest(".drag-handle");
    if (!dragHandle) return;

    // Don't prevent default yet - let scroll happen until hold is confirmed
    const touch = event.touches[0];
    this.touchStartX = touch.clientX;
    this.touchStartY = touch.clientY;
    this.pendingDragHandle = dragHandle;

    // Add visual feedback that touch is registered
    dragHandle.classList.add("touch-pending");

    // Start hold timer - drag only activates after holding
    this.touchHoldTimeout = setTimeout(() => {
      this.activateTouchDrag(dragHandle, touch);
    }, this.touchHoldDelayValue);

    // Listen for movement/end to cancel hold if user scrolls
    document.addEventListener("touchmove", this.handleTouchHoldCheck, {
      passive: true,
    });
    document.addEventListener("touchend", this.handleTouchCancelHold);
  }

  // Check if user moved too much during hold period (they're scrolling)
  handleTouchHoldCheck(event) {
    if (!this.touchHoldTimeout) return;

    const touch = event.touches[0];
    const deltaX = Math.abs(touch.clientX - this.touchStartX);
    const deltaY = Math.abs(touch.clientY - this.touchStartY);

    // If moved beyond threshold, cancel the hold - user is scrolling
    if (deltaX > this.touchMoveThresholdValue || deltaY > this.touchMoveThresholdValue) {
      this.cancelTouchHold();
    }
  }

  // Cancel hold if touch ends before delay completes
  handleTouchCancelHold() {
    this.cancelTouchHold();
  }

  cancelTouchHold() {
    if (this.touchHoldTimeout) {
      clearTimeout(this.touchHoldTimeout);
      this.touchHoldTimeout = null;
    }
    if (this.pendingDragHandle) {
      this.pendingDragHandle.classList.remove("touch-pending");
      this.pendingDragHandle = null;
    }
    document.removeEventListener("touchmove", this.handleTouchHoldCheck);
    document.removeEventListener("touchend", this.handleTouchCancelHold);
  }

  // Actually start the drag after hold delay completes
  activateTouchDrag(dragHandle, initialTouch) {
    // Clean up hold state
    this.touchHoldTimeout = null;
    document.removeEventListener("touchmove", this.handleTouchHoldCheck);
    document.removeEventListener("touchend", this.handleTouchCancelHold);

    // Visual feedback - drag is now active
    dragHandle.classList.remove("touch-pending");
    dragHandle.classList.add("touch-active");
    this.activeDragHandle = dragHandle;

    this.isDragging = true;

    const hourFromElement = this.getHourFromElement(dragHandle);
    this.dragStartHour =
      hourFromElement !== null
        ? hourFromElement
        : this.getHourFromY(initialTouch.clientY);
    this.selectedStartHour = this.dragStartHour;
    this.selectedEndHour = this.dragStartHour + 1;

    this.showSelection();
    this.updateSelection();

    // Now listen for drag movement with passive: false to prevent scroll
    document.addEventListener("touchmove", this.handleTouchMove, {
      passive: false,
    });
    document.addEventListener("touchend", this.handleTouchEnd);
  }

  handleTouchMove(event) {
    if (!this.isDragging) return;
    event.preventDefault();

    const touch = event.touches[0];
    const currentHour = this.getHourFromY(touch.clientY);

    if (currentHour >= this.dragStartHour) {
      this.selectedStartHour = this.dragStartHour;
      this.selectedEndHour = Math.max(currentHour + 1, this.dragStartHour + 1);
    } else {
      this.selectedStartHour = currentHour;
      this.selectedEndHour = this.dragStartHour + 1;
    }

    this.selectedStartHour = Math.max(
      this.startHourValue,
      this.selectedStartHour
    );
    this.selectedEndHour = Math.min(this.endHourValue, this.selectedEndHour);

    this.updateSelection();
  }

  handleTouchEnd(event) {
    if (!this.isDragging) return;

    this.cleanupListeners();
    this.isDragging = false;

    // Clean up active drag handle visual state
    if (this.activeDragHandle) {
      this.activeDragHandle.classList.remove("touch-active");
      this.activeDragHandle = null;
    }

    if (this.selectedEndHour - this.selectedStartHour < 1) {
      this.selectedEndHour = this.selectedStartHour + 1;
    }

    this.openModal();
  }

  cleanupListeners() {
    document.removeEventListener("mousemove", this.handleMouseMove);
    document.removeEventListener("mouseup", this.handleMouseUp);
    document.removeEventListener("touchmove", this.handleTouchMove);
    document.removeEventListener("touchend", this.handleTouchEnd);
    // Also clean up any pending touch hold
    this.cancelTouchHold();
  }

  showSelection() {
    if (this.hasSelectionTarget) {
      this.selectionTarget.classList.remove("hidden");
    }
  }

  hideSelection() {
    if (this.hasSelectionTarget) {
      this.selectionTarget.classList.add("hidden");
    }
  }

  updateSelection() {
    if (!this.hasSelectionTarget) return;

    const startSlot = this.hourSlots.get(this.selectedStartHour);
    const endSlot = this.hourSlots.get(this.selectedEndHour - 1);

    if (!startSlot || !endSlot) return;

    const top = startSlot.offsetTop;
    const height =
      endSlot.offsetTop + endSlot.offsetHeight - startSlot.offsetTop;

    this.selectionTarget.style.top = `${top}px`;
    this.selectionTarget.style.height = `${height}px`;
  }

  openModal() {
    if (this.hasModalTarget) {
      if (this.hasStartHourInputTarget) {
        this.startHourInputTarget.value = this.selectedStartHour;
      }
      if (this.hasEndHourInputTarget) {
        this.endHourInputTarget.value = this.selectedEndHour;
      }

      const timeDisplay = this.modalTarget.querySelector("[data-time-display]");
      if (timeDisplay) {
        timeDisplay.textContent = `${this.formatHour(
          this.selectedStartHour
        )} - ${this.formatHour(this.selectedEndHour)}`;
      }

      this.modalTarget.classList.remove("hidden");
      this.modalTarget.classList.add("flex");
    }
  }

  closeModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden");
      this.modalTarget.classList.remove("flex");
    }
    this.hideSelection();

    if (this.hasNewHabitNameTarget) {
      this.newHabitNameTarget.value = "";
    }
  }

  selectHabit(event) {
    event.preventDefault();
    const habitId = event.currentTarget.dataset.habitId;
    this.submitTimeBlock(habitId);
  }

  createNewHabit(event) {
    event.preventDefault();
    if (!this.hasNewHabitNameTarget) return;

    const name = this.newHabitNameTarget.value.trim();
    if (!name) {
      this.newHabitNameTarget.focus();
      return;
    }

    this.submitTimeBlock(null, name);
  }

  submitTimeBlock(habitId, newHabitName = null) {
    const form = document.createElement("form");
    form.method = "POST";
    form.action = "/habit_logs";

    const csrfToken = document.querySelector(
      'meta[name="csrf-token"]'
    )?.content;
    if (csrfToken) {
      const csrfInput = document.createElement("input");
      csrfInput.type = "hidden";
      csrfInput.name = "authenticity_token";
      csrfInput.value = csrfToken;
      form.appendChild(csrfInput);
    }

    const fields = {
      "habit_log[logged_on]": this.dateValue,
      "habit_log[start_hour]": this.selectedStartHour,
      "habit_log[end_hour]": this.selectedEndHour,
    };

    if (habitId) {
      fields["habit_log[habit_id]"] = habitId;
    } else if (newHabitName) {
      fields["habit_log[new_habit_name]"] = newHabitName;
    }

    for (const [name, value] of Object.entries(fields)) {
      const input = document.createElement("input");
      input.type = "hidden";
      input.name = name;
      input.value = value;
      form.appendChild(input);
    }

    document.body.appendChild(form);
    form.requestSubmit();
  }

  formatHour(hour) {
    const h = Math.floor(hour);
    const m = Math.round((hour % 1) * 60);
    const period = h >= 12 ? "pm" : "am";
    const displayHour = h === 0 ? 12 : h > 12 ? h - 12 : h;
    return m === 0
      ? `${displayHour}${period}`
      : `${displayHour}:${m.toString().padStart(2, "0")}${period}`;
  }
}
