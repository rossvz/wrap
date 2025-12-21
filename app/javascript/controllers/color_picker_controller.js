import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "colorButton"]

  connect() {
    this.updateSelectedButton()
  }

  select(event) {
    const token = event.currentTarget.dataset.token
    this.inputTarget.value = token
    this.updateSelectedButton()
  }

  updateSelectedButton() {
    const currentToken = this.inputTarget.value
    
    this.colorButtonTargets.forEach(button => {
      const buttonToken = button.dataset.token
      if (buttonToken === currentToken) {
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
