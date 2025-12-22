import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="time-block"
export default class extends Controller {
  static targets = [
    "timeline",
    "selection",
    "modal",
    "habitSelect",
    "newHabitName",
    "startHourInput",
    "endHourInput",
    // Edit modal targets
    "editModal",
    "editTimeDisplay",
    "editBlockId",
    "editOriginalHabitId",
    "editHabitButton",
    "editStartHour",
    "editEndHour",
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

    // Edit modal state
    this.editingBlockId = null;
    this.editingHabitId = null;
    this.editingOriginalHabitId = null;

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
    // Look for data-hour on the element or its parents
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
    if (event.target.closest("[data-time-block]")) return;

    event.preventDefault();
    this.isDragging = true;
    
    // Try to get hour from element first, fall back to Y position
    const hourFromElement = this.getHourFromElement(event.target);
    this.dragStartHour = hourFromElement !== null ? hourFromElement : this.getHourFromY(event.clientY);
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

    // Only start drag if touching a drag handle
    const dragHandle = event.target.closest(".drag-handle");
    if (!dragHandle) return;

    // Prevent default to stop scroll when dragging from handle
    event.preventDefault();

    const touch = event.touches[0];
    this.isDragging = true;
    
    // Get the starting hour from the drag handle's data attribute
    const hourFromElement = this.getHourFromElement(dragHandle);
    this.dragStartHour = hourFromElement !== null ? hourFromElement : this.getHourFromY(touch.clientY);
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

    // Use offsetTop - the position within the scrollable container
    // This works because the selection element is now inside the same scrollable container
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

  // Edit modal methods
  openEditModal(event) {
    event.preventDefault();
    event.stopPropagation();

    const target = event.currentTarget;
    this.editingBlockId = target.dataset.blockId;
    this.editingHabitId = target.dataset.habitId;
    this.editingOriginalHabitId = target.dataset.habitId;

    const startHour = parseFloat(target.dataset.startHour);
    const endHour = parseFloat(target.dataset.endHour);

    // Store in hidden inputs
    if (this.hasEditBlockIdTarget) {
      this.editBlockIdTarget.value = this.editingBlockId;
    }
    if (this.hasEditOriginalHabitIdTarget) {
      this.editOriginalHabitIdTarget.value = this.editingOriginalHabitId;
    }

    // Set the time dropdowns
    if (this.hasEditStartHourTarget) {
      this.editStartHourTarget.value = startHour;
    }
    if (this.hasEditEndHourTarget) {
      this.editEndHourTarget.value = endHour;
    }

    // Update time display
    this.updateEditTimeDisplay();

    // Highlight the current habit
    this.updateEditHabitSelection();

    // Show modal
    if (this.hasEditModalTarget) {
      this.editModalTarget.classList.remove("hidden");
      this.editModalTarget.classList.add("flex");
    }
  }

  closeEditModal() {
    if (this.hasEditModalTarget) {
      this.editModalTarget.classList.add("hidden");
      this.editModalTarget.classList.remove("flex");
    }
    this.editingBlockId = null;
    this.editingHabitId = null;
    this.editingOriginalHabitId = null;
  }

  selectEditHabit(event) {
    event.preventDefault();
    const habitId = event.currentTarget.dataset.habitId;
    this.editingHabitId = habitId;
    this.updateEditHabitSelection();
  }

  updateEditHabitSelection() {
    if (!this.hasEditHabitButtonTarget) return;

    this.editHabitButtonTargets.forEach((button) => {
      const checkmark = button.querySelector("[data-checkmark]");
      if (button.dataset.habitId === this.editingHabitId) {
        button.classList.add("ring-2", "ring-black", "ring-offset-2");
        if (checkmark) checkmark.classList.remove("hidden");
      } else {
        button.classList.remove("ring-2", "ring-black", "ring-offset-2");
        if (checkmark) checkmark.classList.add("hidden");
      }
    });
  }

  updateEditTimeDisplay() {
    if (!this.hasEditTimeDisplayTarget) return;

    const start = parseFloat(this.editStartHourTarget?.value || 0);
    const end = parseFloat(this.editEndHourTarget?.value || 0);

    this.editTimeDisplayTarget.textContent = `${this.formatHour(start)} - ${this.formatHour(end)}`;
  }

  saveEdit(event) {
    event.preventDefault();

    const startHour = parseFloat(this.editStartHourTarget?.value || 0);
    const endHour = parseFloat(this.editEndHourTarget?.value || 0);

    // Validate
    if (endHour <= startHour) {
      alert("End time must be after start time");
      return;
    }

    const habitChanged = this.editingHabitId !== this.editingOriginalHabitId;

    if (habitChanged) {
      // Delete old and create new
      this.deleteAndRecreate(startHour, endHour);
    } else {
      // Just update the existing log
      this.updateBlock(startHour, endHour);
    }
  }

  updateBlock(startHour, endHour) {
    const form = document.createElement("form");
    form.method = "POST";
    form.action = `/habits/${this.editingOriginalHabitId}/logs/${this.editingBlockId}`;

    const methodInput = document.createElement("input");
    methodInput.type = "hidden";
    methodInput.name = "_method";
    methodInput.value = "PATCH";
    form.appendChild(methodInput);

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    if (csrfToken) {
      const csrfInput = document.createElement("input");
      csrfInput.type = "hidden";
      csrfInput.name = "authenticity_token";
      csrfInput.value = csrfToken;
      form.appendChild(csrfInput);
    }

    const fields = {
      "habit_log[start_hour]": startHour,
      "habit_log[end_hour]": endHour,
    };

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

  deleteAndRecreate(startHour, endHour) {
    // Use fetch to delete, then create new
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;

    fetch(`/habits/${this.editingOriginalHabitId}/logs/${this.editingBlockId}`, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "text/html",
      },
    }).then(() => {
      // Now create new log with the new habit
      const form = document.createElement("form");
      form.method = "POST";
      form.action = "/habit_logs";

      if (csrfToken) {
        const csrfInput = document.createElement("input");
        csrfInput.type = "hidden";
        csrfInput.name = "authenticity_token";
        csrfInput.value = csrfToken;
        form.appendChild(csrfInput);
      }

      const fields = {
        "habit_log[habit_id]": this.editingHabitId,
        "habit_log[logged_on]": this.dateValue,
        "habit_log[start_hour]": startHour,
        "habit_log[end_hour]": endHour,
      };

      for (const [name, value] of Object.entries(fields)) {
        const input = document.createElement("input");
        input.type = "hidden";
        input.name = name;
        input.value = value;
        form.appendChild(input);
      }

      document.body.appendChild(form);
      form.submit();
    });
  }

  confirmDelete(event) {
    event.preventDefault();

    const form = document.createElement("form");
    form.method = "POST";
    form.action = `/habits/${this.editingOriginalHabitId}/logs/${this.editingBlockId}`;

    const methodInput = document.createElement("input");
    methodInput.type = "hidden";
    methodInput.name = "_method";
    methodInput.value = "DELETE";
    form.appendChild(methodInput);

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    if (csrfToken) {
      const csrfInput = document.createElement("input");
      csrfInput.type = "hidden";
      csrfInput.name = "authenticity_token";
      csrfInput.value = csrfToken;
      form.appendChild(csrfInput);
    }

    document.body.appendChild(form);
    form.submit();
  }
}
