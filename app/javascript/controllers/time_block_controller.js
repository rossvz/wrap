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
  };

  connect() {
    this.isDragging = false;
    this.dragStartHour = null;
    this.selectedStartHour = null;
    this.selectedEndHour = null;

    // Bind event handlers
    this.handleMouseMove = this.handleMouseMove.bind(this);
    this.handleMouseUp = this.handleMouseUp.bind(this);
    this.handleTouchMove = this.handleTouchMove.bind(this);
    this.handleTouchEnd = this.handleTouchEnd.bind(this);

    // Build hour slot map
    this.hourSlots = new Map();
    this.buildHourSlotMap();
  }

  disconnect() {
    this.cleanupListeners();
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
  startTouchDrag(event) {
    if (event.target.closest("[data-time-block]")) return;

    const dragHandle = event.target.closest(".drag-handle");
    if (!dragHandle) return;

    event.preventDefault();

    const touch = event.touches[0];
    this.isDragging = true;

    const hourFromElement = this.getHourFromElement(dragHandle);
    this.dragStartHour =
      hourFromElement !== null
        ? hourFromElement
        : this.getHourFromY(touch.clientY);
    this.selectedStartHour = this.dragStartHour;
    this.selectedEndHour = this.dragStartHour + 1;

    this.showSelection();
    this.updateSelection();

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
    form.submit();
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
