import { Controller } from "@hotwired/stimulus"

// Simple modal controller for Turbo Frame modals
export default class extends Controller {
  static targets = ["content"]

  closeOnBackdrop(event) {
    // Only close if clicking the backdrop itself, not the content
    if (this.hasContentTarget && !this.contentTarget.contains(event.target)) {
      this.close()
    }
  }

  close() {
    // Navigate to dashboard to clear the turbo frame
    Turbo.visit(window.location.pathname, { action: "replace" })
  }
}
