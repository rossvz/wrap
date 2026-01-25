import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  async copy() {
    const text = this.sourceTarget.textContent.trim()

    try {
      await navigator.clipboard.writeText(text)
      const originalText = this.buttonTarget.textContent
      this.buttonTarget.textContent = "Copied!"
      setTimeout(() => {
        this.buttonTarget.textContent = originalText
      }, 2000)
    } catch (err) {
      console.error("Failed to copy:", err)
    }
  }
}
