import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="theme"
export default class extends Controller {
  static targets = ["select"];

  connect() {
    // Store the initial theme in case we need to revert
    this.initialTheme = document.documentElement.dataset.theme;
  }

  // Called when the select changes - preview the theme immediately
  preview() {
    const selectedTheme = this.selectTarget.value;
    document.documentElement.dataset.theme = selectedTheme;
  }

  // Called on form submit - theme is already previewed, just let form submit normally
  save(event) {
    // Theme already applied via preview(), form will save to DB
    // Update initial theme so we don't revert on disconnect
    this.initialTheme = this.selectTarget.value;
  }
}
