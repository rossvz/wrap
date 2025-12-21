import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "colorButton"]

  connect() {
    this.updateSelectedButton()
  }

  select(event) {
    const color = event.currentTarget.dataset.color
    this.inputTarget.value = color
    this.updateSelectedButton()
  }

  updateSelectedButton() {
    const currentColor = (this.inputTarget.value || "").toUpperCase()
    
    this.colorButtonTargets.forEach(button => {
      const buttonColor = (button.dataset.color || "").toUpperCase()
      if (buttonColor === currentColor) {
        button.style.boxShadow = "4px 4px 0 #000"
        button.classList.add("scale-110", "z-10", "ring-2", "ring-black", "ring-offset-2")
        button.setAttribute("aria-selected", "true")
      } else {
        button.style.boxShadow = "2px 2px 0 #000"
        button.classList.remove("scale-110", "z-10", "ring-2", "ring-black", "ring-offset-2")
        button.setAttribute("aria-selected", "false")
      }
    })
  }
}

