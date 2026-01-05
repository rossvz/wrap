import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "container"]

  add() {
    const name = this.inputTarget.value.trim().toLowerCase()
    if (!name || name.length > 30) return

    if (!/^[a-z0-9\s\-_]+$/.test(name)) return

    const form = this.element.closest("form")
    if (!form) return

    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.name = "new_tags[]"
    hidden.value = name
    form.appendChild(hidden)

    const chip = document.createElement("span")
    chip.className = "inline-flex items-center gap-2 px-3 py-2 min-h-[44px] border-2 border-black bg-gray-200"
    chip.style.boxShadow = "2px 2px 0 var(--shadow-color, #000)"

    const textSpan = document.createElement("span")
    textSpan.className = "text-sm font-bold"
    textSpan.textContent = name
    chip.appendChild(textSpan)

    this.containerTarget.appendChild(chip)
    this.inputTarget.value = ""
  }

  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.add()
    }
  }
}
