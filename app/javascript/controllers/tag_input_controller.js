import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "container"]
  static values = { habitId: Number, persisted: Boolean }

  async add() {
    const name = this.inputTarget.value.trim().toLowerCase()
    if (!name || name.length > 30) return
    if (!/^[a-z0-9\s\-_]+$/.test(name)) return

    this.inputTarget.value = ""

    if (this.persistedValue) {
      const response = await fetch(`/habits/${this.habitIdValue}/taggings`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({ tag_name: name })
      })

      if (response.ok) {
        const data = await response.json()
        this.addTagChip(data.tag.name, data.tag.id, true)
      }
    } else {
      this.addNewTagForForm(name)
    }
  }

  addNewTagForForm(name) {
    const form = this.element.closest("form")
    if (!form) return

    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.name = "new_tags[]"
    hidden.value = name
    form.appendChild(hidden)

    this.addTagChip(name, null, true)
  }

  async toggle(event) {
    const checkbox = event.target
    const tagId = checkbox.value

    if (checkbox.checked) {
      await fetch(`/habits/${this.habitIdValue}/taggings`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({ tag_id: tagId })
      })
    } else {
      const response = await fetch(`/habits/${this.habitIdValue}/taggings/${tagId}`, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        }
      })

      if (!response.ok) {
        checkbox.checked = true
      }
    }
  }

  addTagChip(name, tagId, checked) {
    const label = document.createElement("label")
    label.className = `inline-flex items-center gap-2 px-3 py-2 min-h-[44px]
                       border-2 border-black cursor-pointer touch-manipulation
                       hover:bg-gray-50 transition-colors
                       ${checked ? "bg-gray-200 ring-2 ring-black" : ""}`
    label.style.boxShadow = "2px 2px 0 var(--shadow-color, #000)"

    const checkbox = document.createElement("input")
    checkbox.type = "checkbox"
    checkbox.name = "habit[tag_ids][]"
    checkbox.value = tagId || ""
    checkbox.checked = checked
    checkbox.className = "sr-only"
    if (this.persistedValue && tagId) {
      checkbox.dataset.action = "change->tag-input#toggle"
    }

    const textSpan = document.createElement("span")
    textSpan.className = "text-sm font-bold"
    textSpan.textContent = name

    label.appendChild(checkbox)
    label.appendChild(textSpan)
    this.containerTarget.appendChild(label)
  }

  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.add()
    }
  }
}
